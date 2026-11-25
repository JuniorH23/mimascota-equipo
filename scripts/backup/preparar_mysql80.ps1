[CmdletBinding()]
param(
    [string]$SshHost,
    [string]$SshUser
)

$ErrorActionPreference = 'Stop'
$Root = 'C:\mimascota'
$ConfigDir = Join-Path $Root 'config'
$BackupDir = Join-Path $Root 'respaldos'
$LogDir = Join-Path $Root 'logs'
$ConfigPath = Join-Path $ConfigDir 'mysql80-backup.env'
$MysqlExe = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$SshExe = 'C:\Windows\System32\OpenSSH\ssh.exe'
$ScpExe = 'C:\Windows\System32\OpenSSH\scp.exe'
$SshKey = Join-Path $HOME '.ssh\mimascota_respaldo'
$KnownHosts = Join-Path $ConfigDir 'ssh_known_hosts'
$RemoteRoot = '/var/backups/mimascota'
$TempDir = Join-Path $env:TEMP ('mimascota-bootstrap-' + [guid]::NewGuid().ToString('N'))
$SecurePassword = $null
$PasswordBstr = [IntPtr]::Zero

function Quote-ProcessArgument {
    param([string]$Argument)
    $escaped = $Argument -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Invoke-MySql {
    param(
        [string[]]$Arguments,
        [string]$Password,
        [string]$InputFile
    )
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $MysqlExe
    $startInfo.Arguments = (($Arguments | ForEach-Object { Quote-ProcessArgument $_ }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.EnvironmentVariables['MYSQL_PWD'] = $Password
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if ($InputFile) {
        $stream = [IO.File]::OpenRead($InputFile)
        try { $stream.CopyTo($process.StandardInput.BaseStream) } finally { $stream.Dispose(); $process.StandardInput.Close() }
    } else {
        $process.StandardInput.Close()
    }
    $process.WaitForExit()
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    if ($process.ExitCode -ne 0) { throw "mysql termino con codigo $($process.ExitCode). $stderr" }
    return $stdout
}

try {
    if (-not (Test-Path -LiteralPath $MysqlExe -PathType Leaf)) { throw "No se encontro mysql.exe: $MysqlExe" }
    if ([string]::IsNullOrWhiteSpace($SshHost)) { $SshHost = Read-Host 'Nombre DNS o IP de la VM de respaldos' }
    if ([string]::IsNullOrWhiteSpace($SshUser)) { $SshUser = Read-Host 'Usuario SSH de la VM de respaldos' }
    if ($SshHost -notmatch '^[A-Za-z0-9.-]+$' -or $SshUser -notmatch '^[A-Za-z0-9._-]+$') {
        throw 'El host o usuario SSH no es valido.'
    }
    foreach ($path in @($SshExe, $ScpExe, $SshKey, $KnownHosts)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "No se encontro el archivo requerido: $path" }
    }
    New-Item -ItemType Directory -Force -Path $ConfigDir, $BackupDir, $LogDir, $TempDir | Out-Null

    $sshOptions = @('-i', $SshKey, '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', "UserKnownHostsFile=$KnownHosts", '-o', 'GlobalKnownHostsFile=none')
    $listCommand = "find '$RemoteRoot/verificados' -maxdepth 1 -type f -name '*.zip' -printf '%T@ %f\n' | sort -nr | head -n 1 | cut -d' ' -f2-"
    $remoteList = & $SshExe @sshOptions "$SshUser@$SshHost" $listCommand 2>&1
    if ($LASTEXITCODE -ne 0) { throw "No se pudieron consultar respaldos verificados en la VM. $(($remoteList | Select-Object -Last 3) -join ' ')" }
    $archiveName = ($remoteList | Select-Object -First 1).ToString().Trim()
    if ($archiveName -notmatch '^mimascota_[A-Za-z0-9._-]+\.zip$') { throw 'No hay un ZIP mimascota valido en el directorio remoto verificados.' }

    $remoteArchive = "$RemoteRoot/verificados/$archiveName"
    $remoteHashOutput = & $SshExe @sshOptions "$SshUser@$SshHost" "sha256sum -- '$remoteArchive'" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "No se pudo calcular SHA-256 remoto. $(($remoteHashOutput | Select-Object -Last 3) -join ' ')" }
    $remoteHash = ($remoteHashOutput | Select-Object -First 1).ToString().Split(' ')[0].ToLowerInvariant()
    if ($remoteHash -notmatch '^[0-9a-f]{64}$') { throw 'La VM devolvio un SHA-256 invalido.' }

    $localArchive = Join-Path $TempDir $archiveName
    $remoteSource = '{0}@{1}:{2}' -f $SshUser, $SshHost, $remoteArchive
    $scpOutput = & $ScpExe @sshOptions $remoteSource $localArchive 2>&1
    if ($LASTEXITCODE -ne 0) { throw "No se pudo descargar el ZIP verificado. $(($scpOutput | Select-Object -Last 3) -join ' ')" }
    $localHash = (Get-FileHash -LiteralPath $localArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($localHash -ne $remoteHash) { throw 'El SHA-256 local no coincide con el valor calculado en la VM.' }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($localArchive)
    try {
        if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].FullName -notmatch '^mimascota_[A-Za-z0-9._-]+\.sql$') {
            throw 'El ZIP debe contener exactamente un SQL mimascota.'
        }
        $sqlFile = Join-Path $TempDir $zip.Entries[0].Name
        $entryStream = $zip.Entries[0].Open()
        $outputStream = [IO.File]::Create($sqlFile)
        try { $entryStream.CopyTo($outputStream) } finally { $outputStream.Dispose(); $entryStream.Dispose() }
    } finally {
        $zip.Dispose()
    }
    if ((Get-Item -LiteralPath $sqlFile).Length -le 0 -or ((Get-Content -LiteralPath $sqlFile -Tail 30) -join "`n") -notmatch 'Dump completed') {
        throw 'El SQL remoto esta vacio o incompleto.'
    }

    $SecurePassword = Read-Host 'Contrasena de root para MySQL 8.0 (se usa solo localmente)' -AsSecureString
    $PasswordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $rootPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($PasswordBstr)
    $baseArgs = @('--host=127.0.0.1', '--port=3306', '--user=root', '--batch', '--skip-column-names')
    $databaseExists = [int]((Invoke-MySql -Arguments ($baseArgs + @('-e', "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='mimascota';")) -Password $rootPassword).Trim())
    if ($databaseExists -eq 0) {
        Invoke-MySql -Arguments ($baseArgs + @('-e', 'CREATE DATABASE `mimascota` CHARACTER SET utf8mb4;')) -Password $rootPassword | Out-Null
        try {
            Invoke-MySql -Arguments ($baseArgs + @('--database=mimascota')) -Password $rootPassword -InputFile $sqlFile | Out-Null
        } catch {
            Invoke-MySql -Arguments ($baseArgs + @('-e', 'DROP DATABASE IF EXISTS `mimascota`;')) -Password $rootPassword | Out-Null
            throw "La importacion fallo; se elimino la base parcial creada por este proceso. $($_.Exception.Message)"
        }
        Write-Output 'Base mimascota importada en MySQL 8.0 porque no existia.'
    } else {
        Write-Output 'La base mimascota ya existe; no se modifico ni se sobrescribio.'
    }

    $backupBytes = New-Object byte[] 48
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($backupBytes) } finally { $rng.Dispose() }
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $backupPassword = -join ($backupBytes | ForEach-Object { $alphabet[[int]$_ % $alphabet.Length] })
    $serverVersion = (Invoke-MySql -Arguments ($baseArgs + @('-e', 'SELECT VERSION();')) -Password $rootPassword).Trim()
    $grantSql = @"
