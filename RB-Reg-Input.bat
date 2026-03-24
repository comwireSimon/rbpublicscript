@echo off
powershell.exe -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0RB-Reg-Input.ps1\"' -Verb RunAs"
:check
reg query "HKEY_LOCAL_MACHINE\Software\RBConfig" /v RBOrderNumber 2>nul | findstr "RBOrderNumber" >nul
if errorlevel 1 goto check
reg query "HKEY_LOCAL_MACHINE\Software\RBConfig" /v WindowsLicenseKey 2>nul | findstr "WindowsLicenseKey" >nul
if errorlevel 1 goto check
del "%~f0"
exit /b