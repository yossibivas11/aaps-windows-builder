@echo off
REM ============================================================
REM  AAPS (AndroidAPS) one-click builder
REM  Just double-click this file. Everything else is automatic.
REM  Everything this needs lives in the AAPS-Builder-Files folder.
REM ============================================================
title AAPS Builder

REM Switch the console to UTF-8.
chcp 65001 >nul 2>&1

setlocal
set "HERE=%~dp0"

REM --- Guard: people often double-click straight inside a ZIP preview window.
REM Windows unpacks to a read-only temp folder, the build then fails in
REM confusing ways. Catch it and say so plainly.
echo %HERE% | findstr /i /c:"\AppData\Local\Temp\" >nul && goto :inzip
echo %HERE% | findstr /i /c:"\Temp\Rar$"   >nul && goto :inzip
echo %HERE% | findstr /i /c:"\Temp\7z"     >nul && goto :inzip
goto :notinzip

:inzip
echo.
echo  ============================================================
echo   You are running this from INSIDE the ZIP file.
echo.
echo   That cannot work - Windows only unpacked a temporary copy.
echo.
echo   Close this window. Then RIGHT-CLICK the ZIP file,
echo   choose "Extract All...", and run Build-AAPS.bat from the
echo   folder that appears.
echo  ============================================================
echo.
pause
exit /b 1

:notinzip
set "PS1=%HERE%AAPS-Builder-Files\Build-AAPS.ps1"

if not exist "%PS1%" (
  echo.
  echo  ============================================================
  echo   ERROR: the AAPS-Builder-Files folder is missing.
  echo.
  echo   Build-AAPS.bat must sit NEXT TO a folder called
  echo   AAPS-Builder-Files, like this:
  echo.
  echo      Build-AAPS.bat
  echo      AAPS-Builder-Files\
  echo.
  echo   If you unzipped only one file, unzip the whole ZIP again.
  echo  ============================================================
  echo.
  pause
  exit /b 1
)

REM Prefer PowerShell 7 if present, otherwise Windows PowerShell 5.1
where pwsh.exe >nul 2>&1
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
)

set "RC=%errorlevel%"
echo.
if "%RC%"=="2" (
  echo  You did not accept the disclaimer. Nothing was built.
) else if not "%RC%"=="0" (
  echo  The build script exited with code %RC%.
  echo  Open the AAPS-Builder-Files folder and send build-log.txt
  echo  to whoever is helping you.
)
echo  You can close this window now.
pause
endlocal
exit /b %RC%
