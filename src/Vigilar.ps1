# El proceso vive en la sesión del usuario y termina al restaurar, salir o reiniciar.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Preparacion.ps1')
$creado = $false
$detener = [Threading.EventWaitHandle]::new($false, 'ManualReset', 'Local\GermanSiglo21Detener', [ref]$creado)
try {
    if (-not $creado) { return }
    $config = @{ DetenerServiciosBrave=$true; CerrarWebViewWidgets=$true; ForzarCierre=$true }
    while (-not $detener.WaitOne(0)) {
        try {
            $plan = @(Get-Plan $config -Prioritarios)
            if ($plan.Count -and -not $detener.WaitOne(0)) {
                [void](Invoke-Plan -Plan $plan -Config $config -Directo)
            }
        } catch { Write-Warning $_.Exception.Message }
        if ($detener.WaitOne(2000)) { break }
    }
} finally { $detener.Dispose() }
