[CmdletBinding()]
param(
    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'
$Root = 'C:\mimascota'
$ConfigPath = Join-Path $Root 'config\mysql80-backup.env'
$BackupDir = Join-Path $Root 'respaldos'
$LogDir = Join-Path $Root 'logs'
$LogFile = Join-Path $LogDir 'restaurar.log'
$TempDir = $null
$SecurePassword = $null
$PasswordBstr = [IntPtr]::Zero

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

function Get-RemoteOutput {
    param([string]$Command)
    $result = & $SshExe @SshOptions "$SshUser@$SshHost" $Command 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Fallo la consulta remota. $(($result | Select-Object -Last 3) -join ' ')" }
    return (($result | Out-String).Trim())
}

try {
    New-Item -ItemType Directory -Force -Path $BackupDir, $LogDir | Out-Null
    $config = Read-EnvFile -Path $ConfigPath
    $dbName = if ($config['DB_NAME']) { $config['DB_NAME'] } else { 'mimascota' }
    $dbHost = if ($config['DB_HOST']) { $config['DB_HOST'] } else { '127.0.0.1' }
    $dbPort = if ($config['DB_PORT']) { $config['DB_PORT'] } else { '3306' }
    $mysqlExe = if ($config['MYSQL_PATH']) { $config['MYSQL_PATH'] } else { 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe' }
    $SshExe = if ($config['SSH_PATH']) { $config['SSH_PATH'] } else { 'C:\Windows\System32\OpenSSH\ssh.exe' }
    $scpExe = if ($config['SCP_PATH']) { $config['SCP_PATH'] } else { 'C:\Windows\System32\OpenSSH\scp.exe' }
    $SshHost = $config['BACKUP_SSH_HOST']
    $SshUser = if ($config['BACKUP_SSH_USER']) { $config['BACKUP_SSH_USER'] } else { 'respaldo' }
    $sshKey = $config['BACKUP_SSH_KEY_PATH']
    $knownHosts = $config['BACKUP_KNOWN_HOSTS_PATH']
    $remoteRoot = if ($config['BACKUP_REMOTE_ROOT']) { $config['BACKUP_REMOTE_ROOT'] } else { '/var/backups/mimascota' }

    if ($dbName -notmatch '^[A-Za-z0-9_]+$' -or $dbPort -notmatch '^\d{1,5}$' -or [int]$dbPort -gt 65535) { throw 'DB_NAME o DB_PORT no es valido.' }
    if (-not (Test-Path -LiteralPath $mysqlExe -PathType Leaf)) { throw "No se encontro mysql.exe en $mysqlExe" }

    if ($BackupPath) {
        $localZip = (Resolve-Path -LiteralPath $BackupPath).Path
        $backupRoot = (Resolve-Path -LiteralPath $BackupDir).Path.TrimEnd('\') + '\'
        if (-not $localZip.StartsWith($backupRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "El ZIP local debe estar dentro de $BackupDir." }
    } else {
        foreach ($path in @($SshExe, $scpExe, $sshKey, $knownHosts)) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "No existe el archivo SSH requerido: $path" }
        }
        if ($SshHost -notmatch '^[A-Za-z0-9.-]+$' -or $SshUser -notmatch '^[A-Za-z0-9._-]+$') { throw 'La configuracion SSH no es valida.' }
        if ($remoteRoot -notmatch '^/[A-Za-z0-9/_-]+$' -or $remoteRoot.Contains('..')) { throw 'BACKUP_REMOTE_ROOT no es valido.' }
        $SshOptions = @('-i', $sshKey, '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', "UserKnownHostsFile=$knownHosts", '-o', 'GlobalKnownHostsFile=none')
        $latestCommand = "find '$remoteRoot/verificados' -maxdepth 1 -type f -name 'mimascota_*.zip' -printf '%T@ %f\n' | sort -nr | head -n 1 | cut -d' ' -f2-"
        $archiveName = (Get-RemoteOutput -Command $latestCommand).Trim()
        if ($archiveName -notmatch '^mimascota_[A-Za-z0-9._-]+\.zip$') { throw 'No hay un ZIP mimascota en /var/backups/mimascota/verificados/.' }
        $remotePath = "$remoteRoot/verificados/$archiveName"
        $remoteHashOutput = Get-RemoteOutput -Command "sha256sum -- '$remotePath'"
        $remoteHash = $remoteHashOutput.Split(' ')[0].ToLowerInvariant()
        if ($remoteHash -notmatch '^[0-9a-f]{64}$') { throw 'La VM devolvio un SHA-256 invalido.' }

        $localZip = Join-Path $BackupDir $archiveName
        $remoteSource = '{0}@{1}:{2}' -f $SshUser, $SshHost, $remotePath
        $scpOutput = & $scpExe @SshOptions $remoteSource $localZip 2>&1
        if ($LASTEXITCODE -ne 0) { throw "No se pudo descargar el respaldo verificado. $(($scpOutput | Select-Object -Last 3) -join ' ')" }
        $localHash = (Get-FileHash -LiteralPath $localZip -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($localHash -ne $remoteHash) { throw 'El SHA-256 local no coincide con el de la VM.' }
        $checksumLine = "$localHash  $archiveName`n"
        [IO.File]::WriteAllText("$localZip.sha256", $checksumLine, [Text.Encoding]::ASCII)
        Write-Log "[OK] ZIP descargado y SHA-256 validado: $archiveName."
    }

    if ([IO.Path]::GetExtension($localZip) -ne '.zip') { throw 'El respaldo debe ser un archivo .zip.' }
    $checksumFile = "$localZip.sha256"
    if (-not (Test-Path -LiteralPath $checksumFile -PathType Leaf)) { throw 'Falta el archivo local SHA-256; no se restaurara.' }
    $checksumLine = (Get-Content -LiteralPath $checksumFile -TotalCount 1).Trim()
    if ($checksumLine -notmatch '^([0-9a-fA-F]{64})  ([A-Za-z0-9._-]+\.zip)$' -or $Matches[2] -ne (Split-Path -Leaf $localZip)) {
        throw 'El archivo SHA-256 no tiene el formato esperado.'
    }
    $expectedHash = $Matches[1].ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $localZip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) { throw 'El SHA-256 del respaldo no coincide.' }

    $TempDir = Join-Path $env:TEMP ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $TempDir | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($localZip)
    try {
        if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].FullName -notmatch '^[A-Za-z0-9._-]+\.sql$') {
            throw 'El ZIP debe contener exactamente un archivo SQL con nombre valido.'
        }
        $sqlFile = Join-Path $TempDir $zip.Entries[0].Name
        $entryStream = $zip.Entries[0].Open()
        $outputStream = [IO.File]::Create($sqlFile)
        try { $entryStream.CopyTo($outputStream) } finally { $outputStream.Dispose(); $entryStream.Dispose() }
    } finally {
        $zip.Dispose()
    }
    if ((Get-Item -LiteralPath $sqlFile).Length -le 0 -or ((Get-Content -LiteralPath $sqlFile -Tail 30) -join "`n") -notmatch 'Dump completed') {
        throw "El volcado esta vacio o incompleto (falta 'Dump completed')."
    }

    Write-Log "Se restaurara $(Split-Path -Leaf $localZip) en $dbHost`:$dbPort/$dbName."
    $confirmation = Read-Host "Escriba RESTAURAR $dbName para sobrescribir las tablas de destino"
    if ($confirmation -cne "RESTAURAR $dbName") {
        Write-Log 'Restauracion cancelada; no se ejecuto mysql.'
        exit 2
    }

    $restoreUser = Read-Host 'Usuario MySQL con permisos de restauracion'
    if ($restoreUser -notmatch '^[A-Za-z0-9_.@-]+$') { throw 'El usuario MySQL no es valido.' }
    $SecurePassword = Read-Host 'Contrasena MySQL de restauracion' -AsSecureString
    $PasswordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $restorePassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($PasswordBstr)
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $mysqlExe
    $startInfo.Arguments = "--host=$dbHost --port=$dbPort --user=$restoreUser --database=$dbName"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['MYSQL_PWD'] = $restorePassword
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $sqlStream = [IO.File]::OpenRead($sqlFile)
    try { $sqlStream.CopyTo($process.StandardInput.BaseStream) } finally { $sqlStream.Dispose(); $process.StandardInput.Close() }
    $process.WaitForExit()
    $mysqlError = $stderrTask.Result
    if ($process.ExitCode -ne 0) { throw "mysql termino con codigo $($process.ExitCode). $mysqlError" }

    Write-Log "[OK] Restauracion completada en la base '$dbName'."
} catch {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    Write-Log "[ERROR] $($_.Exception.Message)"
    exit 1
} finally {
    if ($TempDir -and (Test-Path -LiteralPath $TempDir)) { Remove-Item -LiteralPath $TempDir -Recurse -Force }
    if ($PasswordBstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordBstr) }
    if ($SecurePassword) { $SecurePassword.Dispose() }
}
