@echo off
setlocal
echo MiR - Activacion LOCAL del servicio receptor de Windows
echo No ejecutar desde la unica conexion remota.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiR_Activar_Receptor.ps1"
echo.
pause
