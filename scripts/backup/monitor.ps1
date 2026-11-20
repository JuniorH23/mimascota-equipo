$ErrorActionPreference = 'Stop'
$Root = 'C:\mimascota'
$LogDir = Join-Path $Root 'logs'
$LogFile = Join-Path $LogDir 'monitor.log'
$BackupDir = Join-Path $Root 'respaldos'
$CpuThreshold = 85
$FreeMemoryThreshold = 15
$FreeDiskThreshold = 10
$MaxBackupAgeHours = 26
$MySqlServiceName = 'MySQL80'

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    Write-Output $line
}

try {
    $cpuSample = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
    if (-not $cpuSample) { throw 'No se pudo consultar el uso de CPU.' }
    $cpu = [math]::Round($cpuSample.PercentProcessorTime, 1)
    $os = Get-WmiObject -Class Win32_OperatingSystem
    if (-not $os) { throw 'No se pudo consultar la memoria del sistema.' }
    $freeMemoryPercent = [math]::Round(100 * $os.FreePhysicalMemory / $os.TotalVisibleMemorySize, 1)
    $diskName = ($env:SystemDrive).TrimEnd(':')
    $disk = Get-PSDrive -Name $diskName
    if (-not $disk -or ($disk.Used + $disk.Free) -le 0) { throw "No se pudo consultar el disco $env:SystemDrive." }
    $freeDiskPercent = [math]::Round(100 * $disk.Free / ($disk.Used + $disk.Free), 1)

    $service = Get-Service -Name $MySqlServiceName -ErrorAction SilentlyContinue
    $serviceState = if ($service) { $service.Status.ToString() } else { 'No encontrado' }
    $mysqlProcesses = @(Get-CimInstance Win32_Process -Filter "Name='mysqld.exe'")
    $processSummary = if ($mysqlProcesses.Count) {
        ($mysqlProcesses | ForEach-Object {
            '{0}(PID={1},PPID={2},RAM={3}MB)' -f $_.Name, $_.ProcessId, $_.ParentProcessId, [math]::Round($_.WorkingSetSize / 1MB, 1)
        }) -join '; '
    } else {
        'ninguno'
    }

    $latestBackup = Get-ChildItem -LiteralPath $BackupDir -Filter '*.zip' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $backupAgeHours = if ($latestBackup) { [math]::Round(((Get-Date) - $latestBackup.LastWriteTime).TotalHours, 1) } else { $null }
    $backupAgeText = if ($null -eq $backupAgeHours) { 'sin respaldo local' } else { "$backupAgeHours horas" }

    Write-Log "CPU=$cpu%; RAM libre=$freeMemoryPercent%; disco $env:SystemDrive libre=$freeDiskPercent%; servicio $MySqlServiceName=$serviceState; mysqld=$processSummary; ultimo respaldo=$backupAgeText."

    if ($cpu -ge $CpuThreshold) { Write-Log "[ALERTA] CPU supera el umbral de $CpuThreshold%." }
    if ($freeMemoryPercent -lt $FreeMemoryThreshold) { Write-Log "[ALERTA] RAM libre por debajo de $FreeMemoryThreshold%." }
    if ($freeDiskPercent -lt $FreeDiskThreshold) { Write-Log "[ALERTA] Disco libre por debajo de $FreeDiskThreshold%." }
    if (-not $service -or $service.Status -ne 'Running') { Write-Log "[ALERTA] Servicio $MySqlServiceName no esta activo." }
    if (-not $mysqlProcesses.Count) { Write-Log '[ALERTA] No se encontro ningun proceso mysqld.exe.' }
    if ($null -eq $backupAgeHours -or $backupAgeHours -gt $MaxBackupAgeHours) {
        Write-Log "[ALERTA] El respaldo local mas reciente supera $MaxBackupAgeHours horas o no existe."
    }
} catch {
    Write-Log "[ERROR] No se pudieron completar las metricas: $($_.Exception.Message)"
    exit 1
}
