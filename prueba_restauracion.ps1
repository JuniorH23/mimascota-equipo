[CmdletBinding()]
param(
    [string]$BackupDirectory = 'C:\mimascota\respaldos',
    [string]$ConfigPath = 'C:\mimascota\config\db.env'
)

$ErrorActionPreference = 'Stop'
$mysqlPassword = ''
$passwordPointer = [IntPtr]::Zero
$securePassword = $null
$temporaryDatabase = $null
$temporaryDirectory = $null
$databaseCreated = $false

function Read-EnvFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No existe la configuracion: $Path"
    }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -gt 0) {
            $values[$trimmed.Substring(0, $separator).Trim()] =
                $trimmed.Substring($separator + 1).Trim()
        }
    }
    return $values
}

function Invoke-MySql {
    param(
        [string]$Database,
        [string]$Query,
        [string]$InputFile
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $script:mysqlExe
    $startInfo.Arguments = "--protocol=tcp --host=$script:dbHost --port=$script:dbPort --user=$script:adminUser --batch --raw --skip-column-names"
    if ($Database) { $startInfo.Arguments += " --database=$Database" }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['MYSQL_PWD'] = $script:mysqlPassword

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $outputTask = $process.StandardOutput.ReadToEndAsync()
    $errorTask = $process.StandardError.ReadToEndAsync()

    if ($InputFile) {
        $stream = [IO.File]::OpenRead($InputFile)
        try {
            $stream.CopyTo($process.StandardInput.BaseStream)
        } finally {
            $stream.Dispose()
            $process.StandardInput.Close()
        }
    } else {
        $process.StandardInput.WriteLine($Query)
        $process.StandardInput.Close()
    }

    $process.WaitForExit()
    $output = $outputTask.Result.Trim()
    $errorOutput = $errorTask.Result.Trim()
    if ($process.ExitCode -ne 0) {
        throw "mysql termino con codigo $($process.ExitCode). $errorOutput"
    }
    return $output
}

function Get-DatabaseSummary {
    param([string]$Database)

    $tableNames = Invoke-MySql -Database $Database -Query `
        "SELECT table_name FROM information_schema.tables WHERE table_schema='$Database' AND table_type='BASE TABLE' ORDER BY table_name;"
    $tables = @()
    foreach ($tableName in ($tableNames -split "`r?`n" | Where-Object { $_ })) {
        if ($tableName -notmatch '^[A-Za-z0-9_]+$') {
            throw 'El nombre de una tabla contiene caracteres no permitidos.'
        }
        $count = Invoke-MySql -Database $Database -Query "SELECT COUNT(*) FROM ``$tableName``;"
        $tables += [PSCustomObject]@{ Tabla = $tableName; Filas = [long]$count }
    }

    $objectCounts = Invoke-MySql -Database $Database -Query `
        "SELECT (SELECT COUNT(*) FROM information_schema.views WHERE table_schema='$Database'), (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='$Database'), (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='$Database');"
    $parts = $objectCounts -split "`t"
    if ($parts.Count -ne 3) { throw 'No se pudieron leer los objetos de la base temporal.' }

    return [PSCustomObject]@{
        Tables = $tables
        Views = [int]$parts[0]
        Triggers = [int]$parts[1]
        Routines = [int]$parts[2]
    }
}

function Show-DatabaseSummary {
    param(
        [string]$Heading,
        $Summary
    )

    Write-Host "`n$Heading"
    $Summary.Tables | Format-Table -AutoSize | Out-Host
    Write-Host ("Tablas: {0}; vistas: {1}; disparadores: {2}; rutinas: {3}" -f `
        $Summary.Tables.Count, $Summary.Views, $Summary.Triggers, $Summary.Routines)
}

try {
    $backups = @(Get-ChildItem -LiteralPath $BackupDirectory -Filter '*.zip' -File |
        Sort-Object LastWriteTime -Descending)
    if ($backups.Count -eq 0) { throw "No hay respaldos ZIP en $BackupDirectory." }

    $backup = $backups[0]
    Write-Host '1. Respaldo seleccionado:'
    Write-Host ("   {0} ({1})" -f $backup.FullName, $backup.LastWriteTime)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($backup.FullName)
    try {
        if ($archive.Entries.Count -ne 1) {
            throw 'El ZIP debe contener exactamente un archivo SQL.'
        }
        $entry = $archive.Entries[0]
        if ($entry.Length -le 0 -or $entry.FullName -notmatch '^[A-Za-z0-9_.-]+\.sql$') {
            throw 'El ZIP no contiene un archivo SQL valido.'
        }
    } finally {
        $archive.Dispose()
    }

    $temporaryDirectory = Join-Path $env:TEMP ('mimascota-demo-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
    Expand-Archive -LiteralPath $backup.FullName -DestinationPath $temporaryDirectory
    $sqlFile = Join-Path $temporaryDirectory $entry.Name
    if (-not (Test-Path -LiteralPath $sqlFile -PathType Leaf)) {
        throw 'No se pudo extraer el archivo SQL del respaldo.'
    }
    if ((Get-Content -LiteralPath $sqlFile -Tail 30) -join "`n" -notmatch 'Dump completed') {
        throw 'El archivo SQL no contiene el marcador de respaldo completo.'
    }

    $config = Read-EnvFile -Path $ConfigPath
    $script:dbHost = if ($config['DB_HOST']) { $config['DB_HOST'] } else { '127.0.0.1' }
    $script:dbPort = if ($config['DB_PORT']) { $config['DB_PORT'] } else { '3307' }
    $script:mysqlExe = if ($config['MYSQL_PATH']) { $config['MYSQL_PATH'] } else { 'C:\xampp\mysql\bin\mysql.exe' }
    $script:adminUser = 'root'

    if ($script:dbHost -notmatch '^[A-Za-z0-9_.:-]+$' -or
        $script:dbPort -notmatch '^\d{1,5}$' -or [int]$script:dbPort -gt 65535) {
        throw 'La direccion o el puerto de MySQL en la configuracion no son validos.'
    }
    if (-not (Test-Path -LiteralPath $script:mysqlExe -PathType Leaf)) {
        throw "No se encontro mysql.exe en $script:mysqlExe."
    }

    try {
        Invoke-MySql -Query 'SELECT 1;' | Out-Null
    } catch {
        Write-Host 'Se necesita la contrasena del usuario administrador root.'
        $securePassword = Read-Host 'Contrasena de root (Enter si no tiene)' -AsSecureString
        $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $script:mysqlPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
        Invoke-MySql -Query 'SELECT 1;' | Out-Null
    }

    $temporaryDatabase = 'mimascota_demo_restore_' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    Invoke-MySql -Query "CREATE DATABASE $temporaryDatabase CHARACTER SET utf8mb4;" | Out-Null
    $databaseCreated = $true

    Write-Host "`n2. Informacion inicial del respaldo (base temporal; la base real no se toca):"
    Invoke-MySql -Database $temporaryDatabase -InputFile $sqlFile | Out-Null
    $before = Get-DatabaseSummary -Database $temporaryDatabase
    Show-DatabaseSummary -Heading '   Estado antes de simular el dano:' -Summary $before

    Write-Host "`n3. Simulando una alteracion en una mascota de la copia temporal..."
    Invoke-MySql -Database $temporaryDatabase -Query `
        "UPDATE mascotas SET nombre='__DANO_SIMULADO__' ORDER BY id_mascota LIMIT 1;" | Out-Null
    $damageCount = Invoke-MySql -Database $temporaryDatabase -Query `
        "SELECT COUNT(*) FROM mascotas WHERE nombre='__DANO_SIMULADO__';"
    if ([int]$damageCount -ne 1) { throw 'No se pudo verificar el dano simulado en la base temporal.' }
    Write-Host '   Alteracion simulada confirmada; solo cambio la copia temporal.'

    Write-Host "`n4. Restaurando la copia temporal desde el mismo ZIP..."
    Invoke-MySql -Database $temporaryDatabase -InputFile $sqlFile | Out-Null
    Write-Host '   Restauracion temporal completada.'

    Write-Host "`n5. Informacion despues de restaurar:"
    $after = Get-DatabaseSummary -Database $temporaryDatabase
    Show-DatabaseSummary -Heading '   Estado despues de restaurar:' -Summary $after
    $beforeRows = ($before.Tables | ForEach-Object { "$($_.Tabla)=$($_.Filas)" }) -join ';'
    $afterRows = ($after.Tables | ForEach-Object { "$($_.Tabla)=$($_.Filas)" }) -join ';'
    $remainingDamage = Invoke-MySql -Database $temporaryDatabase -Query `
        "SELECT COUNT(*) FROM mascotas WHERE nombre='__DANO_SIMULADO__';"
    if ($beforeRows -ne $afterRows -or $before.Views -ne $after.Views -or
        $before.Triggers -ne $after.Triggers -or $before.Routines -ne $after.Routines -or
        [int]$remainingDamage -ne 0) {
        throw 'La comparacion final no coincide con el estado del respaldo.'
    }
    Write-Host '   VERIFICACION OK: los conteos coinciden y no queda el dano simulado.'
    Write-Host '   La base real mimascota no fue modificada.'
} catch {
    Write-Error $_
    exit 1
} finally {
    if ($databaseCreated -and $temporaryDatabase) {
        Invoke-MySql -Query "DROP DATABASE $temporaryDatabase;" | Out-Null
        Write-Host "`nBase temporal eliminada: $temporaryDatabase"
    }
    if ($temporaryDirectory -and (Test-Path -LiteralPath $temporaryDirectory)) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
    if ($securePassword) { $securePassword.Dispose() }
    $script:mysqlPassword = ''
}
