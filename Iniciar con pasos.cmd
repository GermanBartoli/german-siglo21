@echo off
setlocal
title German Siglo21 - Preparacion para rendir
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0German-Siglo21.ps1"
set "resultado=%errorlevel%"
echo.
pause
exit /b %resultado%
