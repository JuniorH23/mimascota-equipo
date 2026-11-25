[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$TaskName = 'MiMascota-Backup-03AM'
$ConfigPath = 'C:\mimascota\config\mysql80-backup.env'
$VerifierPath = Join-Path $PSScriptRoot 'verificar_respaldo.sh'
$LogDir = 'C:\mimascota\logs'
$LogFile = Join-Path $LogDir 'tarea.log'

function Write-Log {
    param([string]$Message)
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    Write-Output $line
}

try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principalCheck = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principalCheck.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Ejecuta tarea.ps1 desde PowerShell abierto como Administrador.'
    }
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Primero ejecuta preparar_mysql80.ps1; falta $ConfigPath."
    }
    if (-not (Test-Path -LiteralPath $VerifierPath -PathType Leaf)) { throw "No existe el verificador: $VerifierPath" }
    & icacls.exe $PSScriptRoot /grant '*S-1-5-18:(OI)(CI)(RX)' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "No se pudo conceder lectura y ejecucion SYSTEM en $PSScriptRoot." }

    $config = @{}
    foreach ($line in Get-Content -LiteralPath $ConfigPath) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $separator = $trimmed.IndexOf('=')
        if ($separator -gt 0) { $config[$trimmed.Substring(0, $separator).Trim()] = $trimmed.Substring($separator + 1).Trim() }
    }
    $ssh = $config['SSH_PATH']
    $scp = $config['SCP_PATH']
    $sshHost = $config['BACKUP_SSH_HOST']
    $sshUser = $config['BACKUP_SSH_USER']
    $sshKey = $config['BACKUP_SSH_KEY_PATH']
    $knownHosts = $config['BACKUP_KNOWN_HOSTS_PATH']
    if ([string]::IsNullOrWhiteSpace($config['DB_PASS'])) { throw 'La configuracion no tiene una contrasena DB_PASS.' }
    foreach ($path in @($ssh, $scp, $sshKey, $knownHosts)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "No existe el archivo requerido: $path" }
    }

    $options = @('-i', $sshKey, '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', '-o', "UserKnownHostsFile=$knownHosts", '-o', 'GlobalKnownHostsFile=none')
    $remoteScript = '/home/respaldo/.local/bin/verificar_respaldo.sh'
    $remoteTemp = "$remoteScript.new"
    $scpResult = & $scp @options $VerifierPath ('{0}@{1}:{2}' -f $sshUser, $sshHost, $remoteTemp) 2>&1
    if ($LASTEXITCODE -ne 0) { throw "No se pudo copiar el verificador a la VM. $(($scpResult | Select-Object -Last 3) -join ' ')" }
    $deployCommand = "chmod 750 '$remoteTemp' && mv -f '$remoteTemp' '$remoteScript' && bash -n '$remoteScript'"
    $deployResult = & $ssh @options "$sshUser@$sshHost" $deployCommand 2>&1
    if ($LASTEXITCODE -ne 0) { throw "No se pudo instalar el verificador en la VM. $(($deployResult | Select-Object -Last 3) -join ' ')" }
    Write-Log '[OK] Verificador remoto SHA-256 desplegado y validado.'

    $actionPath = Join-Path $PSHOME 'powershell.exe'
    $pipelinePath = Join-Path $PSScriptRoot 'ejecutar_ciclo.ps1'
    $action = New-ScheduledTaskAction -Execute $actionPath -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$pipelinePath`""
    $trigger = New-ScheduledTaskTrigger -Daily -At '03:00'
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 15)
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Log "[OK] Tarea $TaskName registrada diaria a las 03:00 como SYSTEM, con 3 reintentos."
    $testStarted = Get-Date
    Start-ScheduledTask -TaskName $TaskName
    $deadline = (Get-Date).AddMinutes(10)
    do {
        Start-Sleep -Seconds 5
        $task = Get-ScheduledTask -TaskName $TaskName
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
    } while ((Get-Date) -lt $deadline -and ($task.State -ne 'Ready' -or $taskInfo.LastRunTime -lt $testStarted))
    if ($task.State -ne 'Ready' -or $taskInfo.LastRunTime -lt $testStarted) {
        throw 'La prueba bajo SYSTEM no termino en 10 minutos; revisa el Programador de tareas y C:\mimascota\logs.'
    }
    if ($taskInfo.LastTaskResult -ne 0) { throw "La prueba bajo SYSTEM fallo con codigo $($taskInfo.LastTaskResult); se conservaron las tareas anteriores." }
    Write-Log '[OK] Ejecucion de prueba bajo SYSTEM completa.'
    foreach ($legacyName in @('MiMascota-Monitor', 'MiMascota-RespaldoDiario')) {
        if (Get-ScheduledTask -TaskName $legacyName -ErrorAction SilentlyContinue) {
            Disable-ScheduledTask -TaskName $legacyName | Out-Null
            Write-Log "Tarea anterior deshabilitada despues de la prueba: $legacyName."
        }
    }
    Write-Output "Tarea $TaskName registrada y probada; el ciclo se repetira a las 03:00."
} catch {
    Write-Log "[ERROR] $($_.Exception.Message)"
    Write-Error $_
    exit 1
}
