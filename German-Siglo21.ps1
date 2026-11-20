#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Simular, [switch]$SoloCamara, [switch]$Restaurar, [switch]$Directo)
$ErrorActionPreference = 'Stop'
$bloqueo = $null
$tomado = $false
try {
    # Evita suspensiones duplicadas si se abren dos lanzadores a la vez.
    $bloqueo = [Threading.Mutex]::new($false, 'Local\GermanSiglo21Preparacion')
    try { $tomado = $bloqueo.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $tomado = $true }
    if (-not $tomado) { throw 'Ya hay una instancia de German Siglo21 abierta. Cerrala primero.' }
    . (Join-Path $PSScriptRoot 'src\Preparacion.ps1')
    . (Join-Path $PSScriptRoot 'src\Camara.ps1')
    if (@($Simular,$SoloCamara,$Restaurar,$Directo | Where-Object { $_ }).Count -gt 1) {
        throw 'Usa un solo modo a la vez.'
    }
    if ($Restaurar) {
        if (Restore-Preparacion) { exit 0 } else { exit 1 }
    }
    $config = Read-Configuracion (Join-Path $PSScriptRoot 'configuracion.psd1')
    Write-Host "`nGERMAN SIGLO21 | Preparacion para rendir virtualmente`n" -ForegroundColor Cyan
    if ($Directo) {
        foreach ($grupo in (Get-Grupos).Keys) { $config[$grupo] = $true }
        $config.CerrarWebViewWidgets = $true
        $config.DetenerServiciosBrave = $true
        $config.ForzarCierre = $true
        $config.PausarBuscar = $false
        $config.PausarWidgets = $false
        $plan = @(Get-Plan $config)
        $correcto = Invoke-Plan -Plan $plan -Config $config
        $camara = Test-Camara
        Write-Host ('CAMARA: ' + $camara.detail)
        if ($correcto -and $camara.ok) { exit 0 } else { exit 1 }
    }
    if (-not $Simular -and -not $SoloCamara) {
        Write-Host '1. Probar solo la camara (no cierra aplicaciones)'
        Write-Host '2. Ver simulacion (no realiza cambios)'
        Write-Host '3. Preparar segun configuracion.psd1'
        Write-Host '4. Restaurar Buscar, Widgets y servicios detenidos'
        Write-Host '0. Salir'
        switch (Read-Host 'Elegi una opcion') {
            '1' { $SoloCamara = $true }
            '2' { $Simular = $true }
            '3' { }
            '4' { if (Restore-Preparacion) { exit 0 } else { exit 1 } }
            '0' { exit 0 }
            default { throw 'Opcion no valida.' }
        }
    }
    if ($SoloCamara) {
        $camara = Test-Camara
        Write-Host ('CAMARA: ' + $camara.detail)
        if ($camara.ok) { exit 0 } else { exit 1 }
    }
    $plan = @(Get-Plan $config)
    if ($Simular -or $config.ModoSimulacion) {
        Write-Host 'Variables activadas:'
        $config.GetEnumerator() | Sort-Object Name | Format-Table Name,Value -AutoSize | Out-Host
        [void](Invoke-Plan -Plan $plan -Config $config -Simular)
        Write-Host 'La camara tampoco se activa en simulacion. Esto NO comprueba que estes listo para rendir.'
        exit 0
    }
    Write-Host 'Acciones previstas:'
    $plan | Format-Table Accion,Nombre,Id -AutoSize | Out-Host
    Write-Host 'Guarda tu trabajo. Ejecuta esto ANTES de abrir la plataforma de examen.' -ForegroundColor Yellow
    if ($config.CerrarCodex) { Write-Host 'Codex se cerrara: ejecuta desde el Explorador, fuera de su terminal.' }
    if ((Read-Host 'Escribi PREPARAR para continuar') -cne 'PREPARAR') { Write-Host 'Cancelado.'; exit 0 }
    $camara = @{ok=$false; detail='No comprobada: ProbarCamara esta desactivado.'}
    if ($config.ProbarCamara) {
        $camara = Test-Camara
        Write-Host ('CAMARA: ' + $camara.detail)
        if (-not $camara.ok) {
            Write-Host 'No se cerraron aplicaciones ni se pausaron servicios. Resolve primero la camara.'
            exit 1
        }
    }
    # Actualizar el inventario despues de la camara. Codex se cierra al final.
    $plan = @(Get-Plan $config | Sort-Object @{Expression={ if ($_.Nombre -in @('Codex','codex-app','codex-desktop')) { 1 } else { 0 } }})
    $correcto = Invoke-Plan -Plan $plan -Config $config
    $pendientes = @(Get-Plan $config | Where-Object Accion -ne 'Pausar')
    Write-Host "`nRESULTADO"
    Write-Host ('CAMARA: ' + $camara.detail)
    if ($pendientes.Count) {
        $pendientes | Format-Table Accion,Nombre,Id -AutoSize | Out-Host
        $correcto = $false
    }
    if ($correcto) { Write-Host 'Acciones habilitadas completadas. Revisa las opciones desactivadas y el chequeo oficial.' }
    else { Write-Host 'CON OBSERVACIONES: quedan acciones pendientes.' -ForegroundColor Yellow }
    Write-Host 'No certifica compatibilidad ni detecta todas las aplicaciones. Usa Restaurar.cmd al terminar.'
    if ($correcto -and $camara.ok) { exit 0 } else { exit 1 }
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if ($tomado) { $bloqueo.ReleaseMutex() }
    if ($bloqueo) { $bloqueo.Dispose() }
}
