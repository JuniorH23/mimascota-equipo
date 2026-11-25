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
    $dbHost = if ($config['DB_HOST']) { $config['DB_HOST'] } else { '127.0.0.1' }
    $dbPort = if ($config['DB_PORT']) { $config['DB_PORT'] } else { '3306' }
    $dbName = if ($config['DB_NAME']) { $config['DB_NAME'] } else { 'mimascota' }
    $dbUser = $config['DB_USER']
    $dbPass = $config['DB_PASS']
    $mysqldump = if ($config['MYSQLDUMP_PATH']) { $config['MYSQLDUMP_PATH'] } else { 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe' }
    $ssh = if ($config['SSH_PATH']) { $config['SSH_PATH'] } else { 'C:\Windows\System32\OpenSSH\ssh.exe' }
    $scp = if ($config['SCP_PATH']) { $config['SCP_PATH'] } else { 'C:\Windows\System32\OpenSSH\scp.exe' }
    $sshHost = $config['BACKUP_SSH_HOST']
    $sshUser = if ($config['BACKUP_SSH_USER']) { $config['BACKUP_SSH_USER'] } else { 'respaldo' }
    $sshKey = $config['BACKUP_SSH_KEY_PATH']
    $knownHosts = $config['BACKUP_KNOWN_HOSTS_PATH']
    $remoteRoot = if ($config['BACKUP_REMOTE_ROOT']) { $config['BACKUP_REMOTE_ROOT'] } else { '/var/backups/mimascota' }

    if ($dbName -notmatch '^[A-Za-z0-9_]+$' -or $dbPort -notmatch '^\d{1,5}$' -or [int]$dbPort -gt 65535) { throw 'DB_NAME o DB_PORT no es valido.' }
    if ($dbUser -ne 'mimascota_backup' -or [string]::IsNullOrWhiteSpace($dbPass)) { throw 'Configura DB_USER=mimascota_backup y DB_PASS en el archivo privado.' }
    if ($sshHost -notmatch '^[A-Za-z0-9.-]+$' -or $sshUser -notmatch '^[A-Za-z0-9._-]+$') { throw 'La configuracion SSH no es valida.' }
    if ($remoteRoot -notmatch '^/[A-Za-z0-9/_-]+$' -or $remoteRoot.Contains('..')) { throw 'BACKUP_REMOTE_ROOT no es valido.' }
    foreach ($path in @($mysqldump, $ssh, $scp, $sshKey, $knownHosts)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "No existe el archivo requerido: $path" }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $sqlFile = Join-Path $BackupDir ("{0}_{1}.sql" -f $dbName, $timestamp)
    $zipFile = Join-Path $BackupDir ("{0}_{1}.zip" -f $dbName, $timestamp)
    $checksumFile = "$zipFile.sha256"
    Write-Log "Iniciando mysqldump de $dbName en MySQL 8.0 ($dbHost`:$dbPort)."

    $env:MYSQL_PWD = $dbPass
    try {
        $dumpOutput = & $mysqldump "--host=$dbHost" "--port=$dbPort" "--user=$dbUser" `
            '--single-transaction' '--routines' '--triggers' '--events' '--no-tablespaces' `
            '--default-character-set=utf8mb4' "--result-file=$sqlFile" $dbName 2>&1
        $dumpExitCode = $LASTEXITCODE
    } finally {
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    }
    if ($dumpExitCode -ne 0) {
        throw "mysqldump finalizo con codigo $dumpExitCode. $(($dumpOutput | Select-Object -Last 3) -join ' ')"
    }
    if (-not (Test-Path -LiteralPath $sqlFile -PathType Leaf) -or (Get-Item -LiteralPath $sqlFile).Length -le 0) { throw 'mysqldump no creo un SQL valido.' }
    if (((Get-Content -LiteralPath $sqlFile -Tail 30) -join "`n") -notmatch 'Dump completed') { throw "El SQL no contiene el marcador 'Dump completed'." }

    Compress-Archive -LiteralPath $sqlFile -DestinationPath $zipFile -CompressionLevel Optimal
    Remove-Item -LiteralPath $sqlFile -Force
    if ((Get-Item -LiteralPath $zipFile).Length -le 0) { throw 'El ZIP esta vacio.' }
    $zipHash = (Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksumLine = "$zipHash  $(Split-Path -Leaf $zipFile)`n"
    [IO.File]::WriteAllText($checksumFile, $checksumLine, [Text.Encoding]::ASCII)
    Write-Log "ZIP y SHA-256 creados: $(Split-Path -Leaf $zipFile)."

    $sshOptions = @('-i', $sshKey, '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', "UserKnownHostsFile=$knownHosts", '-o', 'GlobalKnownHostsFile=none')
    $remoteTarget = '{0}@{1}:{2}/entrantes/' -f $sshUser, $sshHost, $remoteRoot
    $scpOutput = & $scp @sshOptions $zipFile $checksumFile $remoteTarget 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo subir ZIP y SHA-256 por SCP (codigo $LASTEXITCODE). $(($scpOutput | Select-Object -Last 3) -join ' ')"
    }
    Write-Log '[OK] ZIP y SHA-256 enviados a la VM para verificacion.'
} catch {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    Write-Log "[ERROR] $($_.Exception.Message)"
    exit 1
} finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    if ($sqlFile -and (Test-Path -LiteralPath $sqlFile)) { Remove-Item -LiteralPath $sqlFile -Force -ErrorAction SilentlyContinue }
}
