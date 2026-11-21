function Initialize-Camara {
    if ('CamaraSiglo21' -as [type]) { return }
    $marco = [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
    $referencias = @('System.dll','System.Core.dll','System.Drawing.dll','System.Windows.Forms.dll','System.Runtime.dll')
    $compilador = New-Object CodeDom.Compiler.CompilerParameters
    $compilador.GenerateInMemory = $true
    foreach ($nombre in $referencias) { [void]$compilador.ReferencedAssemblies.Add((Join-Path $marco $nombre)) }
    foreach ($archivo in (Get-ChildItem "$env:windir\System32\WinMetadata\*.winmd")) {
        [void]$compilador.ReferencedAssemblies.Add($archivo.FullName)
    }
    $proveedor = New-Object Microsoft.CSharp.CSharpCodeProvider
    try {
        $resultado = $proveedor.CompileAssemblyFromFile($compilador, (Join-Path $PSScriptRoot 'Camara.cs'))
        if ($resultado.Errors.HasErrors) { throw ($resultado.Errors -join [Environment]::NewLine) }
        [void]$resultado.CompiledAssembly
    } finally { $proveedor.Dispose() }
}

function Test-Camara {
    try {
        Initialize-Camara
        [CamaraSiglo21]::Mostrar()
        return @{ok=$true; detail='Imagen recibida durante cinco segundos.'}
    } catch {
        return @{ok=$false; detail=$_.Exception.GetBaseException().Message}
    }
}
