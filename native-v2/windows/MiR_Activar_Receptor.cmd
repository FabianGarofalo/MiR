@echo off
setlocal
echo MiR - Activacion LOCAL del servicio receptor de Windows
echo Se pedira permiso de administrador. NO ejecutar desde la unica conexion remota.
set "MIR_RECEPTOR_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$f=Join-Path $env:MIR_RECEPTOR_DIR 'MiR_Activar_Receptor.ps1'; Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$f+'"'))"
echo.
pause
