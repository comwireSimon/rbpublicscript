@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0RB-Reg-Input.ps1"
:check
reg query "HKCU\Software\RBConfig" /v RBOrderNumber 2>nul | findstr /C:"RBOrderNumber" >nul
if errorlevel 1 goto check
reg query "HKCU\Software\RBConfig" /v WindowsLicenseKey 2>nul | findstr /C:"WindowsLicenseKey" >nul
if errorlevel 1 goto check
del "%~f0"
exit /b