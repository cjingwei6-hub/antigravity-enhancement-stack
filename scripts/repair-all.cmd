@echo off
chcp 65001 >nul
title Antigravity Enhancement Repair

rem Prefer PowerShell 7 if present, fall back to Windows PowerShell 5.1.
rem Both work: the .ps1 carries a UTF-8 BOM so 5.1 reads its Chinese text correctly.

set "PS=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS=pwsh.exe"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair-all.ps1"
