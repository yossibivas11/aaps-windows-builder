@echo off
REM ==========================================================================
REM  AAPS Builder - one file, self-unpacking.
REM  Double-click it. It unpacks itself into a folder called AAPS next to
REM  this file, and starts. Nothing is installed into Windows.
REM  (This is a plain text batch file, not a program - you can open it in
REM   Notepad and read this.)
REM ==========================================================================
title AAPS Builder
chcp 65001 >nul 2>&1
setlocal

set "HERE=%~dp0"
set "DEST=%HERE%AAPS"

echo.
echo  ============================================================
echo    AAPS Builder
echo  ============================================================
echo.

REM If it was already unpacked, just show it again.
if exist "%DEST%\Build-AAPS.bat" (
  echo   Already unpacked.
  goto :show
)

REM Refuse to unpack into a temporary folder - that happens when someone
REM runs this from inside a ZIP preview window, and nothing would survive.
echo %HERE% | findstr /i /c:"\AppData\Local\Temp\" >nul && goto :inzip
echo %HERE% | findstr /i /c:"\Temp\Rar$" >nul && goto :inzip
echo %HERE% | findstr /i /c:"\Temp\7z" >nul && goto :inzip

echo   Unpacking (a few seconds)...
echo.

set "HELPER=%TEMP%\aaps-unpack.ps1"
if exist "%HELPER%" del "%HELPER%"
echo $ErrorActionPreference = 'Stop'>>"%HELPER%"
echo $src = $env:AAPS_SFX_FILE>>"%HELPER%"
echo $dst = $env:AAPS_SFX_DEST>>"%HELPER%"
echo $all = Get-Content -LiteralPath $src>>"%HELPER%"
echo $start = 0>>"%HELPER%"
echo for ($k = 0; $k -lt $all.Count; $k++) { if ($all[$k].StartsWith('::PAYLOAD::')) { $start = $k + 1; break } }>>"%HELPER%"
echo if ($start -eq 0) { throw 'payload marker not found' }>>"%HELPER%"
echo $b64 = ($all[$start..($all.Count - 1)]) -join ''>>"%HELPER%"
echo $zip = Join-Path $env:TEMP 'aaps-payload.zip'>>"%HELPER%"
echo [IO.File]::WriteAllBytes($zip, [Convert]::FromBase64String($b64))>>"%HELPER%"
echo if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force ^| Out-Null }>>"%HELPER%"
echo Add-Type -AssemblyName System.IO.Compression.FileSystem>>"%HELPER%"
echo $arch = [IO.Compression.ZipFile]::OpenRead($zip)>>"%HELPER%"
echo foreach ($e in $arch.Entries) {>>"%HELPER%"
echo   $target = Join-Path $dst $e.FullName>>"%HELPER%"
echo   $parent = Split-Path $target -Parent>>"%HELPER%"
echo   if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force ^| Out-Null }>>"%HELPER%"
echo   if ($e.Name) { [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true) }>>"%HELPER%"
echo }>>"%HELPER%"
echo $arch.Dispose()>>"%HELPER%"
echo Remove-Item $zip -Force -ErrorAction SilentlyContinue>>"%HELPER%"

set "AAPS_SFX_FILE=%~f0"
set "AAPS_SFX_DEST=%DEST%"

where pwsh.exe >nul 2>&1
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%HELPER%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%HELPER%"
)
set "RC=%errorlevel%"
del "%HELPER%" >nul 2>&1

if not "%RC%"=="0" goto :fail
if not exist "%DEST%\Build-AAPS.bat" goto :fail

echo   Unpacked into:  %DEST%
echo.

:show
REM Open the Hebrew instructions and the folder. Deliberately do NOT start the
REM build - the user must read the instructions first, and have the chance to
REM copy an existing signing key into the folder before anything runs.
REM (The guide has a Hebrew file name, so it is opened via a wildcard rather
REM  than typed out - this batch file is plain ASCII.)
for %%f in ("%DEST%\*.html") do start "" "%%f"
start "" "%DEST%"

echo  ============================================================
echo.
echo    Everything is ready. NOTHING has been built yet.
echo.
echo    Two windows have just opened:
echo      1. The instructions, in Hebrew - please read them.
echo      2. The AAPS folder.
echo.
echo    When you have read the instructions, go to the AAPS
echo    folder and double-click:   Build-AAPS.bat
echo.
echo    If you already have a signing key (a .jks file) from a
echo    previous build, copy it into the AAPS folder FIRST.
echo.
echo  ============================================================
echo.
pause
exit /b 0

:inzip
echo  ============================================================
echo   You are running this from inside a ZIP file.
echo.
echo   Save this file to your Desktop or Documents first,
echo   then double-click it there.
echo  ============================================================
echo.
pause
exit /b 1

:fail
echo.
echo  ============================================================
echo   Could not unpack. This usually means antivirus blocked it.
echo   Save the file somewhere else (Documents) and try again.
echo  ============================================================
echo.
pause
exit /b 1

::PAYLOAD::
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
QVBTLnBzMVBLBQYAAAAABgAGAKkBAACkigAAAAA=
