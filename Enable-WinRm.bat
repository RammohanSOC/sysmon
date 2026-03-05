@echo off

echo =========================================
echo Configuring Windows for Ansible WinRM
echo =========================================
echo Enabling WinRM service...
winrm quickconfig -q

echo Enabling PowerShell Remoting...
powershell -Command "Enable-PSRemoting -Force"

echo Enabling Basic Authentication...
winrm set winrm/config/service/auth '@{Basic="true"}'

echo Allowing unencrypted WinRM traffic...
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

echo Opening Firewall Port 5985...
netsh advfirewall firewall add rule name="WinRM-5985" dir=in action=allow protocol=TCP localport=5985

echo Creating Ansible user...
net user ansible P@ssw0rd123 /add

echo Adding user to Administrators group...
net localgroup administrators ansible /add

echo =========================================
echo WinRM Configuration Completed
echo =========================================

pause
