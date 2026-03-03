<# :
@echo off
setlocal
title Wazuh-SOC-Master-Deployer

:: ADMIN CHECK
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please run as Administrator.
    pause
    exit /b 1
)

:: Launch embedded PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Get-Content '%~f0' -Raw)"
echo.
echo [FINISHED] Deployment Complete.
pause
exit /b
#>

# =========================
# POWERSHELL SECTION
# =========================

$ErrorActionPreference = "Stop"

$managerIp = "4.150.203.68"
$wazuhPath = "C:\Program Files (x86)\ossec-agent\ossec.conf"
$workDir = "C:\Windows\Temp\Sysmon_Setup"
$sysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
$configUrl = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"

Write-Host "[*] Starting Deployment..." -ForegroundColor Cyan

# =========================
# 1. INSTALL / UPDATE SYSMON
# =========================

if (!(Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
}

Set-Location $workDir
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "[*] Downloading Sysmon..." -ForegroundColor Gray
Invoke-WebRequest $sysmonUrl -OutFile "Sysmon.zip"
Expand-Archive "Sysmon.zip" -Force
Invoke-WebRequest $configUrl -OutFile "sysmonconfig.xml"

if (!(Get-Service Sysmon64 -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Installing Sysmon..." -ForegroundColor Green
    .\Sysmon64.exe -i sysmonconfig.xml -accepteula | Out-Null
} else {
    Write-Host "[*] Updating Sysmon Config..." -ForegroundColor Yellow
    .\Sysmon64.exe -c sysmonconfig.xml -accepteula | Out-Null
}

# =========================
# 2. UPDATE WAZUH CONFIG
# =========================

if (!(Test-Path $wazuhPath)) {
    Write-Host "[ERROR] Wazuh ossec.conf not found." -ForegroundColor Red
    exit 1
}

# Backup
Copy-Item $wazuhPath "$wazuhPath.bak" -Force
Write-Host "[*] Backup created." -ForegroundColor Gray

$conf = Get-Content $wazuhPath -Raw

# Rebuild if corrupted
if ([string]::IsNullOrWhiteSpace($conf) -or ($conf -notmatch "<ossec_config>")) {

    Write-Host "[!] ossec.conf invalid. Rebuilding..." -ForegroundColor Red

$conf = @"
<ossec_config>
  <client>
    <server>
      <address>$managerIp</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
  </client>
</ossec_config>
"@
}

# Security Event Query Block
$securityBlock = @"

  <localfile>
    <location>Security</location>
    <log_format>eventchannel</log_format>
    <query>Event/System[EventID=4720 or EventID=4726]</query>
  </localfile>

"@

# Prevent duplicate injection
if ($conf -notmatch "EventID=4720") {

    Write-Host "[*] Injecting Security Event Monitoring block..." -ForegroundColor Cyan

    $newConf = $conf -replace "(?i)</ossec_config>", "$securityBlock</ossec_config>"

    if ($newConf -match "EventID=4720") {
        Set-Content $wazuhPath $newConf -Encoding UTF8 -Force
        Write-Host "[SUCCESS] ossec.conf updated." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Injection failed. No changes made." -ForegroundColor Red
        exit 1
    }

} else {
    Write-Host "[INFO] Security event block already exists." -ForegroundColor Yellow
}

# =========================
# 3. RESTART WAZUH
# =========================

Write-Host "[*] Restarting Wazuh Agent..." -ForegroundColor Cyan
Restart-Service Wazuh -Force

Write-Host "[SUCCESS] Deployment Complete." -ForegroundColor Green
