@echo off
setlocal
title Force Advanced Audit - User Account Management

:: ADMIN CHECK
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Run as Administrator.
    pause
    exit /b 1
)

echo Enabling Advanced Audit Override...
reg add "HKLM\System\CurrentControlSet\Control\Lsa" ^
 /v SCENoApplyLegacyAuditPolicy ^
 /t REG_DWORD ^
 /d 1 ^
 /f >nul

echo.
echo Enabling Success and Failure auditing...
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable

echo.
echo ===== VERIFICATION =====
auditpol /get /subcategory:"User Account Management"

echo.
echo NOTE:
echo secpol.msc may still show unchecked.
echo auditpol output is the real effective policy.
echo =========================
pause
