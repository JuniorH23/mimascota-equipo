[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = 'C:\mimascota'
$ConfigPath = Join-Path $Root 'config\mysql80-backup.env'
$BackupDir = Join-Path $Root 'respaldos'
$LogDir = Join-Path $Root 'logs'
$LogFile = Join-Path $LogDir 'respaldo.log'

function Write-Log {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    Write-Output $line
}

function Read-EnvFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "No existe la configuracion: $Path" }
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -gt 0) { $values[$trimmed.Substring(0, $separator).Trim()] = $trimmed.Substring($separator + 1).Trim() }
    }
    return $values
}

try {
    New-Item -ItemType Directory -Force -Path $BackupDir, $LogDir | Out-Null
    $config = Read-EnvFile -Path $ConfigPath
    $ssh = if ($config['SSH_PATH']) { $config['SSH_PATH'] } else { 'C:\Windows\System32\OpenSSH\ssh.exe' }
    $sshHost = $config['BACKUP_SSH_HOST']
    $sshUser = if ($config['BACKUP_SSH_USER']) { $config['BACKUP_SSH_USER'] } else { 'respaldo' }
    $sshKey = $config['BACKUP_SSH_KEY_PATH']
    $knownHosts = $config['BACKUP_KNOWN_HOSTS_PATH']
    $remoteRoot = if ($config['BACKUP_REMOTE_ROOT']) { $config['BACKUP_REMOTE_ROOT'] } else { '/var/backups/mimascota' }
    if ($sshHost -notmatch '^[A-Za-z0-9.-]+$' -or $sshUser -notmatch '^[A-Za-z0-9._-]+$' -or $remoteRoot -notmatch '^/[A-Za-z0-9/_-]+$') {
        throw 'La configuracion SSH no es valida.'
    }
    foreach ($path in @($ssh, $config['BACKUP_SSH_KEY_PATH'], $config['BACKUP_KNOWN_HOSTS_PATH'])) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "No existe el archivo SSH requerido: $path" }
    }

    $sshOptions = @(
        '-i', $config['BACKUP_SSH_KEY_PATH'],
        '-o', 'BatchMode=yes',
        '-o', 'StrictHostKeyChecking=yes',
        '-o', "UserKnownHostsFile=$($config['BACKUP_KNOWN_HOSTS_PATH'])",
        '-o', 'GlobalKnownHostsFile=none'
    )
    $verifyOutput = & $ssh @sshOptions "$sshUser@$sshHost" 'bash /home/respaldo/.local/bin/verificar_respaldo.sh' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "La VM rechazo o no pudo verificar los respaldos. $(($verifyOutput | Select-Object -Last 3) -join ' ')" }

    $latest = Get-ChildItem -LiteralPath $BackupDir -Filter '*.zip' -File |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { throw 'No hay un ZIP local que verificar en la VM.' }
    $remoteVerified = "$remoteRoot/verificados/$($latest.Name)"
    $remoteCommand = "test -s '$remoteVerified' && cd '$remoteRoot/verificados' && sha256sum --check --status '$($latest.Name).sha256'"
    $sshOutput = & $ssh @sshOptions "$sshUser@$sshHost" $remoteCommand 2>&1
    if ($LASTEXITCODE -ne 0) { throw "La VM no confirmo ZIP y SHA-256 en verificados. $(($sshOutput | Select-Object -Last 3) -join ' ')" }

    Write-Log "[OK] VM verifico el respaldo $($latest.Name) y su SHA-256."
    Get-ChildItem -LiteralPath $BackupDir -Filter '*.zip' -File |
        Where-Object { $_.FullName -ne $latest.FullName } |
        ForEach-Object {
            $oldChecksum = "$($_.FullName).sha256"
            Remove-Item -LiteralPath $_.FullName -Force
            if (Test-Path -LiteralPath $oldChecksum) { Remove-Item -LiteralPath $oldChecksum -Force }
            Write-Log "Eliminado respaldo local anterior: $($_.Name)."
        }
    Get-ChildItem -LiteralPath $BackupDir -Filter '*.sha256' -File |
        Where-Object { $_.Name -ne "$($latest.Name).sha256" } |
        Remove-Item -Force
} catch {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    Write-Log "[ERROR] $($_.Exception.Message)"
    exit 1
}
