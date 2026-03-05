@echo off

echo =========================================
echo Configuring Windows for Ansible WinRM
echo =========================================

echo Enabling WinRM service...
winrm quickconfig -quiet

echo Enabling PowerShell Remoting...
powershell -ExecutionPolicy Bypass -Command "Enable-PSRemoting -Force"

echo Enabling Basic Authentication...
powershell -ExecutionPolicy Bypass -Command "Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true"

echo Allowing unencrypted WinRM traffic...
powershell -ExecutionPolicy Bypass -Command "Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true"

echo Opening Firewall Port 5985...
netsh advfirewall firewall add rule name="WinRM-5985" dir=in action=allow protocol=TCP localport=5985

echo Creating Ansible user...
net user ansible P@ssw0rd123 /add

echo Adding user to Administrators group...
net localgroup administrators ansible /add

echo Restarting WinRM service...
powershell -ExecutionPolicy Bypass -Command "Restart-Service WinRM"

echo =========================================
echo WinRM Configuration Completed
echo =========================================
