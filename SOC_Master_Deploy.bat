<# :
@echo off
setlocal EnableDelayedExpansion
title Wazuh SOC Master Deployer - Full Suite

:: 1. ADMINISTRATOR PRIVILEGE CHECK
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] ERROR: Please run as Administrator.
    pause
    exit /b 1
)

:: 2. CONFIGURATION
set "WAZUH_MANAGER=4.150.203.68"
set "SYSMON_XML_URL=https://raw.githubusercontent.com/RammohanSOC/sysmon/refs/heads/main/master-sysmonconfig.xml"
set "WORK_DIR=C:\Windows\Temp\SOC_Setup"

echo [*] Starting Comprehensive SOC Deployment...
if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"
cd /d "%WORK_DIR%"

:: 3. EXECUTE POWERSHELL PORTION
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Get-Content '%~f0' -Raw)"

echo.
echo ============================================================
echo [FINISHED] Use cases active: CDB, BruteForce, PowerShell, 
echo            FIM, Ransomware, USB, C2, SCA, and Port Scanning.
echo ============================================================
pause
exit /b
#>

# --- POWERSHELL PORTION ---
$managerIp = "4.150.203.68"
$wazuhPath = "C:\Program Files (x86)\ossec-agent"
$ossecConf = "$wazuhPath\ossec.conf"
$sysmonXmlUrl = "https://raw.githubusercontent.com/RammohanSOC/sysmon/refs/heads/main/master_soc_config.xml"

Write-Host "[1/4] Configuring Sysmon..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $sysmonXmlUrl -OutFile "master_soc.xml" -UseBasicParsing

if (!(Get-Service Sysmon64 -ErrorAction SilentlyContinue)) {
    # Download binaries if missing
    Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "Sysmon.zip"
    Expand-Archive -Path "Sysmon.zip" -DestinationPath "." -Force
    & .\Sysmon64.exe -i master_soc.xml -accepteula
} else {
    & "C:\Windows\Sysmon64.exe" -c master_soc.xml
}

Write-Host "[2/4] Registering Wazuh Agent..." -ForegroundColor Cyan
if (Test-Path "$wazuhPath\agent-auth.exe") {
    & "$wazuhPath\agent-auth.exe" -m $managerIp
}

Write-Host "[3/4] Hardening ossec.conf for all Use Cases..." -ForegroundColor Cyan
if (Test-Path $ossecConf) {
    Copy-Item $ossecConf "$ossecConf.bak" -Force
    $conf = Get-Content $ossecConf -Raw

    # Define the Unified Collection Block
    $socBlock = @"
  <!-- SOC Master Collection Block -->
  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Microsoft-Windows-PowerShell/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <syscheck>
    <directories whodata="yes" realtime="yes">C:\Sensitive\Data</directories>
    <directories whodata="yes" realtime="yes">D:\,E:\,F:\</directories>
  </syscheck>
  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>12h</interval>
  </sca>
"@

    if ($conf -notlike "*SOC Master Collection Block*") {
        $updatedConf = $conf -replace '(?i)</ossec_config>', "$socBlock`r`n</ossec_config>"
        Set-Content -Path $ossecConf -Value $updatedConf -Encoding UTF8 -Force
        Write-Host "[SUCCESS] ossec.conf updated with SOC Suite." -ForegroundColor Green
    } else {
        Write-Host "[INFO] SOC Suite already present in ossec.conf." -ForegroundColor Yellow
    }
}

Write-Host "[4/4] Finalizing Services..." -ForegroundColor Cyan
Restart-Service Wazuh -Force
Write-Host "[COMPLETE] Endpoint is now fully monitored." -ForegroundColor Green
