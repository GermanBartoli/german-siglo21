# Acciones limitadas a listas conocidas; nunca se cierran todos los procesos.
function Read-Configuracion {
    param([string]$Ruta)
    $config = Import-PowerShellDataFile -LiteralPath $Ruta
    $booleanos = @('ModoSimulacion','ProbarCamara','CerrarNavegadores','CerrarComunicacion',
        'CerrarCaptura','CerrarAsistentesIA','CerrarCodex','PausarBuscar','PausarWidgets',
        'CerrarWebViewWidgets','DetenerServiciosBrave','ForzarCierre')
    foreach ($nombre in $booleanos) {
        if (-not $config.ContainsKey($nombre) -or $config[$nombre] -isnot [bool]) {
            throw "La variable $nombre debe ser `$true o `$false."
        }
    }
    if ($config.EsperaCierreSegundos -isnot [int] -or
        $config.EsperaCierreSegundos -lt 1 -or $config.EsperaCierreSegundos -gt 30) {
        throw 'EsperaCierreSegundos debe ser un entero entre 1 y 30.'
    }
    foreach ($nombre in $config.Keys) {
        if ($nombre -notin ($booleanos + 'EsperaCierreSegundos')) { throw "Variable desconocida: $nombre" }
    }
    return $config
}

function Get-Grupos {
    return [ordered]@{
        CerrarNavegadores = @('brave','chrome','msedge','firefox','opera','opera_gx','vivaldi',
            'iexplore','waterfox','librewolf','floorp','zen','thorium','chromium','Arc','DuckDuckGo',
            'BraveCrashHandler','BraveCrashHandler64','BraveUpdate','BraveUpdater')
        CerrarComunicacion = @('Teams','ms-teams','Zoom','Discord','Skype','Slack','Telegram','WhatsApp')
        CerrarCaptura = @('obs64','obs32','ShareX','Snagit32','SnagitEditor','CamtasiaStudio','CamRecorder')
        CerrarAsistentesIA = @('ChatGPT','Claude','Copilot')
        CerrarCodex = @('Codex','codex-app','codex-desktop')
    }
}

function Get-Plan {
    param([hashtable]$Config)
    $sesion = (Get-Process -Id $PID).SessionId
    $grupos = Get-Grupos
    foreach ($grupo in $grupos.Keys) {
        if (-not $Config[$grupo]) { continue }
        foreach ($proceso in @(Get-Process -Name $grupos[$grupo] -ErrorAction SilentlyContinue)) {
            if ($proceso.SessionId -eq $sesion -and $proceso.Id -ne $PID) {
                [pscustomobject]@{ Accion='Cerrar'; Nombre=$proceso.ProcessName; Id=$proceso.Id; Inicio=$proceso.StartTime.Ticks }
            }
        }
    }
    $pausables = @()
    if ($Config.PausarBuscar) { $pausables += 'SearchHost'; $pausables += 'SearchApp' }
    if ($Config.PausarWidgets) { $pausables += 'Widgets'; $pausables += 'WidgetService' }
    if ($pausables.Count) {
        foreach ($proceso in @(Get-Process -Name $pausables -ErrorAction SilentlyContinue)) {
            if ($proceso.SessionId -eq $sesion) {
                [pscustomobject]@{ Accion='Pausar'; Nombre=$proceso.ProcessName; Id=$proceso.Id; Inicio=$proceso.StartTime.Ticks }
            }
        }
    }
    if ($Config.CerrarWebViewWidgets) {
        foreach ($proceso in @(Get-CimInstance Win32_Process -Filter "name='msedgewebview2.exe'")) {
            if ($proceso.SessionId -eq $sesion -and
                $proceso.CommandLine -match 'MicrosoftWindows\.Client\.(CBS|WebExperience)') {
                $actual = Get-Process -Id $proceso.ProcessId -ErrorAction SilentlyContinue
                if ($actual) {
                    [pscustomobject]@{ Accion='Cerrar'; Nombre=$actual.ProcessName; Id=$actual.Id; Inicio=$actual.StartTime.Ticks }
                }
            }
        }
    }
    if ($Config.DetenerServiciosBrave) {
        foreach ($servicio in @(Get-Service -Name brave,bravem -ErrorAction SilentlyContinue | Where-Object Status -eq Running)) {
            [pscustomobject]@{ Accion='Detener servicio'; Nombre=$servicio.Name; Id=0; Inicio=0 }
        }
    }
}

function Initialize-Pausa {
    if ('Siglo21Proceso' -as [type]) { return }
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Siglo21Proceso {
    [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint acceso, bool heredar, int id);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr identificador);
    [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr identificador);
    [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr identificador);
}
'@
}

