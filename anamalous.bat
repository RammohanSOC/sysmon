# 1. Variables
$githubUrl = "https://raw.githubusercontent.com/RammohanSOC/sysmon/refs/heads/main/anomalousfiledeletiondetection.xml"
$tempXml = "C:\Windows\Temp\sysmon_soc.xml"
$sysmonBin = "C:\Windows\Sysmon64.exe"

Write-Host "[*] Downloading SOC-Approved Sysmon Config..." -ForegroundColor Cyan

# 2. Download from GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    Invoke-WebRequest -Uri $githubUrl -OutFile $tempXml -ErrorAction Stop
} catch {
    Write-Host "[!] ERROR: Could not reach GitHub." -ForegroundColor Red; exit
}

# 3. Update Sysmon Configuration
if (Test-Path $sysmonBin) {
    Write-Host "[*] Applying Mass Deletion Detection rules..." -ForegroundColor Yellow
    & $sysmonBin -c $tempXml
} else {
    Write-Host "[!] ERROR: Sysmon is not installed." -ForegroundColor Red
}

# 4. Restart Wazuh Agent to ensure synchronization
Restart-Service Wazuh -Force
Write-Host "[SUCCESS] Agent is now monitoring for anomalous deletions." -ForegroundColor Green
