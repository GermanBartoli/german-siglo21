@echo off
setlocal
title German Siglo21 - Preparacion para rendir
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0German-Siglo21.ps1" -Directo
exit /b %errorlevel%
