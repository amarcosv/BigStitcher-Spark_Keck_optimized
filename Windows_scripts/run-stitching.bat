@echo off
powershell.exe -ExecutionPolicy Bypass -File "%~dp0run-stitching.ps1" %*
pause