CREATE USER IF NOT EXISTS 'mimascota_backup'@'localhost' IDENTIFIED BY '$backupPassword';
ALTER USER 'mimascota_backup'@'localhost' IDENTIFIED BY '$backupPassword';
CREATE USER IF NOT EXISTS 'mimascota_backup'@'127.0.0.1' IDENTIFIED BY '$backupPassword';
ALTER USER 'mimascota_backup'@'127.0.0.1' IDENTIFIED BY '$backupPassword';
GRANT SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES ON `mimascota`.* TO 'mimascota_backup'@'localhost';
GRANT SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES ON `mimascota`.* TO 'mimascota_backup'@'127.0.0.1';
"@
    if ($serverVersion -match '^8\.0\.(\d+)' -and [int]$Matches[1] -ge 20) {
        $grantSql += "`nGRANT SHOW_ROUTINE ON *.* TO 'mimascota_backup'@'localhost';`nGRANT SHOW_ROUTINE ON *.* TO 'mimascota_backup'@'127.0.0.1';"
    }
    $grantFile = Join-Path $TempDir 'create-backup-user.sql'
    Set-Content -LiteralPath $grantFile -Value $grantSql -Encoding ASCII
    Invoke-MySql -Arguments ($baseArgs + @()) -Password $rootPassword -InputFile $grantFile | Out-Null

    $config = @(
        'DB_HOST=127.0.0.1',
        'DB_PORT=3306',
        'DB_NAME=mimascota',
        'DB_USER=mimascota_backup',
        "DB_PASS=$backupPassword",
        "MYSQL_PATH=$MysqlExe",
        "MYSQLDUMP_PATH=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe",
        "SSH_PATH=$SshExe",
        "SCP_PATH=$ScpExe",
        "BACKUP_SSH_HOST=$SshHost",
        "BACKUP_SSH_USER=$SshUser",
        "BACKUP_SSH_KEY_PATH=$SshKey",
        "BACKUP_KNOWN_HOSTS_PATH=$KnownHosts",
        "BACKUP_REMOTE_ROOT=$RemoteRoot"
    )
    New-Item -ItemType File -Force -Path $ConfigPath | Out-Null
    & icacls.exe $ConfigPath /inheritance:r /grant:r '*S-1-5-18:(R)' '*S-1-5-32-544:(F)' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -LiteralPath $ConfigPath -Force -ErrorAction SilentlyContinue
        throw "No se pudieron proteger los permisos de $ConfigPath."
    }
    Set-Content -LiteralPath $ConfigPath -Value $config -Encoding ASCII
    foreach ($directory in @($BackupDir, $LogDir)) {
        & icacls.exe $directory /grant '*S-1-5-18:(OI)(CI)(M)' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "No se pudo conceder acceso SYSTEM a $directory." }
    }
    & icacls.exe $SshKey /grant '*S-1-5-18:(R)' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo conceder lectura SYSTEM a la llave SSH.' }
    & icacls.exe $KnownHosts /grant '*S-1-5-18:(R)' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo conceder lectura SYSTEM al archivo known_hosts.' }

    Write-Output "Configuracion MySQL 8.0 lista en $ConfigPath; la contrasena de respaldo no se muestra."
} catch {
    Write-Error $_
    exit 1
} finally {
    if ($PasswordBstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordBstr) }
    if ($SecurePassword) { $SecurePassword.Dispose() }
    if (Test-Path -LiteralPath $TempDir) { Remove-Item -LiteralPath $TempDir -Recurse -Force }
}
