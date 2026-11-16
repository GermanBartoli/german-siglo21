@echo off
setlocal
title German Siglo21 - Simulacion segura
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0German-Siglo21.ps1" -Simular
set "resultado=%errorlevel%"
echo.
pause
exit /b %resultado%
