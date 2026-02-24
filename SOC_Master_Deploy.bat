<# :
@echo off
setlocal
title Wazuh SOC Master Deployer - V2 (Fixed)

:: 1. ADMIN CHECK
net session >nul 2>&1
if %errorLevel% neq 0 (echo [!] ERROR: Run as Administrator. & pause & exit /b 1)

:: 2. CONFIGURATION
set "WAZUH_MANAGER=4.150.203.68"
set "WORK_DIR=C:\Windows\Temp\SOC_Setup"

if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"
cd /d "%WORK_DIR%"

:: 3. EXECUTE FIXED POWERSHELL
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Get-Content '%~f0' -Raw)"

echo.
echo ============================================================
echo [FINISHED] If SUCCESS appears above, use cases are active.
echo ============================================================
pause
exit /b
#>

# --- POWERSHELL PORTION ---
$managerIp = "4.150.203.68"
$wazuhPath = "C:\Program Files (x86)\ossec-agent"
$ossecConf = "$wazuhPath\ossec.conf"
# ENSURE THIS URL IS CORRECT ON YOUR GITHUB
$sysmonXmlUrl = "https://raw.githubusercontent.com/RammohanSOC/sysmon/refs/heads/main/master_soc_config.xml"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. SYSMON RECOVERY
Write-Host "[1/4] Recovering Sysmon..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $sysmonXmlUrl -OutFile "master_soc.xml" -UseBasicParsing -ErrorAction Stop
    if (Test-Path "C:\Windows\Sysmon64.exe") {
        & "C:\Windows\Sysmon64.exe" -c master_soc.xml
        Write-Host "[SUCCESS] Sysmon reconfigured." -ForegroundColor Green
    } else {
        Write-Host "[!] Sysmon64.exe not found in C:\Windows. Please install it first." -ForegroundColor Red
    }
} catch {
    Write-Host "[ERROR] 404: The XML file does not exist at the URL provided." -ForegroundColor Red
}

# 2. AGENT REGISTRATION FIX
Write-Host "[2/4] Registering Wazuh Agent..." -ForegroundColor Cyan
if (Test-Path "$wazuhPath\agent-auth.exe") {
    # We change location to the agent folder so it can find ossec.conf
    Set-Location $wazuhPath
    ./agent-auth.exe -m $managerIp
    Set-Location $WORK_DIR
}

# 3. OSSEC.CONF HARDENING
Write-Host "[3/4] Hardening ossec.conf..." -ForegroundColor Cyan
if (Test-Path $ossecConf) {
    $conf = Get-Content $ossecConf -Raw
    $socBlock = @"
  <!-- SOC MASTER SUITE -->
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
  </syscheck>
  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
  </sca>
"@
    if ($conf -notlike "*SOC MASTER SUITE*") {
        $updatedConf = $conf -replace '(?i)</ossec_config>', "$socBlock`r`n</ossec_config>"
        Set-Content -Path $ossecConf -Value $updatedConf -Encoding UTF8 -Force
        Write-Host "[SUCCESS] Configuration Hardened." -ForegroundColor Green
    } else {
        Write-Host "[INFO] Hardening already applied." -ForegroundColor Yellow
    }
}

# 4. FINALIZING
Write-Host "[4/4] Restarting Services..." -ForegroundColor Cyan
Restart-Service Wazuh -Force -ErrorAction SilentlyContinue
Write-Host "[COMPLETE] Deployment sequence finished." -ForegroundColor White
