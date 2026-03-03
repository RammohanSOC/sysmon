@echo off
setlocal EnableDelayedExpansion
title Wazuh SOC - Sysmon PowerShell Config Fix

:: 1. ADMINISTRATOR PRIVILEGE CHECK
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] ERROR: Please run as Administrator.
    pause
    exit /b 1
)

:: 2. DEFINE PATHS
set "SYSMON_PATH=C:\Windows\Sysmon64.exe"
set "CONFIG_FILE=%TEMP%\suspicious_powershell.xml"

:: 3. GENERATE THE CLEAN XML USING POWERSHELL
:: This method ensures no Batch artifacts like '@echo off' enter the XML
echo [*] Generating clean Sysmon XML configuration...
powershell -Command "$xml = '<Sysmon schemaversion=\"4.30\"><EventFiltering><RuleGroup name=\"Suspicious PowerShell\" groupRelation=\"or\"><ProcessCreate onmatch=\"include\"><Image condition=\"contains\">powershell.exe</Image><Image condition=\"contains\">pwsh.exe</Image><Image condition=\"contains\">powershell_ise.exe</Image></ProcessCreate></RuleGroup></EventFiltering></Sysmon>'; Set-Content -Path '%CONFIG_FILE%' -Value $xml -Encoding UTF8"

:: 4. APPLY THE CONFIGURATION
if exist "%SYSMON_PATH%" (
    echo [*] Applying configuration to Sysmon service...
    "%SYSMON_PATH%" -c "%CONFIG_FILE%" -accepteula
    if %errorLevel% equ 0 (
        echo [SUCCESS] Sysmon configuration updated successfully.
    ) else (
        echo [!] ERROR: Failed to update Sysmon. Check the XML syntax.
    )
) else (
    echo [!] ERROR: Sysmon64.exe not found at %SYSMON_PATH%.
    pause
    exit /b 1
)

:: 5. VERIFICATION
echo.
echo [*] Verifying active configuration...
"%SYSMON_PATH%" -c | findstr /i "Suspicious PowerShell"
if %errorLevel% equ 0 (
    echo [REPORT] The "Suspicious PowerShell" rule group is now LIVE.
) else (
    echo [!] WARNING: Rule group not found in active config.
)

:: 6. CLEANUP
if exist "%CONFIG_FILE%" del "%CONFIG_FILE%"
echo ============================================================
echo [FINISHED] Your agent is now monitoring deep PS command lines.
echo ============================================================
pause