function Set-Pausa {
    param([int]$Id, [bool]$Restaurar)
    Initialize-Pausa
    $identificador = [Siglo21Proceso]::OpenProcess(0x800, $false, $Id)
    if ($identificador -eq [IntPtr]::Zero) { throw 'Acceso denegado al proceso; puede requerir administrador.' }
    try {
        if ($Restaurar) { $resultado = [Siglo21Proceso]::NtResumeProcess($identificador) }
        else { $resultado = [Siglo21Proceso]::NtSuspendProcess($identificador) }
        if ($resultado -ne 0) { throw "Windows rechazo la operacion: $resultado" }
    } finally { [void][Siglo21Proceso]::CloseHandle($identificador) }
}

function Get-CarpetaEstado {
    return (Join-Path $env:LOCALAPPDATA 'GermanSiglo21\estado')
}

function Invoke-Plan {
    param([array]$Plan, [hashtable]$Config, [switch]$Simular)
    if ($Simular) {
        Write-Host 'SIMULACION: no se ejecutan cierres, pausas ni cambios de servicios.' -ForegroundColor Cyan
        $Plan | Format-Table Accion,Nombre,Id -AutoSize | Out-Host
        return $true
    }
    $correcto = $true
    $carpeta = Get-CarpetaEstado
    New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
    foreach ($accion in $Plan) {
        try {
            if ($accion.Accion -eq 'Detener servicio') {
                # Registrar antes de detener para poder recuperar tras una interrupcion.
                $marca = Join-Path $carpeta ('servicio-' + $accion.Nombre + '.json')
                $accion | ConvertTo-Json | Set-Content -LiteralPath $marca -Encoding UTF8
                Stop-Service -Name $accion.Nombre -ErrorAction Stop
                if ((Get-Service -Name $accion.Nombre).Status -ne 'Stopped') { throw 'El servicio sigue activo.' }
            } else {
                $proceso = Get-Process -Id $accion.Id -ErrorAction SilentlyContinue
                if (-not $proceso -or $proceso.StartTime.Ticks -ne $accion.Inicio) { continue }
                if ($accion.Accion -eq 'Pausar') {
                    $marca = Join-Path $carpeta ("proceso-$($accion.Id)-$($accion.Inicio).json")
                    if (Test-Path -LiteralPath $marca) { continue }
                    $accion | ConvertTo-Json | Set-Content -LiteralPath $marca -Encoding UTF8
                    try { Set-Pausa -Id $accion.Id -Restaurar $false }
                    catch { Remove-Item -LiteralPath $marca; throw }
                } else {
                    [void]$proceso.CloseMainWindow()
                    if (-not $proceso.WaitForExit($Config.EsperaCierreSegundos * 1000)) {
                        if ($Config.ForzarCierre) { $proceso.Kill(); [void]$proceso.WaitForExit(3000) }
                        if (-not $proceso.HasExited) { throw 'Sigue abierto. Cerralo manualmente o habilita ForzarCierre.' }
                    }
                }
            }
            Write-Host ("HECHO: $($accion.Accion) - $($accion.Nombre)")
        } catch {
            $correcto = $false
            Write-Host ("PENDIENTE: $($accion.Nombre). " + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    return $correcto
}

function Restore-Preparacion {
    $carpeta = Get-CarpetaEstado
    $correcto = $true
    foreach ($archivo in @(Get-ChildItem -LiteralPath $carpeta -Filter '*.json' -ErrorAction SilentlyContinue)) {
        try {
            $accion = Get-Content -Raw -LiteralPath $archivo.FullName | ConvertFrom-Json
            if ($accion.Accion -eq 'Detener servicio' -and $accion.Nombre -in @('brave','bravem')) {
                Start-Service -Name $accion.Nombre -ErrorAction Stop
            } elseif ($accion.Accion -eq 'Pausar' -and $accion.Nombre -in @('SearchHost','SearchApp','Widgets','WidgetService')) {
                $proceso = Get-Process -Id $accion.Id -ErrorAction SilentlyContinue
                if ($proceso -and $proceso.StartTime.Ticks -eq $accion.Inicio -and $proceso.ProcessName -eq $accion.Nombre) {
                    Set-Pausa -Id $accion.Id -Restaurar $true
                }
            } else { throw 'Registro de restauracion no reconocido.' }
            Remove-Item -LiteralPath $archivo.FullName
            Write-Host ("RESTAURADO: $($accion.Nombre)")
        } catch {
            $correcto = $false
            Write-Host ('No se pudo restaurar: ' + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    Write-Host 'La restauracion no vuelve a abrir aplicaciones cerradas. Si Windows sigue pausado, reinicia el equipo.'
    return $correcto
}
