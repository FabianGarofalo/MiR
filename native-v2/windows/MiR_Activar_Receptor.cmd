@echo off
setlocal
echo MiR - Activacion LOCAL del servicio receptor Windows
echo El portable no instala servicios; este asistente requiere MiR instalado y permiso de administrador.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiR_Activar_Receptor.ps1"
echo.
pause
