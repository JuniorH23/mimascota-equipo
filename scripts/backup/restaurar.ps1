$ErrorActionPreference = 'Stop'
$Root = 'C:\mimascota'
$ConfigPath = if ($env:MIMASCOTA_CONFIG_PATH) { $env:MIMASCOTA_CONFIG_PATH } else { Join-Path $Root 'config\db.env' }
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
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "No existe el archivo de configuracion: $Path" }
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -lt 1) { continue }
        $values[$trimmed.Substring(0, $separator).Trim()] = $trimmed.Substring($separator + 1).Trim()
    }
    return $values
}

try {
    New-Item -ItemType Directory -Force -Path $BackupDir, $LogDir | Out-Null
    $config = Read-EnvFile -Path $ConfigPath
    $DbName = if ($config['DB_NAME']) { $config['DB_NAME'] } else { 'mimascota' }
    $DbHost = if ($config['DB_HOST']) { $config['DB_HOST'] } else { '127.0.0.1' }
    $DbPort = if ($config['DB_PORT']) { $config['DB_PORT'] } else { '3306' }
    $MysqlExe = if ($config['MYSQL_PATH']) { $config['MYSQL_PATH'] } else { 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe' }
    $SshHost = $config['BACKUP_SSH_HOST']
    $SshUser = if ($config['BACKUP_SSH_USER']) { $config['BACKUP_SSH_USER'] } else { 'respaldo' }
    $RemoteRoot = if ($config['BACKUP_REMOTE_ROOT']) { $config['BACKUP_REMOTE_ROOT'] } else { '/var/backups/mimascota' }
    $SshKey = if ($config['BACKUP_SSH_KEY_PATH']) { $config['BACKUP_SSH_KEY_PATH'] } else { Join-Path $HOME '.ssh\mimascota_respaldo' }

    if ($DbName -notmatch '^[A-Za-z0-9_]+$') { throw 'DB_NAME solo puede contener letras, numeros y guion bajo.' }
    if ($DbPort -notmatch '^\d{1,5}$' -or [int]$DbPort -gt 65535) { throw 'DB_PORT no es valido.' }
    if ($SshHost -notmatch '^[A-Za-z0-9.-]+$' -or $SshUser -notmatch '^[A-Za-z0-9._-]+$') { throw 'Configura BACKUP_SSH_HOST y BACKUP_SSH_USER.' }
    if ($RemoteRoot -notmatch '^/[A-Za-z0-9/_-]+$' -or $RemoteRoot.Contains('..')) { throw 'BACKUP_REMOTE_ROOT no es valido.' }
    if (-not (Test-Path -LiteralPath $SshKey -PathType Leaf)) { throw "No se encontro la llave SSH en $SshKey" }
    if (-not (Test-Path -LiteralPath $MysqlExe -PathType Leaf)) { throw "No se encontro mysql.exe en $MysqlExe" }

    $remoteHost = "$($SshUser)@$($SshHost)"
    $remoteDir = "$RemoteRoot/verificados"
    $latestOutput = & ssh -i $SshKey -o BatchMode=yes -o StrictHostKeyChecking=yes $remoteHost "ls -1t '$remoteDir'/*.zip 2>/dev/null | head -n 1" 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar la carpeta de respaldos verificados.' }
    $remoteZip = ($latestOutput | Select-Object -Last 1).ToString().Trim()
    if ($remoteZip -notmatch ('^' + [regex]::Escape($remoteDir) + '/[A-Za-z0-9._-]+\.zip$')) {
        throw 'No hay un ZIP verificado disponible en el servidor.'
    }

    $localZip = Join-Path $BackupDir ([IO.Path]::GetFileName($remoteZip))
    $scpOutput = & scp -i $SshKey -o BatchMode=yes -o StrictHostKeyChecking=yes "${remoteHost}:$remoteZip" $localZip 2>&1
    if ($LASTEXITCODE -ne 0) { throw "No se pudo descargar el respaldo verificado. $($scpOutput | Select-Object -Last 1)" }

    $TempDir = Join-Path $env:TEMP ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $TempDir | Out-Null
    Expand-Archive -LiteralPath $localZip -DestinationPath $TempDir
    $sqlFiles = @(Get-ChildItem -LiteralPath $TempDir -Filter '*.sql' -File)
    if ($sqlFiles.Count -ne 1) { throw 'El ZIP debe contener exactamente un archivo SQL.' }
    if ((Get-Item -LiteralPath $sqlFiles[0].FullName).Length -le 0) { throw 'El archivo SQL del respaldo esta vacio.' }
    $tailText = (Get-Content -LiteralPath $sqlFiles[0].FullName -Tail 30) -join "`n"
    if ($tailText -notmatch 'Dump completed') { throw "El volcado no contiene el marcador 'Dump completed'." }

    Write-Log "Se descargara y cargara el respaldo en $DbHost`:$DbPort/$DbName."
    $confirmation = Read-Host "Escriba RESTAURAR $DbName para sobrescribir las tablas de destino"
    if ($confirmation -cne "RESTAURAR $DbName") {
        Write-Log 'Restauracion cancelada; no se ejecuto mysql.'
        exit 2
    }

    $restoreUser = Read-Host 'Usuario MySQL con permisos de restauracion'
    if ($restoreUser -notmatch '^[A-Za-z0-9_.@-]+$') { throw 'El usuario MySQL no es valido.' }
    $SecurePassword = Read-Host 'Contrasena MySQL de restauracion' -AsSecureString
    $PasswordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $restorePassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($PasswordBstr)

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $MysqlExe
    $startInfo.Arguments = "--host=$DbHost --port=$DbPort --user=$restoreUser --database=$DbName"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['MYSQL_PWD'] = $restorePassword
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $sqlStream = [IO.File]::OpenRead($sqlFiles[0].FullName)
    try {
        $sqlStream.CopyTo($process.StandardInput.BaseStream)
    } finally {
        $sqlStream.Dispose()
        $process.StandardInput.Close()
    }
    $process.WaitForExit()
    $mysqlError = $stderrTask.Result
    if ($process.ExitCode -ne 0) { throw "mysql termino con codigo $($process.ExitCode). $mysqlError" }

    Write-Log "[OK] Restauracion completada en la base '$DbName'."
} catch {
    if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
    Write-Log "[ERROR] $($_.Exception.Message)"
    exit 1
} finally {
    if ($TempDir -and (Test-Path -LiteralPath $TempDir)) { Remove-Item -LiteralPath $TempDir -Recurse -Force }
    if ($PasswordBstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordBstr) }
    if ($SecurePassword) { $SecurePassword.Dispose() }
}
