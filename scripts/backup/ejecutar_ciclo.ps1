[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Scripts = @(
    (Join-Path $PSScriptRoot 'monitor.ps1'),
    (Join-Path $PSScriptRoot 'backup_mimascota.ps1'),
    (Join-Path $PSScriptRoot 'verificar_vm.ps1')
)

foreach ($scriptPath in $Scripts) {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "No existe el script requerido: $scriptPath" }
    & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
