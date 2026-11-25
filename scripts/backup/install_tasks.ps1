[CmdletBinding()]
param(
    [switch]$MonitorOnly,
    [switch]$BackupOnly
)

$ErrorActionPreference = 'Stop'
$DataRoot = 'C:\mimascota'
$ConfigPath = if ($env:MIMASCOTA_CONFIG_PATH) { $env:MIMASCOTA_CONFIG_PATH } else { Join-Path $DataRoot 'config\db.env' }
$MonitorScript = Join-Path $PSScriptRoot 'monitor.ps1'
$BackupScript = Join-Path $PSScriptRoot 'respaldo.ps1'
$TaskPrincipal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$TaskSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew

function Register-Task {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [Microsoft.Management.Infrastructure.CimInstance]$Trigger
    )
    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) { throw "No existe el script: $ScriptPath" }
    $scriptArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    if ($Name -eq 'MiMascota-RespaldoDiario') { $scriptArguments += ' -LocalOnly' }
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $scriptArguments
    Register-ScheduledTask -TaskName $Name -Action $action -Trigger $Trigger -Settings $TaskSettings -Principal $TaskPrincipal -Force | Out-Null
    Write-Output "Tarea registrada: $Name"
}

$doMonitor = -not $BackupOnly
$doBackup = -not $MonitorOnly
if (-not $MonitorOnly -and -not $BackupOnly) {
    $doMonitor = $true
    $doBackup = $true
}

if ($doMonitor) {
    $monitorTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
        -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
    Register-Task -Name 'MiMascota-Monitor' -ScriptPath $MonitorScript -Trigger $monitorTrigger
}

if ($doBackup) {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { throw "No existe la configuracion: $ConfigPath" }
    $config = @{}
    foreach ($line in Get-Content -LiteralPath $ConfigPath) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -gt 0) { $config[$trimmed.Substring(0, $separator).Trim()] = $trimmed.Substring($separator + 1).Trim() }
    }
    if ($config['DB_USER'] -ne 'mimascota_backup' -or [string]::IsNullOrWhiteSpace($config['DB_PASS'])) {
        throw "No se registro la tarea diaria: configura DB_USER=mimascota_backup y DB_PASS en $ConfigPath."
    }
    $backupTrigger = New-ScheduledTaskTrigger -Daily -At '06:00'
    Register-Task -Name 'MiMascota-RespaldoDiario' -ScriptPath $BackupScript -Trigger $backupTrigger
}
