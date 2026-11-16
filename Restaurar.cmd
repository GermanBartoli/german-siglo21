@echo off
setlocal
title German Siglo21 - Restaurar
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0German-Siglo21.ps1" -Restaurar
set "resultado=%errorlevel%"
echo.
pause
exit /b %resultado%
