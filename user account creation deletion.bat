<# :
@echo off
setlocal
title Wazuh-SOC-Master-V5

:: 1. ADMINISTRATOR PRIVILEGE CHECK
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] ERROR: Please run as Administrator.
    pause
    exit /b 1
)

:: 2. RUN THE EMBEDDED POWERSHELL
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Get-Content '%~f0' -Raw)"
echo.
echo [COMPLETE] Deployment and Configuration Complete.
pause
exit /b
#>

# --- POWERSHELL PORTION ---

# CONFIGURATION
$managerIp = "4.150.203.68" 
$wazuhPath = "C:\Program Files (x86)\ossec-agent\ossec.conf"
$workDir = "C:\Windows\Temp\Sysmon_Setup"
$sysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
$configUrl = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"

Write-Host "[*] Starting Wazuh, Sysmon & Security Audit Integration..." -ForegroundColor Cyan

# 1. DOWNLOAD & INSTALL SYSMON
if (!(Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir -Force | Out-Null }
Set-Location $workDir
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "[*] Downloading Sysmon binaries..." -ForegroundColor Gray
Invoke-WebRequest -Uri $sysmonUrl -OutFile "Sysmon.zip" -ErrorAction SilentlyContinue
Expand-Archive -Path "Sysmon.zip" -DestinationPath "." -Force
Invoke-WebRequest -Uri $configUrl -OutFile "sysmonconfig.xml" -ErrorAction SilentlyContinue

if (!(Get-Service Sysmon64 -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Installing Sysmon64..." -ForegroundColor Green
    ./Sysmon64.exe -i sysmonconfig.xml -accepteula | Out-Null
} else {
    Write-Host "[*] Updating Sysmon Config..." -ForegroundColor Yellow
    ./Sysmon64.exe -c sysmonconfig.xml -accepteula | Out-Null
}

# 2. DEFINE XML BLOCKS FOR INJECTION
$sysmonBlock = "`r`n  <localfile>`r`n    <location>Microsoft-Windows-Sysmon/Operational</location>`r`n    <log_format>eventchannel</log_format>`r`n  </localfile>"

$securityBlock = "`r`n  <localfile>`r`n    <location>Security</location>`r`n    <log_format>eventchannel</log_format>`r`n    <query>Event/System[EventID=4720 or EventID=4726]</query>`r`n  </localfile>"

# 3. UPDATE OSSEC.CONF SAFELY
if (Test-Path $wazuhPath) {
    Copy-Item $wazuhPath "$wazuhPath.bak" -Force
    $conf = Get-Content $wazuhPath -Raw

    # REBUILD LOGIC: If file is empty, create fresh with both blocks
    if ([string]::IsNullOrWhiteSpace($conf) -or ($conf -notlike "*<ossec_config>*")) {
        Write-Host "[!] ossec.conf was empty. Rebuilding with SOC Template..." -ForegroundColor Red
        $conf = @"
<ossec_config>
  <client>
    <server>
      <address>$managerIp</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
  </client>
  $securityBlock
  $sysmonBlock
</ossec_config>
"@
        Set-Content -Path $wazuhPath -Value $conf -Encoding UTF8 -Force
    } else {
        # INJECTION LOGIC: Add blocks if missing
        $updated = $false
        
        # Inject Security Block
        if ($conf -notlike "*EventID=4720*") {
            Write-Host "[*] Injecting Security Audit block (4720/4726)..." -ForegroundColor Cyan
            $conf = $conf -replace '(?i)</ossec_config>', "$securityBlock`r`n</ossec_config>"
            $updated = $true
        }

        # Inject Sysmon Block
        if ($conf -notlike "*Microsoft-Windows-Sysmon/Operational*") {
            Write-Host "[*] Injecting Sysmon block..." -ForegroundColor Cyan
            $conf = $conf -replace '(?i)</ossec_config>', "$sysmonBlock`r`n</ossec_config>"
            $updated = $true
        }

        if ($updated) {
            Set-Content -Path $wazuhPath -Value $conf -Encoding UTF8 -Force
            Write-Host "[SUCCESS] ossec.conf updated and verified." -ForegroundColor Green
        } else {
            Write-Host "[INFO] All blocks already exist in ossec.conf." -ForegroundColor Yellow
        }
    }
}

# 4. RESTART AGENT
Write-Host "[*] Restarting Wazuh Agent..." -ForegroundColor Cyan
Restart-Service Wazuh -Force -ErrorAction SilentlyContinue
