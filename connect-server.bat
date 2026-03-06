@echo off
powershell.exe -ExecutionPolicy Bypass -File "%~dp0connect-server.ps1" %*
pause
