@echo off
REM ============================================================
REM  Quick check that this PC can build AAPS.
REM  Takes about a minute. Builds nothing, downloads nothing big.
REM ============================================================
title AAPS Builder - self test
chcp 65001 >nul 2>&1
setlocal
set "PS1=%~dp0AAPS-Builder-Files\Build-AAPS.ps1"
if not exist "%PS1%" (
  echo  ERROR: AAPS-Builder-Files\Build-AAPS.ps1 not found next to this file.
  pause
  exit /b 1
)
where pwsh.exe >nul 2>&1
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -SelfTest
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -SelfTest
)
echo.
pause
endlocal
