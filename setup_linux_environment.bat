@echo off
powershell.exe -ExecutionPolicy Bypass -File "%~dp0setup_linux_environment.ps1" %*
pause
