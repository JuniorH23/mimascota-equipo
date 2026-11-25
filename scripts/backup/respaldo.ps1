[CmdletBinding()]
param(
    [switch]$LocalOnly
)

$ErrorActionPreference = 'Stop'
$Root = 'C:\mimascota'
$ConfigPath = if ($env:MIMASCOTA_CONFIG_PATH) { $env:MIMASCOTA_CONFIG_PATH } else { Join-Path $Root 'config\db.env' }
$BackupDir = Join-Path $Root 'respaldos'
$LogDir = Join-Path $Root 'logs'
$LogFile = Join-Path $LogDir 'respaldo.log'
$SqlFile = $null
$ZipFile = $null

function Write-Log {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    Write-Output $line
}

function Read-EnvFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No existe el archivo de configuracion: $Path"
    }
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -lt 1) { continue }
        $name = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1).Trim()
        $values[$name] = $value
    }
    return $values
}

try {
    New-Item -ItemType Directory -Force -Path $BackupDir, $LogDir | Out-Null
    $config = Read-EnvFile -Path $ConfigPath
    $DbHost = if ($config['DB_HOST']) { $config['DB_HOST'] } else { '127.0.0.1' }
    $DbPort = if ($config['DB_PORT']) { $config['DB_PORT'] } else { '3306' }
    $DbName = if ($config['DB_NAME']) { $config['DB_NAME'] } else { 'mimascota' }
    $DbUser = $config['DB_USER']
    $DbPass = $config['DB_PASS']
    $MysqldumpExe = if ($config['MYSQLDUMP_PATH']) { $config['MYSQLDUMP_PATH'] } else { 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe' }

    if ($DbName -notmatch '^[A-Za-z0-9_]+$') { throw 'DB_NAME solo puede contener letras, numeros y guion bajo.' }
    if ($DbPort -notmatch '^\d{1,5}$' -or [int]$DbPort -gt 65535) { throw 'DB_PORT no es valido.' }
    if ($DbUser -ne 'mimascota_backup') { throw 'Configura DB_USER=mimascota_backup para usar la cuenta de respaldo.' }
    if ([string]::IsNullOrWhiteSpace($DbPass)) { throw "DB_PASS esta vacio en $ConfigPath. Configura la clave localmente; no la incluyas en Git." }
    if (-not (Test-Path -LiteralPath $MysqldumpExe -PathType Leaf)) { throw "No se encontro mysqldump.exe en $MysqldumpExe" }

    $SshHost = $config['BACKUP_SSH_HOST']
    $SshUser = if ($config['BACKUP_SSH_USER']) { $config['BACKUP_SSH_USER'] } else { 'respaldo' }
    $RemoteRoot = if ($config['BACKUP_REMOTE_ROOT']) { $config['BACKUP_REMOTE_ROOT'] } else { '/var/backups/mimascota' }
    $SshKey = if ($config['BACKUP_SSH_KEY_PATH']) { $config['BACKUP_SSH_KEY_PATH'] } else { Join-Path $HOME '.ssh\mimascota_respaldo' }

    if (-not $LocalOnly) {
        if ($SshHost -notmatch '^[A-Za-z0-9.-]+$') { throw 'BACKUP_SSH_HOST no esta configurado o no es valido.' }
        if ($SshUser -notmatch '^[A-Za-z0-9._-]+$') { throw 'BACKUP_SSH_USER no es valido.' }
        if ($RemoteRoot -notmatch '^/[A-Za-z0-9/_-]+$' -or $RemoteRoot.Contains('..')) { throw 'BACKUP_REMOTE_ROOT no es valido.' }
        if (-not (Test-Path -LiteralPath $SshKey -PathType Leaf)) { throw "No se encontro la llave SSH en $SshKey" }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $SqlFile = Join-Path $BackupDir ("{0}_{1}.sql" -f $DbName, $timestamp)
    $ZipFile = Join-Path $BackupDir ("{0}_{1}.zip" -f $DbName, $timestamp)
    Write-Log "Iniciando respaldo de '$DbName' desde $DbHost`:$DbPort."

    $env:MYSQL_PWD = $DbPass
    try {
        $dumpOutput = & $MysqldumpExe `
            "--host=$DbHost" `
            "--port=$DbPort" `
            "--user=$DbUser" `
            '--single-transaction' `
            '--routines' `
            '--triggers' `
            '--default-character-set=utf8mb4' `
            "--result-file=$SqlFile" `
            $DbName 2>&1
        $dumpExitCode = $LASTEXITCODE
    } finally {
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    }

    if ($dumpExitCode -ne 0) {
        $detail = ($dumpOutput | Select-Object -Last 3) -join ' '
        throw "mysqldump finalizo con codigo $dumpExitCode. $detail"
    }
    if (-not (Test-Path -LiteralPath $SqlFile -PathType Leaf)) { throw 'mysqldump no creo el archivo SQL.' }
    if ((Get-Item -LiteralPath $SqlFile).Length -le 0) { throw 'El archivo SQL esta vacio.' }
    $tailText = (Get-Content -LiteralPath $SqlFile -Tail 30) -join "`n"
    if ($tailText -notmatch 'Dump completed') { throw "El volcado no contiene el marcador 'Dump completed'." }

    Compress-Archive -LiteralPath $SqlFile -DestinationPath $ZipFile -Force
    if (-not (Test-Path -LiteralPath $ZipFile -PathType Leaf) -or (Get-Item -LiteralPath $ZipFile).Length -le 0) {
        throw 'No se pudo validar el archivo ZIP.'
    }
    Remove-Item -LiteralPath $SqlFile -Force
    $SqlFile = $null
    Write-Log "ZIP local validado: $(Split-Path -Leaf $ZipFile)."

    if (-not $LocalOnly) {
        $remoteTarget = "$($SshUser)@$($SshHost):$($RemoteRoot)/entrantes/"
        $scpOutput = & scp -i $SshKey -o BatchMode=yes -o StrictHostKeyChecking=yes $ZipFile $remoteTarget 2>&1
        if ($LASTEXITCODE -ne 0) {
            $detail = ($scpOutput | Select-Object -Last 3) -join ' '
            throw "scp fallo con codigo $LASTEXITCODE. $detail"
        }
        Write-Log "Respaldo enviado al directorio entrantes del servidor configurado."
    } else {
        Write-Log 'Modo LocalOnly: se omitio la transferencia SSH.'
    }

    Get-ChildItem -LiteralPath $BackupDir -Filter '*.zip' -File |
        Where-Object { $_.FullName -ne $ZipFile } |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
            Write-Log "Eliminado respaldo local anterior: $($_.Name)."
        }
    Write-Log "[OK] Respaldo completado con exito: $(Split-Path -Leaf $ZipFile)"
} catch {
    if ($SqlFile -and (Test-Path -LiteralPath $SqlFile)) {
        Remove-Item -LiteralPath $SqlFile -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
    Write-Log "[ERROR] $($_.Exception.Message)"
    exit 1
} finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
