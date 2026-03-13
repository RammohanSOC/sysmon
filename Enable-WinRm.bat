@echo off
echo =====================================
echo Configuring WinRM for Ansible Access
echo =====================================

powershell -ExecutionPolicy Bypass -Command ^
"Enable-PSRemoting -Force; ^
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true; ^
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true; ^
Enable-NetFirewallRule -Name 'WINRM-HTTP-In-TCP'"

echo Creating Ansible user...
net user ansible P@ssw0rd123 /add

echo Adding user to Administrators group...
net localgroup administrators ansible /add

echo Opening WinRM port 5985 in firewall...
netsh advfirewall firewall add rule name="WinRM-5985" dir=in action=allow protocol=TCP localport=5985

echo =====================================
echo WinRM Configuration Completed
echo =====================================
pause
