@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0MiR_Corregir_Receptor.ps1" -Modo Corregir
set "code=%ERRORLEVEL%"
echo.
echo MIR: resultado del diagnostico / reparacion: %code%
echo Presiona una tecla para cerrar.
pause >nul
exit /b %code%
