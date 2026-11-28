@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiR_Verificar_PreLogin.ps1"
echo.
pause
