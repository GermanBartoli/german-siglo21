# Acciones limitadas a listas conocidas; nunca se cierran todos los procesos.
function Read-Configuracion {
    param([string]$Ruta)
    $config = Import-PowerShellDataFile -LiteralPath $Ruta
    if (-not $config.ContainsKey('CerrarWallpaper')) { $config.CerrarWallpaper = $false }
    $booleanos = @('ModoSimulacion','ProbarCamara','CerrarNavegadores','CerrarComunicacion',
        'CerrarWallpaper','CerrarCaptura','CerrarAsistentesIA','CerrarCodex','PausarBuscar','PausarWidgets',
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
        CerrarWallpaper = @('wallpaper32')
        CerrarCodex = @('Codex','codex-app','codex-desktop')
    }
}

function Get-Prioritarios {
    return @('brave','chrome','msedge','ChatGPT','BraveCrashHandler','BraveCrashHandler64','BraveUpdate','BraveUpdater','wallpaper32')
}

function Get-WebViewDeBuscar {
    param([int]$Sesion)
    $procesos = @(Get-CimInstance Win32_Process -Filter "SessionId=$Sesion AND (Name='msedgewebview2.exe' OR Name='SearchHost.exe' OR Name='SearchApp.exe' OR Name='Widgets.exe' OR Name='WidgetService.exe')")
    $porId = @{}
    foreach ($actual in $procesos) { $porId[$actual.ProcessId] = $actual }
    foreach ($web in $procesos) {
        if ($web.Name -ne 'msedgewebview2.exe') { continue }
        $actual = $web
        while ($actual) {
            if ($actual.Name -in @('SearchHost.exe','SearchApp.exe','Widgets.exe','WidgetService.exe') -or
                $actual.CommandLine -match 'MicrosoftWindows\.Client\.(CBS|WebExperience)|--webview-exe-name="?(SearchHost|SearchApp|Widgets|WidgetService)\.exe(?:"|\s|$)') {
                $web
                break
            }
            $padre = $porId[$actual.ParentProcessId]
            if (-not $padre -or $padre.CreationDate -ge $actual.CreationDate) { break }
            $actual = $padre
        }
    }
}

function Get-Plan {
    param([hashtable]$Config, [switch]$Prioritarios)
    $sesion = (Get-Process -Id $PID).SessionId
    $grupos = Get-Grupos
    $nombres = if ($Prioritarios) { Get-Prioritarios } else {
        foreach ($grupo in $grupos.Keys) { if ($Config[$grupo]) { $grupos[$grupo] } }
    }
    if ($nombres) {
        foreach ($proceso in @(Get-Process -Name $nombres -ErrorAction SilentlyContinue)) {
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
        foreach ($proceso in (Get-WebViewDeBuscar $sesion)) {
            $actual = Get-Process -Id $proceso.ProcessId -ErrorAction SilentlyContinue
            if ($actual -and $actual.ProcessName -eq 'msedgewebview2' -and $actual.SessionId -eq $sesion -and
                [Math]::Abs(($actual.StartTime - $proceso.CreationDate).TotalMilliseconds) -lt 1) {
                [pscustomobject]@{ Accion='Cerrar'; Nombre=$actual.ProcessName; Id=$actual.Id; Inicio=$actual.StartTime.Ticks }
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
    param([array]$Plan, [hashtable]$Config, [switch]$Simular, [switch]$Directo)
    if ($Simular) {
        Write-Host 'SIMULACION: no se ejecutan cierres, pausas ni cambios de servicios.' -ForegroundColor Cyan
        $Plan | Format-Table Accion,Nombre,Id -AutoSize | Out-Host
        return $true
    }
    $correcto = $true
    $carpeta = Get-CarpetaEstado
    New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
    $resumen = @{}
    if ($Directo) {
        $prioridad = @(Get-Prioritarios) + 'msedgewebview2'
        $Plan = @($Plan | Sort-Object @{Expression={
            if ($_.Accion -eq 'Detener servicio') { 0 } elseif ($_.Nombre -in $prioridad) { 1 } else { 2 }
        }})
    }
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
                } elseif ($Directo) {
                    try { $proceso.Kill() } catch { if (-not $proceso.HasExited) { throw } }
                    if (-not $proceso.WaitForExit(2000)) { throw 'El proceso sigue activo.' }
                } else {
                    [void]$proceso.CloseMainWindow()
                    if (-not $proceso.WaitForExit($Config.EsperaCierreSegundos * 1000)) {
                        if ($Config.ForzarCierre) { $proceso.Kill(); [void]$proceso.WaitForExit(3000) }
                        if (-not $proceso.HasExited) { throw 'Sigue abierto. Cerralo manualmente o habilita ForzarCierre.' }
                    }
                }
            }
            if ($Directo) { $resumen[$accion.Nombre]++ }
            else { Write-Host ("HECHO: $($accion.Accion) - $($accion.Nombre)") }
        } catch {
            $correcto = $false
            Write-Host ("PENDIENTE: $($accion.Nombre). " + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    foreach ($nombre in ($resumen.Keys | Sort-Object)) { Write-Host ("HECHO: {0} ({1})" -f $nombre,$resumen[$nombre]) }
    return $correcto
}

function Start-Vigilancia {
    $guion = Join-Path $PSScriptRoot 'Vigilar.ps1'
    $argumentos = '-NoProfile -ExecutionPolicy Bypass -File "' + $guion + '"'
    $hijo = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $argumentos -WindowStyle Hidden -PassThru
    try {
        for ($intento = 0; $intento -lt 50; $intento++) {
            $evento = $null
            if ([Threading.EventWaitHandle]::TryOpenExisting('Local\GermanSiglo21Detener', [ref]$evento)) {
                $evento.Dispose()
                return
            }
            if ($hijo.HasExited) { break }
            Start-Sleep -Milliseconds 100
        }
        throw 'No se pudo iniciar la vigilancia de cierres.'
    } finally { $hijo.Dispose() }
}

function Stop-Vigilancia {
    $evento = $null
    if ([Threading.EventWaitHandle]::TryOpenExisting('Local\GermanSiglo21Detener', [ref]$evento)) {
        try { [void]$evento.Set() } finally { $evento.Dispose() }
        for ($i = 0; $i -lt 300; $i++) {
            if (-not [Threading.EventWaitHandle]::TryOpenExisting('Local\GermanSiglo21Detener', [ref]$evento)) { return }
            $evento.Dispose()
            Start-Sleep -Milliseconds 100
        }
        throw 'La vigilancia sigue terminando. Volvé a ejecutar Restaurar.'
    }
}

function Restore-Preparacion {
    Stop-Vigilancia
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
