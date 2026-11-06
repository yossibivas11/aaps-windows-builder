<#
================================================================================
 AAPS (AndroidAPS) one-click builder for Windows
================================================================================
 What it does, with (almost) no input from you:
   1. Checks your PC has enough disk space.
   2. Downloads a private copy of Git into "aaps-tools".
   3. Downloads the latest AAPS source code (master branch) from GitHub.
   4. READS THE SOURCE to find out exactly which Java version, which Android
      SDK platform and which build-tools that particular AAPS version needs,
      then downloads/updates precisely those. Nothing is hard-coded, so when
      upstream bumps a requirement this script follows automatically.
   5. Finds your signing keystore in this folder, or creates one for you.
   6. Builds and signs the APK(s) you asked for.
   7. Drops the finished APK(s) next to this script and opens the folder.

 Nothing is installed system-wide. No Administrator rights are needed.
 Android Studio is NOT used and NOT required - this is the official CLI build.

 Re-run any time for an up-to-date build. Later runs are much faster.
================================================================================
#>

#Requires -Version 5.1

param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Console encoding, kept for consistency with the Hebrew edition.
try {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $OutputEncoding           = [Text.Encoding]::UTF8
} catch { }

# ------------------------------------------------------------------- settings
$AapsRepo     = 'https://github.com/nightscout/AndroidAPS.git'
$AapsBranch   = 'master'
$KeystoreName = 'aaps-keystore.jks'
$KeyAlias     = 'aaps-key'

# Name that appears in the legal notice. Change it if you want to.
$AuthorName   = 'The script author'

# Used only if the source code cannot be read for some reason.
$FallbackJdk       = '21'
$FallbackPlatform  = 36
$FallbackBuildTool = '36.0.0'

# Folder layout, kept deliberately bare so a nervous user sees almost nothing:
#
#   <your folder>\
#       Build-AAPS.bat            <- the only thing to double-click
#       AAPS-phone-....apk        <- the finished app lands here
#       aaps-keystore.jks         <- your key. BACK IT UP.
#       keystore.properties       <- its password. BACK IT UP.
#       README.html               <- the guide
#       AAPS-Builder-Files\       <- everything else hides in here
#
# $Root    = the visible folder (APK, key, guide).
# $Support = the AAPS-Builder-Files folder, where this script lives, along
#            with the logs, the downloaded tools and the source code.
$Support   = $PSScriptRoot
$Root      = Split-Path $Support -Parent
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = $Support }   # run from a drive root
$LogFile   = Join-Path $Support 'build-log.txt'
$PropsFile = Join-Path $Root    'keystore.properties'

# ------------------------------------------------------------------- plumbing
function Say  { param($m) Write-Host $m -ForegroundColor Gray }
function Step { param($m) Write-Host "`n=== $m" -ForegroundColor Cyan }
function Ok   { param($m) Write-Host "    [OK] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Fail {
    param($m)
    Write-Host "`n--------------------------------------------------------------" -ForegroundColor Red
    Write-Host " STOPPED: $m" -ForegroundColor Red
    Write-Host " A full log was saved to: $LogFile" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------`n" -ForegroundColor Red
    try { Stop-Transcript | Out-Null } catch {}
    exit 1
}

function Get-File {
    param([string]$Url, [string]$OutFile, [string]$What)
    if (Test-Path $OutFile) {
        $sizeMb = [math]::Round((Get-Item $OutFile).Length / 1MB, 1)
        if ($sizeMb -gt 1) { Ok "$What already downloaded ($sizeMb MB)"; return }
        Remove-Item $OutFile -Force
    }
    Say "    downloading $What ..."
    $tmp = "$OutFile.part"
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
    $done = $false
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        try { Start-BitsTransfer -Source $Url -Destination $tmp -Description $What -ErrorAction Stop; $done = $true }
        catch { if (Test-Path $tmp) { Remove-Item $tmp -Force } }
    }
    if (-not $done) {
        try { Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -TimeoutSec 1800 }
        catch { throw "Could not download $What from $Url  --  $($_.Exception.Message)" }
    }
    Move-Item $tmp $OutFile -Force
    Ok "$What downloaded ($([math]::Round((Get-Item $OutFile).Length / 1MB,1)) MB)"
}

function Expand-Zip {
    param([string]$Zip, [string]$Dest)
    if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Dest)
}

function Invoke-Tool {
    param(
        [string]$Exe, [string[]]$Arguments, [string]$WorkDir = $Root,
        [hashtable]$EnvVars = @{}, $StdIn = $null, [switch]$Quiet
    )
    $old = @{}
    foreach ($k in $EnvVars.Keys) {
        $old[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $EnvVars[$k])
    }
    # CRITICAL for Windows PowerShell 5.1: when a native program writes to
    # stderr and its output is redirected with 2>&1, PS 5.1 turns that line into
    # an ErrorRecord. With ErrorActionPreference='Stop' the FIRST such line
    # aborts the script - even when the program is working perfectly and exits 0.
    # git reports its clone progress on stderr, so "Cloning into ..." killed the
    # build on every machine that did not have PowerShell 7. Exit codes, checked
    # below, remain the only thing that decides success or failure.
    $ErrorActionPreference = 'Continue'

    $prevPwd = Get-Location
    try {
        Set-Location $WorkDir
        # Stream the output line by line AS IT ARRIVES. (Collecting it into a
        # variable first makes long tools look frozen for many minutes.)
        $out = New-Object System.Collections.Generic.List[object]
        if ($null -ne $StdIn) {
            $StdIn | & $Exe @Arguments 2>&1 | ForEach-Object {
                [void]$out.Add($_); if (-not $Quiet) { Write-Host "    $_" } }
        } else {
            & $Exe @Arguments 2>&1 | ForEach-Object {
                [void]$out.Add($_); if (-not $Quiet) { Write-Host "    $_" } }
        }
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            # Carry the tool's own error text into the exception. Without this a
            # -Quiet call fails with nothing but a number, which is useless.
            $why = ($out | Select-Object -Last 15 | ForEach-Object { "$_" }) -join "`n      "
            $msg = "$(Split-Path $Exe -Leaf) failed with exit code $code"
            if ($why.Trim()) { $msg += ":`n      $why" }
            throw $msg
        }
        return $out
    } finally {
        Set-Location $prevPwd
        foreach ($k in $old.Keys) { [Environment]::SetEnvironmentVariable($k, $old[$k]) }
    }
}

# --------------------------------------------------------- Gradle with progress
# Gradle can run for the better part of an hour. Run it as a real child process,
# tail its output live, and keep one status line updated so the user can always
# see that something is happening, what it is doing, and roughly how far along.
# Checks whether $KeyPass really unlocks $Alias. Generating a certificate
# request needs the PRIVATE key, so it fails on a wrong password - and unlike
# -keypasswd it changes nothing in the file.
# sdkmanager is a .bat, so PowerShell runs it through cmd.exe - and cmd treats
# ";" as an argument separator. Unquoted, "platforms;android-36" arrives as two
# arguments and the installer reports "Package platforms not found". Wrapping
# the value in literal quotes makes cmd pass it through in one piece.
function Quote-Pkg { param([string]$Name) return ('"' + $Name + '"') }

# From API 37 on, Google names SDK platforms with a minor version:
# "platforms;android-37.0", "-37.1", ... - there is NO plain "platforms;android-37"
# and asking for it fails with "Failed to find package". So compileSdk = 37 has
# to be matched against what the SDK listing really offers. Preference: the
# plain name (API 36 and older), then the ".0" release, then the newest stable
# minor. Betas, previews and "-extNN" variants are never picked.
function Resolve-PlatformPackage {
    param([int]$Api, [string]$Listing)
    if ($Listing) {
        $names = [regex]::Matches($Listing, "platforms;(android-$Api(?:\.\d+)?)(?=[\s|])") |
                 ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        if ($names -contains "android-$Api")   { return "platforms;android-$Api" }
        if ($names -contains "android-$Api.0") { return "platforms;android-$Api.0" }
        $minor = $names | Where-Object { $_ -match "^android-$Api\.\d+$" } |
                 Sort-Object { [int]($_ -replace "^android-$Api\.", '') } -Descending | Select-Object -First 1
        if ($minor) { return "platforms;$minor" }
    }
    # No usable listing: guess from the naming rule.
    if ($Api -ge 37) { return "platforms;android-$Api.0" }
    return "platforms;android-$Api"
}

function Test-KeyPassword {
    param([string]$Keytool, [string]$JavaHome, [string]$Keystore,
          [string]$StorePass, [string]$Alias, [string]$KeyPass, [string[]]$EnglishArgs,
          [string]$StageDir)
    if ([string]::IsNullOrEmpty($KeyPass)) { return $false }
    if ([string]::IsNullOrWhiteSpace($StageDir)) { $StageDir = [IO.Path]::GetTempPath() }
    $tmp = Join-Path $StageDir ("keycheck-" + [IO.Path]::GetRandomFileName() + ".csr")
    try {
        Invoke-Tool -Exe $Keytool -WorkDir $StageDir -EnvVars @{ JAVA_HOME = $JavaHome } -Quiet -Arguments (
            $EnglishArgs + @('-certreq','-alias',$Alias,'-keystore',$Keystore,
                             '-storepass',$StorePass,'-keypass',$KeyPass,'-file',$tmp)) | Out-Null
        return $true
    } catch {
        return $false
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------- SDK packages without sdkmanager
# sdkmanager fetches Google's package index using JAVA's own networking and
# Java's own certificate store. Antivirus HTTPS inspection, a corporate proxy or
# a filtering ISP break that while PowerShell's downloads keep working - which
# is exactly why the tools download fine and then sdkmanager reports
# "IO exception while downloading manifest" and gives up.
#
# This does the same job over PowerShell's network stack instead: read the
# index, pick the exact archives, download and unpack them into place.
function Install-SdkPackagesDirect {
    param([string]$SdkRoot, [string]$DownloadDir, [string]$PlatformPkg, [string]$BuildTools)

    $base = 'https://dl.google.com/android/repository/'
    Say '    fetching the Android package index directly ...'
    [xml]$repo = (Invoke-WebRequest ($base + 'repository2-3.xml') -UseBasicParsing -TimeoutSec 120).Content

    # $PlatformPkg is the real id, e.g. "platforms;android-37.0", and the SDK
    # folder uses that same leaf name.
    $platLeaf = $PlatformPkg -replace '^platforms;', ''
    $wanted = @(
        @{ Path = $PlatformPkg;                      Dest = (Join-Path $SdkRoot "platforms\$platLeaf") },
        @{ Path = "build-tools;$BuildTools";         Dest = (Join-Path $SdkRoot "build-tools\$BuildTools") },
        @{ Path = 'platform-tools';                  Dest = (Join-Path $SdkRoot 'platform-tools') }
    )

    foreach ($w in $wanted) {
        if (Test-Path (Join-Path $w.Dest 'source.properties')) { Ok "$($w.Path) already present"; continue }

        $pkg = $repo.'sdk-repository'.remotePackage | Where-Object { $_.path -eq $w.Path } | Select-Object -First 1
        if (-not $pkg) { throw "The Android package '$($w.Path)' is not listed in Google's index." }

        $arch = $pkg.archives.archive | Where-Object { $_.'host-os' -eq 'windows' } | Select-Object -First 1
        if (-not $arch) { $arch = $pkg.archives.archive | Where-Object { -not $_.'host-os' } | Select-Object -First 1 }
        if (-not $arch) { $arch = @($pkg.archives.archive)[0] }
        if (-not $arch) { throw "No downloadable archive found for '$($w.Path)'." }

        $url = $arch.complete.url
        if ($url -notmatch '^https?://') { $url = $base + $url }

        $zip = Join-Path $DownloadDir (($w.Path -replace '[;:]', '_') + '.zip')
        Get-File -Url $url -OutFile $zip -What "Android package $($w.Path)"

        Say "    unpacking $($w.Path) ..."
        $tmp = Join-Path $DownloadDir ('_unz_' + [IO.Path]::GetRandomFileName())
        Expand-Zip -Zip $zip -Dest $tmp

        # Each of these zips holds one top-level folder named with Google's
        # internal codename - build-tools 36 unpacks as "android-16" - so take
        # whatever is inside and put it where the SDK expects to find it.
        $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
        if (-not $inner) { $inner = Get-Item $tmp }

        $parent = Split-Path $w.Dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        if (Test-Path $w.Dest) { Remove-Item $w.Dest -Recurse -Force }
        Move-Item $inner.FullName $w.Dest -Force
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Ok "$($w.Path) installed"
    }
}

function Invoke-GradleWithProgress {
    param(
        [string]$Gradlew, [string[]]$Arguments, [string]$WorkDir,
        [hashtable]$EnvVars, [string]$RawLog, [string]$BaselineFile
    )
    $old = @{}
    foreach ($k in $EnvVars.Keys) {
        $old[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $EnvVars[$k])
    }

    # A previous successful build tells us roughly how many tasks to expect.
    $expected = 0
    if (Test-Path $BaselineFile) {
        $v = 0; if ([int]::TryParse((Get-Content $BaselineFile -Raw).Trim(), [ref]$v)) { $expected = $v }
    }

    $errLog = "$RawLog.err"
    foreach ($f in @($RawLog, $errLog)) { if (Test-Path $f) { Remove-Item $f -Force } }

    $spin = '|/-\'; $spinIdx = 0
    $done = 0; $lastTask = 'starting Gradle'; $lastDraw = ''; $failed = $false
    $started = Get-Date

    $proc = Start-Process -FilePath $Gradlew -ArgumentList $Arguments -WorkingDirectory $WorkDir `
                          -NoNewWindow -PassThru -RedirectStandardOutput $RawLog -RedirectStandardError $errLog

    Start-Sleep -Milliseconds 300
    $fs = $null; $reader = $null
    try {
        $fs     = New-Object System.IO.FileStream($RawLog, 'Open', 'Read', 'ReadWrite')
        $reader = New-Object System.IO.StreamReader($fs)

        $draw = {
            $el   = (Get-Date) - $started
            $time = '{0:00}:{1:00}' -f [int]$el.TotalMinutes, $el.Seconds
            $idle = [int]((Get-Date) - $script:lastOutputAt).TotalMinutes
            $pct  = ''
            if ($expected -gt 0) {
                $p = [math]::Min(99, [math]::Floor(100 * $done / $expected))
                $pct = ('{0,3}%  ' -f $p)
            }
            $task = $lastTask
            if ($task.Length -gt 46) { $task = '...' + $task.Substring($task.Length - 43) }
            $stall = if ($idle -ge 5) { "  [silent {0}m]" -f $idle } else { '' }
            $txt = ("    [{0}] {1}  {2}{3} tasks  {4}{5}" -f $spin[$spinIdx % 4], $time, $pct, $done, $task, $stall)
            if ($txt -ne $lastDraw) {
                Write-Host ("`r" + $txt.PadRight(100)) -NoNewline -ForegroundColor Cyan
                $script:__lastDraw = $txt
            }
            $lastDraw = $txt
        }

        $script:lastOutputAt = Get-Date
        $warned = 0
        while ($true) {
            $gotLine = $false
            while ($null -ne ($line = $reader.ReadLine())) {
                $gotLine = $true
                $script:lastOutputAt = Get-Date
                if ($line -match '^> Task (\S+)') { $done++; $lastTask = $Matches[1] }
                elseif ($line -match '^(FAILURE|\* What went wrong)') { $failed = $true }
                elseif ($line -match '^> (Transforming|Downloading|Starting|Configure|Resolve) ') {
                    $lastTask = $line.Substring(2)
                }
            }
            $spinIdx++
            & $draw

            # A build that has produced nothing for a long time is not "slow",
            # it is stuck. Say so instead of spinning forever in silence.
            $idleMin = [int]((Get-Date) - $script:lastOutputAt).TotalMinutes
            if ($idleMin -ge 15 -and $warned -lt 1) {
                $warned = 1
                Write-Host ''
                Write-Host '' 
                Warn "Gradle has produced no output for $idleMin minutes. That is not normal."
                Say  '    Most likely causes, in order:'
                Say  '      1. Antivirus is scanning every file Gradle writes. Add the'
                Say  '         AAPS-Builder-Files folder to your antivirus exclusions.'
                Say  '      2. The PC has run out of memory and is swapping to disk.'
                Say  '      3. The build genuinely wedged.'
                Say  '    Open Task Manager: if CPU and disk are near zero, it is stuck -'
                Say  '    close this window and run Build-AAPS.bat again. Nothing is lost,'
                Say  '    the build resumes from where it got to.'
                Write-Host ''
            }
            if ($idleMin -ge 45 -and $warned -lt 2) {
                $warned = 2
                Warn "Still nothing after $idleMin minutes - this build is almost certainly stuck. Close the window and run it again."
            }

            if ($proc.HasExited -and -not $gotLine) { break }
            Start-Sleep -Milliseconds 400
        }
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line -match '^> Task (\S+)') { $done++; $lastTask = $Matches[1] }
        }
        & $draw
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($fs)     { $fs.Dispose() }
        $proc.WaitForExit()
        Write-Host ''
        foreach ($k in $old.Keys) { [Environment]::SetEnvironmentVariable($k, $old[$k]) }
    }

    if ($proc.ExitCode -ne 0) {
        # Show the part of the log that explains why, so the user can paste it.
        Write-Host ''
        Write-Host '    ---- last lines of the Gradle output ----' -ForegroundColor Yellow
        Get-Content $RawLog -Tail 40 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" }
        if (Test-Path $errLog) { Get-Content $errLog -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" } }
        Write-Host '    ----------------------------------------' -ForegroundColor Yellow
        throw "Gradle failed with exit code $($proc.ExitCode)"
    }
    if ($done -gt 0) { Set-Content -Path $BaselineFile -Value $done -Encoding ASCII }
    return $done
}

# ===================================================== PowerShell 7 bootstrap
# Windows PowerShell 5.1 is full of sharp edges this script keeps hitting: it
# turns a native program's stderr into a fatal error, handles UTF-8 badly, and
# is simply not what any of this was tested on. Rather than ask a nervous user
# to install anything, fetch a PORTABLE PowerShell 7 into the tools folder and
# re-launch ourselves under it. No installer, no Administrator, nothing added
# to Windows. Everything after this point therefore runs on a known-good shell.
if ($PSVersionTable.PSVersion.Major -lt 7 -and $env:AAPS_PWSH_BOOTSTRAPPED -ne '1' -and -not $SelfTest) {

    $bootBase = $null
    foreach ($cand in @($Support, (Join-Path $env:LOCALAPPDATA 'AAPS-Build'), $env:TEMP)) {
        if ([string]::IsNullOrWhiteSpace($cand)) { continue }
        if ($cand -match '[^\x20-\x7E]') { continue }
        try {
            $probe = Join-Path $cand 'aaps-tools'
            New-Item -ItemType Directory -Path $probe -Force -ErrorAction Stop | Out-Null
            $bootBase = $probe; break
        } catch { }
    }

    $pwshExe = if ($bootBase) { Join-Path $bootBase 'pwsh\pwsh.exe' } else { $null }

    if ($pwshExe -and -not (Test-Path $pwshExe)) {
        Write-Host ''
        Write-Host ' Preparing a modern PowerShell (one-time, about 100 MB)...' -ForegroundColor Cyan
        Write-Host ' Nothing is installed on your computer - it goes in the tools folder.' -ForegroundColor Gray
        try {
            $url = $null
            try {
                $rel = Invoke-RestMethod 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' `
                         -Headers @{ 'User-Agent' = 'aaps-builder' } -TimeoutSec 60
                $asset = $rel.assets | Where-Object { $_.name -match '^PowerShell-[\d.]+-win-x64\.zip$' } | Select-Object -First 1
                if ($asset) { $url = $asset.browser_download_url }
            } catch { }
            if (-not $url) { $url = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.zip' }

            $zip = Join-Path $bootBase 'pwsh.zip'
            Get-File -Url $url -OutFile $zip -What 'PowerShell 7 (portable)'
            Say '    unpacking PowerShell ...'
            Expand-Zip -Zip $zip -Dest (Join-Path $bootBase 'pwsh')
            Remove-Item $zip -Force -ErrorAction SilentlyContinue
        } catch {
            Warn "Could not fetch PowerShell 7 ($($_.Exception.Message)). Carrying on with the older one."
        }
    }

    if ($pwshExe -and (Test-Path $pwshExe)) {
        Ok 'Restarting under PowerShell 7'
        $env:AAPS_PWSH_BOOTSTRAPPED = '1'
        & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
        exit $LASTEXITCODE
    }

    Warn 'Running on Windows PowerShell 5.1 - this is less well tested. If anything behaves oddly, install PowerShell 7 and run again.'
}

# ================================================== legal notice (Hebrew, RTL)
$DisclaimerHe = @"
DISCLAIMER AND LIMITATION OF LIABILITY

This script builds AAPS (AndroidAPS), open-source software written by a third
party. $AuthorName does not own AAPS, does not develop it, and is not
affiliated with it in any way.

The software and this script are provided AS IS, without warranty of any kind,
express or implied, including but not limited to warranties of fitness for a
particular purpose, correctness, availability, accuracy, or non-infringement.

AAPS IS NOT AN APPROVED MEDICAL DEVICE. It is not a substitute for medical
advice, diagnosis or treatment. Using a system that manages insulin delivery
can cause serious harm, including risk to life.

Your use of this script, of the code, and of any file it produces is entirely
at your own risk and your sole responsibility.

$AuthorName shall not be liable, on any legal basis whatsoever, for any direct,
indirect, special, consequential or other damage - including bodily injury,
financial loss or loss of data - arising from the use of, or the inability to
use, this script, even if advised of the possibility of such damage.

Nothing here is a medical recommendation or an encouragement to use AAPS.
Consult your treating medical team before making any change to your therapy.

Ticking the box below and clicking "I Agree" confirms that you have read,
understood and accepted all of the above.
"@

function Show-Disclaimer {
    # Save a copy next to the script so it can always be read calmly.
    try { Set-Content -Path (Join-Path $Support 'DISCLAIMER.txt') -Value $DisclaimerHe -Encoding UTF8 } catch { }

    $accepted = $false

    # A real window is used because Windows consoles cannot lay out Hebrew RTL.
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing        -ErrorAction Stop
        [Windows.Forms.Application]::EnableVisualStyles()

        $font    = New-Object Drawing.Font('Segoe UI', 11)
        $fontBig = New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)

        $form = New-Object Windows.Forms.Form
        $form.Text            = 'AAPS Builder - Disclaimer and Limitation of Liability'
        $form.ClientSize      = New-Object Drawing.Size(720, 580)
        $form.StartPosition   = 'CenterScreen'
        $form.FormBorderStyle = 'FixedDialog'
        $form.MinimizeBox     = $false
        $form.MaximizeBox     = $false
        $form.TopMost         = $true
        $form.AutoScaleMode   = 'Font'
        $form.RightToLeft     = 'No'
        $form.BackColor       = [Drawing.Color]::FromArgb(251, 243, 228)

        $box = New-Object Windows.Forms.TextBox
        $box.Multiline   = $true
        $box.ReadOnly    = $true
        $box.ScrollBars  = 'Vertical'
        $box.RightToLeft = 'No'
        $box.Font        = $font
        $box.BackColor   = [Drawing.Color]::White
        $box.Location    = New-Object Drawing.Point(20, 20)
        $box.Size        = New-Object Drawing.Size(680, 420)
        $box.Text        = ($DisclaimerHe -replace "`r?`n", "`r`n")
        $box.Select(0, 0)

        $chk = New-Object Windows.Forms.CheckBox
        $chk.Text        = 'I have read and understood the above, and I accept full responsibility.'
        $chk.Font        = $fontBig
        $chk.RightToLeft = 'No'
        $chk.Location    = New-Object Drawing.Point(20, 455)
        $chk.Size        = New-Object Drawing.Size(680, 32)

        # Agree sits on the right, which is the primary position in a Hebrew dialog.
        $btnYes = New-Object Windows.Forms.Button
        $btnYes.Text         = 'I Agree'
        $btnYes.Font         = $fontBig
        $btnYes.Size         = New-Object Drawing.Size(170, 46)
        $btnYes.Location     = New-Object Drawing.Point(345, 500)
        $btnYes.Enabled      = $false
        $btnYes.DialogResult = [Windows.Forms.DialogResult]::Yes

        $btnNo = New-Object Windows.Forms.Button
        $btnNo.Text         = 'I Do Not Agree'
        $btnNo.Font         = $font
        $btnNo.Size         = New-Object Drawing.Size(170, 46)
        $btnNo.Location     = New-Object Drawing.Point(530, 500)
        $btnNo.DialogResult = [Windows.Forms.DialogResult]::No

        # The Agree button stays dead until the box is ticked.
        $chk.Add_CheckedChanged({ $btnYes.Enabled = $chk.Checked }.GetNewClosure())

        $form.CancelButton = $btnNo          # Esc and the X both mean "do not agree"
        $form.Controls.AddRange(@($box, $chk, $btnYes, $btnNo))

        $result = $form.ShowDialog()
        $accepted = ($result -eq [Windows.Forms.DialogResult]::Yes -and $chk.Checked)
        $form.Dispose()

        if (-not $accepted) {
            Write-Host ''
            Write-Host ' Disclaimer not accepted - nothing was built.' -ForegroundColor Yellow
                        try { Stop-Transcript | Out-Null } catch {}
            exit 2
        }
        return
    } catch { }

    # Fallback if a window cannot be created at all (server core, no desktop).
    Write-Host ''
    Write-Host ' DISCLAIMER' -ForegroundColor Yellow
    Write-Host ' The full text is in the AAPS-Builder-Files folder, DISCLAIMER.txt.' -ForegroundColor Yellow
    Write-Host ' AAPS is not an approved medical device. This script is provided AS IS,' -ForegroundColor Yellow
    Write-Host ' with no warranty of any kind. All use is entirely at your own risk.' -ForegroundColor Yellow
    Write-Host ' The author accepts no liability of any kind for any damage whatsoever.' -ForegroundColor Yellow
    Write-Host ''
    $a = Read-Host ' Type  YES  to confirm you have read, understood and accept full responsibility'
    if ($a.Trim().ToUpper() -ne 'YES') {
        Write-Host ' Disclaimer not accepted - nothing was built.' -ForegroundColor Yellow
        try { Stop-Transcript | Out-Null } catch {}
        exit 2
    }
}

# =============================================================== 0. START / LOG
try { Stop-Transcript | Out-Null } catch {}
Start-Transcript -Path $LogFile -Force | Out-Null

# Shown on every single run, before anything else happens.
# (Skipped for -SelfTest: that mode checks the machine, it builds nothing.)
if (-not $SelfTest) { Show-Disclaimer }

if (-not $SelfTest) {
Clear-Host
Write-Host @"
================================================================
        AAPS  (AndroidAPS)  -  automatic APK builder
================================================================
 This window will do everything by itself.
 The FIRST run downloads several GB and can take 30-90 minutes.
 Later runs are much faster.

 Do not close this window while it is working.
================================================================
"@ -ForegroundColor Cyan
Say " Working folder: $Root"
}

# =============================================================== 1. SANITY
if (-not $SelfTest) { Step '1/8  Checking your computer' }

if (-not [Environment]::Is64BitOperatingSystem) { Fail 'A 64-bit version of Windows is required.' }

$ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
if (-not $SelfTest) { Say "    RAM: $ramGb GB" }
if ($ramGb -lt 8) { Warn "$ramGb GB of RAM is below the recommended 16 GB. The build may be very slow." }

if (-not $SelfTest) {
    try { Invoke-WebRequest -Uri 'https://github.com' -UseBasicParsing -TimeoutSec 20 -Method Head | Out-Null }
    catch { Fail 'No working internet connection to github.com. Connect to the internet and run this again.' }
}

# ---- Choose where the heavy build happens -----------------------------------
# You can keep this script wherever you like, including Documents. The build
# itself needs somewhere that is: writable without Administrator, free of
# non-English characters (Gradle and the JDK choke on them), and NOT synced to
# OneDrive / Dropbox / Google Drive (sync corrupts builds and uploads ~20 GB of
# junk). The script picks the first location below that satisfies all of that.

function Test-Writable {
    param([string]$Path)
    try {
        New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
        $probe = Join-Path $Path ".write-test-$PID"
        Set-Content -Path $probe -Value 'x' -ErrorAction Stop
        Remove-Item $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch { return $false }
}
function Test-CloudSynced {
    param([string]$Path)
    if ($Path -match '(?i)onedrive|dropbox|google\s*drive|\\box\\|iCloudDrive') { return $true }
    foreach ($v in 'OneDrive','OneDriveCommercial','OneDriveConsumer') {
        $od = [Environment]::GetEnvironmentVariable($v)
        if ($od -and $Path.StartsWith($od, 'OrdinalIgnoreCase')) { return $true }
    }
    return $false
}
function Get-FreeGb {
    param([string]$Path)
    try { return [math]::Round((Get-PSDrive (Split-Path -Qualifier $Path).TrimEnd(':')).Free / 1GB, 1) }
    catch { return 0 }
}

# Each candidate is added only if its base folder actually exists as an
# environment variable - Join-Path throws on a null path, and under
# ErrorActionPreference='Stop' that would kill the script outright.
function Add-Candidate {
    param([System.Collections.ArrayList]$List, [string]$Base, [string]$Leaf)
    if ([string]::IsNullOrWhiteSpace($Base)) { return }
    try { [void]$List.Add((Join-Path $Base $Leaf)) } catch { }
}
$sysDrive   = $env:SystemDrive; if (-not $sysDrive) { $sysDrive = 'C:\' }
$candidates = New-Object System.Collections.ArrayList
[void]$candidates.Add($Support)                               # inside AAPS-Builder-Files - ideal if it qualifies
Add-Candidate $candidates $env:LOCALAPPDATA 'AAPS-Build'      # per-user, never synced, no admin
Add-Candidate $candidates $env:PUBLIC       'AAPS-Build'      # always plain ASCII, no admin
Add-Candidate $candidates $sysDrive         'AAPS-Build'      # last resort (may prompt for admin)

$WorkRoot = $null
foreach ($c in $candidates) {
    $why = @()
    if ($c -match '[^\x20-\x7E]')  { $why += 'contains non-English characters' }
    if (Test-CloudSynced $c)       { $why += 'is inside a cloud-synced folder' }
    if ($c.Length -gt 80)          { $why += 'path is too long' }
    if ($why.Count -eq 0 -and -not (Test-Writable $c)) { $why += 'is not writable without Administrator' }
    if ($why.Count -eq 0) {
        $free = Get-FreeGb $c
        if ($free -lt 20) { $why += "only $free GB free on that drive" }
    }
    if ($why.Count -eq 0) { $WorkRoot = $c; break }
    Say "    not using $c  ($($why -join '; '))"
}
if (-not $WorkRoot) {
    Fail ("Could not find anywhere suitable to build.`n" +
          " The build needs about 30 GB, a path with only English letters, and a folder`n" +
          " that is not synced to OneDrive/Dropbox. Free up disk space and run again.")
}

$ToolsDir = Join-Path $WorkRoot 'aaps-tools'
$SrcDir   = Join-Path $WorkRoot 'AndroidAPS'
$DlDir    = Join-Path $ToolsDir 'downloads'
$JdkDir   = Join-Path $ToolsDir 'jdk'
$GitDir   = Join-Path $ToolsDir 'git'
$SdkDir   = Join-Path $ToolsDir 'android-sdk'

# Java tools (keytool, apksigner) resolve file names using sun.jnu.encoding,
# which follows the Windows ANSI code page - NOT Unicode. On an English-locale
# Windows with a Hebrew folder or user name they simply cannot see the file.
# $WorkRoot is guaranteed plain ASCII by the checks above, so anything handed
# to a Java tool is staged through here and moved back with PowerShell, which
# has no such limitation.
$SignStage   = Join-Path $WorkRoot 'signing'
$RootIsAscii = ($Root -notmatch '[^\x20-\x7E]')

$freeGb = Get-FreeGb $WorkRoot
if (-not $SelfTest) { Say "    Free space where it will build: $freeGb GB" }
if ($freeGb -lt 30) { Warn "Only $freeGb GB free. 30 GB is recommended - the build may run out of space." }

if (-not $SelfTest) { Ok "Your APK and key will be in:  $Root" }
if ($WorkRoot -ne $Support) {
    Ok "The build itself will run in: $WorkRoot"
    Say '    (that folder is just a workspace - you can delete it any time)'
}

New-Item -ItemType Directory -Path $ToolsDir, $DlDir, $SignStage -Force | Out-Null
if (-not $RootIsAscii) {
    Warn 'Your folder name contains non-English characters.'
    Say  '    Java cannot always open such paths, so signing is done in a plain-English'
    Say  '    working folder and the finished files are copied back here. Nothing for you to do.'
}

# ============================================================ SELF TEST
# Runs the checks that have actually caught this script out on real machines,
# without downloading gigabytes or building anything. Two minutes, not an hour.
if ($SelfTest) {
    $pass = 0; $fail = 0; $warn = 0
    function T {
        param([string]$Name, [scriptblock]$Check)
        try {
            $r = @(& $Check)[-1]     # take the last value, ignore stray output
            $isWarn = ($r -is [string]) -and ([string]$r -ceq 'WARN')
            if ($isWarn)      { Write-Host ("  WARN  " + $Name) -ForegroundColor Yellow; $script:warn++ }
            elseif ($r -eq $true) { Write-Host ("  PASS  " + $Name) -ForegroundColor Green; $script:pass++ }
            else              { Write-Host ("  FAIL  " + $Name) -ForegroundColor Red;    $script:fail++ }
        } catch {
            Write-Host ("  FAIL  " + $Name + "  ->  " + $_.Exception.Message.Split([char]10)[0]) -ForegroundColor Red
            $script:fail++
        }
    }

    Write-Host ''
    Write-Host '================ AAPS Builder self-test ================' -ForegroundColor Cyan
    Write-Host " Shell   : PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    Write-Host " Windows : $([Environment]::OSVersion.Version)"
    Write-Host " Folder  : $Support"
    Write-Host ''

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('aaps-selftest-' + [IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
        if (-not $onWindows) { Write-Host '  SKIP  cmd.exe checks (not running on Windows)' -ForegroundColor DarkGray }
        if ($onWindows) {
        T 'a native tool writing to stderr does not abort the script' {
            $b = Join-Path $tmp 'err.bat'
            Set-Content $b -Value @('@echo off','echo progress message 1>&2','exit /b 0') -Encoding ASCII
            $null = Invoke-Tool -Exe $b -WorkDir $tmp -Quiet -Arguments @(); $true
        }
        T 'a genuinely failing tool is still caught' {
            $b = Join-Path $tmp 'bad.bat'
            Set-Content $b -Value @('@echo off','echo something broke 1>&2','exit /b 3') -Encoding ASCII
            try { $null = Invoke-Tool -Exe $b -WorkDir $tmp -Quiet -Arguments @(); $false } catch { $true }
        }
        T 'semicolon package names survive the trip through cmd.exe' {
            $b = Join-Path $tmp 'args.bat'
            Set-Content $b -Value @('@echo off',':loop','if "%~1"=="" exit /b 0','echo ARG=%~1','shift','goto loop') -Encoding ASCII
            $out = Invoke-Tool -Exe $b -WorkDir $tmp -Quiet -Arguments @((Quote-Pkg 'platforms;android-36'))
            [bool](($out -join "`n") -match 'ARG=platforms;android-36')
        }
        }
        T 'SDK platform names with a minor version (android-37.0) are resolved' {
            $l = "  platforms;android-36    | 2 | x`n  platforms;android-36-ext19 | 1 | x`n" +
                 "  platforms;android-37.0  | 2 | x`n  platforms;android-37.2 | 2 | x`n  platforms;android-37.2-beta3 | 3 | x"
            (Resolve-PlatformPackage -Api 37 -Listing $l) -eq 'platforms;android-37.0' -and
            (Resolve-PlatformPackage -Api 36 -Listing $l) -eq 'platforms;android-36' -and
            (Resolve-PlatformPackage -Api 37 -Listing '') -eq 'platforms;android-37.0'
        }
        T 'a window can be shown (needed for the legal notice)' {
            try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop; $true } catch { 'WARN' }
        }
        T 'the console can print UTF-8 file names' {
            $f = Join-Path $tmp ("unicode-" + [char]0x00E9 + [char]0x00FC + ".txt")
            Set-Content -LiteralPath $f -Value 'x' -Encoding UTF8
            [bool](Test-Path -LiteralPath $f)
        }
        T "a usable build folder was found ($WorkRoot)" { [bool]$WorkRoot }
        T "build folder is plain ASCII" { [bool]($WorkRoot -notmatch '[^\x20-\x7E]') }
        T "at least 30 GB free where it builds" {
            $g = Get-FreeGb $WorkRoot; if ($g -ge 30) { $true } elseif ($g -ge 20) { 'WARN' } else { $false }
        }
        T "reaching github.com" {
            try { Invoke-WebRequest 'https://github.com' -UseBasicParsing -Method Head -TimeoutSec 20 | Out-Null; $true } catch { $false }
        }
        T "reaching the Java download (adoptium.net)" {
            try { Invoke-WebRequest 'https://api.adoptium.net/v3/info/available_releases' -UseBasicParsing -TimeoutSec 30 | Out-Null; $true } catch { $false }
        }
        T "reaching the Android tools download (dl.google.com)" {
            try { Invoke-WebRequest 'https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip' -UseBasicParsing -Method Head -TimeoutSec 30 | Out-Null; $true } catch { $false }
        }
        T "the known-good Android tools version is still published" {
            try { Invoke-WebRequest 'https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip' -UseBasicParsing -Method Head -TimeoutSec 30 | Out-Null; $true } catch { $false }
        }

        # These only apply once tools have been downloaded by a real run.
        $javaExe = Join-Path $JdkDir 'bin\java.exe'
        if (Test-Path $javaExe) {
            T 'keytool reports in English (needed to read key names)' {
                $kt = Join-Path $JdkDir 'bin\keytool.exe'
                $ks = Join-Path $tmp 'test.jks'
                Invoke-Tool -Exe $kt -WorkDir $tmp -Quiet -EnvVars @{ JAVA_HOME = $JdkDir } -Arguments @(
                    '-J-Duser.language=en','-J-Duser.country=US','-genkeypair','-keystore',$ks,'-alias','t',
                    '-keyalg','RSA','-keysize','2048','-validity','1','-storepass','test1234','-keypass','test1234',
                    '-dname','CN=t') | Out-Null
                $l = Invoke-Tool -Exe $kt -WorkDir $tmp -Quiet -EnvVars @{ JAVA_HOME = $JdkDir } -Arguments @(
                    '-J-Duser.language=en','-J-Duser.country=US','-list','-v','-keystore',$ks,'-storepass','test1234')
                [bool](($l -join "`n") -match '(?im)^Alias name:')
            }
        } else {
            Write-Host '  SKIP  Java checks (nothing downloaded yet - run a real build first)' -ForegroundColor DarkGray
        }

        $sdkMgrT    = Join-Path $SdkDir 'cmdline-tools\latest\bin\sdkmanager.bat'
        $androidBatT = Join-Path $SdkDir 'cmdline-tools\latest\bin\android.bat'
        if (Test-Path $sdkMgrT) {
            T 'the Android tools are the working version, not the broken new one' {
                [bool](-not (Test-Path $androidBatT))
            }
        } else {
            Write-Host '  SKIP  Android SDK checks (nothing downloaded yet)' -ForegroundColor DarkGray
        }

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            Write-Host '  NOTE  This is Windows PowerShell 5.1. A real run will fetch PowerShell 7 first.' -ForegroundColor Yellow
        }
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host '========================================================' -ForegroundColor Cyan
    if ($fail -eq 0) {
        Write-Host "  $pass passed, $warn warnings, 0 failed - safe to build." -ForegroundColor Green
    } else {
        Write-Host "  $pass passed, $warn warnings, $fail FAILED." -ForegroundColor Red
        Write-Host '  Send this window to whoever is helping you.' -ForegroundColor Red
    }
    Write-Host '========================================================' -ForegroundColor Cyan
    Write-Host ''
    try { Stop-Transcript | Out-Null } catch {}
    exit ($(if ($fail -eq 0) { 0 } else { 1 }))
}

# =============================================================== 2. WHAT TO BUILD
Step '2/8  What do you want to build?'
Write-Host ''
Write-Host '      1  -  Phone app only            (this is what almost everyone wants)' -ForegroundColor White
Write-Host '      2  -  Wear OS smartwatch app only' -ForegroundColor White
Write-Host '      3  -  Both phone app and watch app' -ForegroundColor White
Write-Host ''
$choice = Read-Host '    Type 1, 2 or 3 and press Enter (just press Enter for 1)'
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
switch ($choice.Trim()) {
    '1' { $BuildPhone = $true;  $BuildWear = $false; $what = 'Phone app' }
    '2' { $BuildPhone = $false; $BuildWear = $true;  $what = 'Watch app' }
    '3' { $BuildPhone = $true;  $BuildWear = $true;  $what = 'Phone app + Watch app' }
    default { $BuildPhone = $true; $BuildWear = $false; $what = 'Phone app (unrecognised answer, using the default)' }
}
Ok "Will build: $what"

# =============================================================== 3. GIT
Step '3/8  Git'
$gitExe = Join-Path $GitDir 'cmd\git.exe'
if (-not (Test-Path $gitExe)) {
    $mingitUrl = $null
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/git-for-windows/git/releases/latest' -Headers @{ 'User-Agent' = 'aaps-builder' } -TimeoutSec 60
        $asset = $rel.assets | Where-Object { $_.name -match '^MinGit-.*-64-bit\.zip$' -and $_.name -notmatch 'busybox' } | Select-Object -First 1
        if ($asset) { $mingitUrl = $asset.browser_download_url }
    } catch { }
    if (-not $mingitUrl) {
        $mingitUrl = 'https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/MinGit-2.47.1-64-bit.zip'
        Warn 'Could not ask GitHub for the newest Git, using a known-good version instead.'
    }
    $gitZip = Join-Path $DlDir 'mingit.zip'
    Get-File -Url $mingitUrl -OutFile $gitZip -What 'Git (portable)'
    Say '    unpacking Git ...'
    Expand-Zip -Zip $gitZip -Dest $GitDir
}
if (-not (Test-Path $gitExe)) { Fail 'Git could not be set up. Delete the aaps-tools folder and try again.' }
Ok 'Git ready'

# =============================================================== 4. SOURCE CODE
Step "4/8  AAPS source code (branch: $AapsBranch)"
$gitEnv = @{ GIT_TERMINAL_PROMPT = '0'; HOME = $ToolsDir }
if (Test-Path (Join-Path $SrcDir '.git')) {
    Say '    updating existing copy ...'
    try {
        Invoke-Tool -Exe $gitExe -WorkDir $SrcDir -EnvVars $gitEnv -Quiet -Arguments @('fetch','--prune','origin',$AapsBranch) | Out-Null
        Invoke-Tool -Exe $gitExe -WorkDir $SrcDir -EnvVars $gitEnv -Quiet -Arguments @('checkout','-f',$AapsBranch) | Out-Null
        Invoke-Tool -Exe $gitExe -WorkDir $SrcDir -EnvVars $gitEnv -Quiet -Arguments @('reset','--hard',"origin/$AapsBranch") | Out-Null
        Invoke-Tool -Exe $gitExe -WorkDir $SrcDir -EnvVars $gitEnv -Quiet -Arguments @('clean','-fd','-e','local.properties') | Out-Null
    } catch {
        Warn 'The existing copy of the source could not be updated - downloading a fresh copy.'
        Remove-Item $SrcDir -Recurse -Force
    }
}
if (-not (Test-Path (Join-Path $SrcDir '.git'))) {
    Say '    downloading source code (about 1 GB, please be patient) ...'
    Invoke-Tool -Exe $gitExe -WorkDir $WorkRoot -EnvVars $gitEnv -Arguments @(
        '-c','core.longpaths=true','-c','core.autocrlf=false',
        'clone','--progress','--branch',$AapsBranch,'--single-branch',$AapsRepo,$SrcDir
    ) | Out-Null
}
$commit = ((Invoke-Tool -Exe $gitExe -WorkDir $SrcDir -EnvVars $gitEnv -Quiet -Arguments @('rev-parse','--short','HEAD')) -join '').Trim()

# =========================================== 5. READ WHAT THIS VERSION NEEDS
Step '5/8  Working out what this version of AAPS needs'
Say '    (reading it out of the source code, so it is always correct)'

$AppVersion = 'unknown'; $ReqJdk = $null; $ReqPlatform = $null; $ReqBuildTools = $null

$vFile = Join-Path $SrcDir 'buildSrc\src\main\kotlin\Versions.kt'
if (-not (Test-Path $vFile)) {
    $vFile = Get-ChildItem -Path $SrcDir -Recurse -Filter 'Versions.kt' -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -match '\\buildSrc\\|\\build-logic\\' } | Select-Object -First 1 -ExpandProperty FullName
}
if ($vFile -and (Test-Path $vFile)) {
    $vTxt = Get-Content $vFile -Raw
    $m = [regex]::Match($vTxt, 'appVersion\s*=\s*"([^"]+)"');            if ($m.Success) { $AppVersion  = $m.Groups[1].Value }
    $m = [regex]::Match($vTxt, 'javaVersion\s*=\s*JavaVersion\.VERSION_(\d+)'); if ($m.Success) { $ReqJdk = $m.Groups[1].Value }
    if (-not $ReqJdk) { $m = [regex]::Match($vTxt, 'jvmTarget\s*=\s*JvmTarget\.JVM_(\d+)'); if ($m.Success) { $ReqJdk = $m.Groups[1].Value } }
    $m = [regex]::Match($vTxt, 'compileSdk\s*=\s*(\d+)');                if ($m.Success) { $ReqPlatform = [int]$m.Groups[1].Value }
    $m = [regex]::Match($vTxt, 'buildTools(?:Version)?\s*=\s*"([^"]+)"'); if ($m.Success) { $ReqBuildTools = $m.Groups[1].Value }
} else {
    Warn 'Could not find Versions.kt in the source - falling back to known-good versions.'
}
if (-not $ReqJdk)      { $ReqJdk      = $FallbackJdk;      Warn "Java version not found in source, assuming Java $ReqJdk." }
if (-not $ReqPlatform) { $ReqPlatform = $FallbackPlatform; Warn "compileSdk not found in source, assuming android-$ReqPlatform." }

# Gradle comes from the wrapper in the source itself - just report it.
$gwProps = Join-Path $SrcDir 'gradle\wrapper\gradle-wrapper.properties'
$GradleVer = 'from wrapper'
if (Test-Path $gwProps) {
    $m = [regex]::Match((Get-Content $gwProps -Raw), 'gradle-([\d.]+)-(bin|all)\.zip')
    if ($m.Success) { $GradleVer = $m.Groups[1].Value }
}
# Android Gradle Plugin, for the log only.
$AgpVer = 'unknown'
$tomlFile = Join-Path $SrcDir 'gradle\libs.versions.toml'
if (Test-Path $tomlFile) {
    $m = [regex]::Match((Get-Content $tomlFile -Raw), '(?im)^\s*(?:android-)?gradle-plugin\s*=\s*"([\d.]+)"')
    if (-not $m.Success) { $m = [regex]::Match((Get-Content $tomlFile -Raw), '(?im)^\s*agp\s*=\s*"([\d.]+)"') }
    if ($m.Success) { $AgpVer = $m.Groups[1].Value }
}

Ok "AAPS $AppVersion (commit $commit)"
Ok "Needs: Java $ReqJdk | android-$ReqPlatform | Gradle $GradleVer | AGP $AgpVer"

# =============================================================== 6. JAVA + SDK
Step "6/8  Java $ReqJdk and the Android SDK"

# ---- 6a. Java: install, or REPLACE if the wrong major version is sitting there
$javaExe  = Join-Path $JdkDir 'bin\java.exe'
$haveJdk  = $null
if (Test-Path $javaExe) {
    try {
        $vOut = (& $javaExe -version 2>&1) -join ' '
        $m = [regex]::Match($vOut, 'version "(\d+)')
        if ($m.Success) { $haveJdk = $m.Groups[1].Value }
    } catch { }
}
if ($haveJdk -and $haveJdk -ne $ReqJdk) {
    Warn "AAPS now needs Java $ReqJdk but Java $haveJdk is installed here - replacing it."
    Remove-Item $JdkDir -Recurse -Force
    Get-ChildItem $DlDir -Filter 'temurin-*.zip' -ErrorAction SilentlyContinue | Remove-Item -Force
    $haveJdk = $null
}
if (-not $haveJdk) {
    $jdkZip = Join-Path $DlDir "temurin-$ReqJdk.zip"
    $jdkUrl = "https://api.adoptium.net/v3/binary/latest/$ReqJdk/ga/windows/x64/jdk/hotspot/normal/eclipse"
    Get-File -Url $jdkUrl -OutFile $jdkZip -What "Java $ReqJdk (Eclipse Temurin)"
    Say '    unpacking Java ...'
    $tmp = Join-Path $ToolsDir '_jdk_tmp'
    Expand-Zip -Zip $jdkZip -Dest $tmp
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (-not $inner) { Fail 'The Java download looks corrupted. Delete the aaps-tools folder and run this script again.' }
    if (Test-Path $JdkDir) { Remove-Item $JdkDir -Recurse -Force }
    Move-Item $inner.FullName $JdkDir
    Remove-Item $tmp -Recurse -Force
}
if (-not (Test-Path $javaExe)) { Fail 'Java could not be set up. Delete the aaps-tools folder and try again.' }
$JavaHome = $JdkDir
$keytool  = Join-Path $JdkDir 'bin\keytool.exe'
Ok "Java ready: $(((& $javaExe -version 2>&1) | Select-Object -First 1))"

# ---- 6b. Android command line tools
$sdkMgr    = Join-Path $SdkDir 'cmdline-tools\latest\bin\sdkmanager.bat'
$androidBat = Join-Path $SdkDir 'cmdline-tools\latest\bin\android.bat'

# Google has started shipping a cmdline-tools package in which sdkmanager is a
# thin deprecated wrapper around a new "android" CLI. That wrapper crashes on
# --update and mangles package names, so it cannot install anything. If that
# version is sitting here, throw it away and fetch the last good one instead.
if ((Test-Path $sdkMgr) -and (Test-Path $androidBat)) {
    Warn 'The Android tools here are the new incompatible version - replacing them with the last working one.'
    Remove-Item (Join-Path $SdkDir 'cmdline-tools') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $DlDir 'cmdline-tools.zip') -Force -ErrorAction SilentlyContinue
    Get-ChildItem $SdkDir -Filter '.installed-*' -Force -ErrorAction SilentlyContinue | Remove-Item -Force
}

if (-not (Test-Path $sdkMgr)) {
    # Known-good revision FIRST. Newest-wins was the whole problem: Google's
    # latest package replaced a working tool with one that cannot install.
    $ctUrl = $null
    foreach ($rev in @('13114758','12700392','11076708')) {
        $try = "https://dl.google.com/android/repository/commandlinetools-win-${rev}_latest.zip"
        try { Invoke-WebRequest $try -UseBasicParsing -Method Head -TimeoutSec 30 | Out-Null; $ctUrl = $try; break } catch { }
    }
    if (-not $ctUrl) {
        Warn 'None of the known-good Android tool versions are available - falling back to whatever Google lists as newest.'
        try {
            $xml = Invoke-WebRequest 'https://dl.google.com/android/repository/repository2-3.xml' -UseBasicParsing -TimeoutSec 60
            $names = [regex]::Matches($xml.Content, 'commandlinetools-win-(\d+)_latest\.zip') |
                     ForEach-Object { [pscustomobject]@{ File = $_.Value; Rev = [int64]$_.Groups[1].Value } } |
                     Sort-Object Rev -Descending
            if ($names) { $ctUrl = "https://dl.google.com/android/repository/$($names[0].File)" }
        } catch { }
    }
    if (-not $ctUrl) { Fail 'Could not find the Android command line tools download. Check your internet connection / firewall and try again.' }
    $ctZip = Join-Path $DlDir 'cmdline-tools.zip'
    Get-File -Url $ctUrl -OutFile $ctZip -What 'Android command line tools'
    Say '    unpacking Android tools ...'
    $tmp = Join-Path $ToolsDir '_ct_tmp'
    Expand-Zip -Zip $ctZip -Dest $tmp
    $dest = Join-Path $SdkDir 'cmdline-tools'
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    if (Test-Path (Join-Path $dest 'latest')) { Remove-Item (Join-Path $dest 'latest') -Recurse -Force }
    Move-Item (Join-Path $tmp 'cmdline-tools') (Join-Path $dest 'latest')
    Remove-Item $tmp -Recurse -Force
}
if (-not (Test-Path $sdkMgr)) { Fail 'The Android SDK tools could not be set up. Delete the aaps-tools folder and try again.' }

# ---- 6c. Accept every licence up front so nothing ever stops to ask
$licDir = Join-Path $SdkDir 'licenses'
New-Item -ItemType Directory -Path $licDir -Force | Out-Null
$licenses = @{
    'android-sdk-license'           = @('24333f8a63b6825ea9c5514f83c2829b004d1fee','8933bad161af4178b1185d1a37fbf41ea5269c55','d56f5187479451eabf01fb78af6dfcb131a6481e')
    'android-sdk-preview-license'   = @('84831b9409646a918e30573bab4c9c91346d8abd')
    'android-sdk-arm-dbt-license'   = @('859f317696f67ef3d7f30a50a5560e7834b43903')
    'google-gdk-license'            = @('33b6a2b64607f11b759f320ef9dff4ae5c47d97a')
    'mips-android-sysimage-license' = @('e9acab5b5fbb560a72cfaecce8946896ff6aab9d')
    'intel-android-extra-license'   = @('d975f751698a77b662f1254ddbeed3901e976f5a')
}
foreach ($name in $licenses.Keys) {
    Set-Content -Path (Join-Path $licDir $name) -Value ("`n" + ($licenses[$name] -join "`n")) -NoNewline -Encoding ASCII
}

$sdkEnv = @{ JAVA_HOME = $JavaHome; ANDROID_HOME = $SdkDir; ANDROID_SDK_ROOT = $SdkDir }

# ---- 6d. (No '--update' call. It crashes some tool versions outright and the
#          exact packages needed are installed explicitly below anyway.)

# ---- 6e. Look up the exact platform package name and the newest stable
#          build-tools that match the required platform.
# From API 37 on Google publishes "platforms;android-37.0", not "android-37".
Say "    looking up the SDK packages for android-$ReqPlatform ..."
$listingTxt = $null
try {
    $listing = Invoke-Tool -Exe $sdkMgr -WorkDir $SdkDir -EnvVars $sdkEnv -Quiet -Arguments @("--sdk_root=$SdkDir",'--list','--channel=0')
    $listingTxt = ($listing | ForEach-Object { "$_" }) -join "`n"
} catch { Warn 'Could not list SDK packages through sdkmanager.' }

# sdkmanager may have failed for network reasons; Google's index is readable
# over PowerShell's network stack even when Java's is blocked.
$indexPaths = $null
if (-not $listingTxt) {
    try {
        Say '    reading the package index directly instead ...'
        [xml]$idx = (Invoke-WebRequest 'https://dl.google.com/android/repository/repository2-3.xml' -UseBasicParsing -TimeoutSec 120).Content
        $indexPaths = @($idx.'sdk-repository'.remotePackage | ForEach-Object { [string]$_.path })
        # Same "name | ..." shape the platform and build-tools matchers expect.
        $listingTxt = ($indexPaths | ForEach-Object { "  $_ | 1 | index" }) -join "`n"
    } catch { }
}

$PlatformPkg = Resolve-PlatformPackage -Api $ReqPlatform -Listing $listingTxt
Ok "Using $PlatformPkg"

if (-not $ReqBuildTools -and $listingTxt) {
    # (?=[\s|]) skips release candidates such as "37.0.0-rc1".
    # @() is required: a single match is a string, and $cands[0] would be its first character.
    $cands = [regex]::Matches($listingTxt, "build-tools;($ReqPlatform\.\d+\.\d+)(?=[\s|])") |
             ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique |
             Sort-Object { [version]$_ } -Descending
    if ($cands) { $ReqBuildTools = @($cands)[0] }
}
if (-not $ReqBuildTools -and -not $indexPaths) {
    try {
        Say '    reading the package index directly instead ...'
        [xml]$idx = (Invoke-WebRequest 'https://dl.google.com/android/repository/repository2-3.xml' -UseBasicParsing -TimeoutSec 120).Content
        $indexPaths = @($idx.'sdk-repository'.remotePackage | ForEach-Object { [string]$_.path })
    } catch { }
}
if (-not $ReqBuildTools -and $indexPaths) {
    $cands2 = $indexPaths |
              Where-Object { $_ -match "^build-tools;$ReqPlatform\.\d+\.\d+$" } |
              ForEach-Object { $_ -replace '^build-tools;', '' } |
              Sort-Object { [version]$_ } -Descending
    if ($cands2) { $ReqBuildTools = @($cands2)[0] }
}
if (-not $ReqBuildTools) {
    $ReqBuildTools = if ($ReqPlatform -ge 36) { "$ReqPlatform.0.0" } else { $FallbackBuildTool }
    Warn "Guessing build-tools $ReqBuildTools."
}
Ok "Using build-tools $ReqBuildTools"

# ---- 6f. Install exactly what is needed (marker makes reruns instant)
# The marker carries the real package name, so a marker left behind by an older
# run that asked for a name that does not exist (android-37) is not trusted.
$marker = Join-Path $SdkDir (".installed-" + ($PlatformPkg -replace '^platforms;', '') + "-$ReqBuildTools")
# Each installed package records its own name in package.xml - check that rather
# than guessing the folder name.
$platPresent = [bool](Get-ChildItem (Join-Path $SdkDir 'platforms') -Filter 'package.xml' -Recurse -Depth 1 -ErrorAction SilentlyContinue |
               Select-String -SimpleMatch ('path="' + $PlatformPkg + '"') -List -ErrorAction SilentlyContinue)
if (-not (Test-Path $marker) -or -not $platPresent) {
    Say '    installing SDK packages (slow the first time) ...'
    $sdkDone = $false
    try {
        Invoke-Tool -Exe $sdkMgr -WorkDir $SdkDir -EnvVars $sdkEnv -StdIn (,'y' * 40) -Arguments @(
            "--sdk_root=$SdkDir", 'platform-tools',
            (Quote-Pkg $PlatformPkg), (Quote-Pkg "build-tools;$ReqBuildTools")) | Out-Null
        $sdkDone = $true
    } catch {
        $why = "$($_.Exception.Message)"
        # A missing build-tools revision is not a network failure. Install the
        # platform on its own and let Gradle fetch the rest.
        if ($why -match '(?i)Failed to find package' -and $why -match '(?i)build-tools') {
            Warn "build-tools $ReqBuildTools was rejected - installing the platform only and letting Gradle pick the rest."
            try {
                Invoke-Tool -Exe $sdkMgr -WorkDir $SdkDir -EnvVars $sdkEnv -StdIn (,'y' * 40) -Arguments @(
                    "--sdk_root=$SdkDir", 'platform-tools', (Quote-Pkg $PlatformPkg)) | Out-Null
                $sdkDone = $true
            } catch {
                $why = "$($_.Exception.Message)"
            }
        }
        if (-not $sdkDone) {
            if ($why -match '(?i)IO exception|manifest|source lists|Failed to find package|Connection|timed out|SSL|certificate') {
                Warn 'The Android installer could not reach Google.'
                Say  '    This is a network problem, not a problem with your PC:'
                Say  '      - antivirus HTTPS scanning breaks Java downloads (very common)'
                Say  '      - a company/school proxy or a filtering router blocks it'
                Say  '    Downloading the same packages directly instead - this usually works.'
            } else {
                Warn "The Android installer failed ($($why.Split([char]10)[0])). Trying a direct download instead."
            }
            try {
                Install-SdkPackagesDirect -SdkRoot $SdkDir -DownloadDir $DlDir -PlatformPkg $PlatformPkg -BuildTools $ReqBuildTools
                $sdkDone = $true
            } catch {
                Fail ("Could not install the Android SDK.`n" +
                      " Reason: $($_.Exception.Message)`n`n" +
                      " Almost always one of these:`n" +
                      "   1. Antivirus is inspecting HTTPS traffic. Turn that off, or add an`n" +
                      "      exception for dl.google.com, and run again.`n" +
                      "   2. You are on a company or school network that blocks it. Try a`n" +
                      "      home network or a phone hotspot.`n" +
                      "   3. dl.google.com was temporarily unreachable. Simply try again later.")
            }
        }
    }
    if (-not $sdkDone) { Fail 'The Android SDK could not be installed.' }
    Get-ChildItem $SdkDir -Filter '.installed-*' -Force -ErrorAction SilentlyContinue | Remove-Item -Force
    New-Item -ItemType File -Path $marker -Force | Out-Null
}

# apksigner lives in build-tools; take the newest one actually present.
$btRoot = Join-Path $SdkDir 'build-tools'
$apksigner = $null
if (Test-Path $btRoot) {
    $bt = Get-ChildItem $btRoot -Directory | Sort-Object { try { [version]$_.Name } catch { [version]'0.0.0' } } -Descending | Select-Object -First 1
    if ($bt) { $apksigner = Join-Path $bt.FullName 'apksigner.bat' }
}
if (-not $apksigner -or -not (Test-Path $apksigner)) { Fail "apksigner was not found under $btRoot. Delete the aaps-tools folder and run again." }
Ok 'Android SDK ready'

# Point the build at our private SDK copy.
Set-Content -Path (Join-Path $SrcDir 'local.properties') -Value ('sdk.dir=' + $SdkDir.Replace('\','\\')) -Encoding ASCII

# =============================================================== 7. KEYSTORE
Step '7/8  Signing key'

$KeystorePath = $null; $StorePass = $null; $KeyAliasUsed = $KeyAlias
$KeyPass = $null; $aliasFromProps = $null

if (Test-Path $PropsFile) {
    $p = @{}
    Get-Content $PropsFile | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
        $kv = $_ -split '=', 2; $p[$kv[0].Trim()] = $kv[1].Trim()
    }
    if ($p['storeFile']) {
        $cand = if ([IO.Path]::IsPathRooted($p['storeFile'])) { $p['storeFile'] } else { Join-Path $Root $p['storeFile'] }
        if (Test-Path $cand) {
            $KeystorePath = $cand
            $StorePass    = $p['storePassword']
            if ($p['keyAlias'])    { $KeyAliasUsed = $p['keyAlias']; $aliasFromProps = $p['keyAlias'] }
            if ($p['keyPassword']) { $KeyPass = $p['keyPassword'] }
            Ok "Using the key remembered in keystore.properties ($(Split-Path $cand -Leaf))"
        }
    }
}

if (-not $KeystorePath) {
    $found = @(Get-ChildItem -Path $Root -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Extension -in '.jks','.keystore','.p12' })
    if (-not $found) {
        # Someone may have dropped it into the support folder instead - move it out.
        $stray = @(Get-ChildItem -Path $Support -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.Extension -in '.jks','.keystore','.p12' })
        foreach ($f in $stray) {
            try { Move-Item $f.FullName (Join-Path $Root $f.Name) -Force; Say "    moved $($f.Name) out to the main folder" } catch { }
        }
        $found = @(Get-ChildItem -Path $Root -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.Extension -in '.jks','.keystore','.p12' })
    }
    if ($found.Count -ge 1) {
        $KeystorePath = $found[0].FullName
        if ($found.Count -gt 1) { Warn "Several key files found - using $($found[0].Name)" }
        Write-Host ''
        Write-Host "    Found your existing signing key: $(Split-Path $KeystorePath -Leaf)" -ForegroundColor White
        Write-Host '    Type its password (nothing appears on screen while you type).' -ForegroundColor White
        $sec = Read-Host '    Password' -AsSecureString
        $StorePass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }
}

if (-not $KeystorePath) {
    $KeystorePath = Join-Path $Root $KeystoreName
    Write-Host ''
    Write-Host '    No signing key was found in this folder, so a new one will be created.' -ForegroundColor Yellow
    Write-Host '    ------------------------------------------------------------------' -ForegroundColor Yellow
    Write-Host '     IMPORTANT: keep the file aaps-keystore.jks and this password safe.' -ForegroundColor Yellow
    Write-Host '     Every future AAPS update MUST be signed with the same key, or the' -ForegroundColor Yellow
    Write-Host '     phone will refuse to install it and you would have to uninstall' -ForegroundColor Yellow
    Write-Host '     AAPS and lose your settings.' -ForegroundColor Yellow
    Write-Host '     When the build finishes, copy the key file OUT of this folder' -ForegroundColor Yellow
    Write-Host '     to a USB stick or cloud drive. That copy is your only insurance.' -ForegroundColor Yellow
    Write-Host '    ------------------------------------------------------------------' -ForegroundColor Yellow
    Write-Host ''
    while (-not $StorePass) {
        $s1 = Read-Host '    Choose a password (at least 8 characters)' -AsSecureString
        $s2 = Read-Host '    Type the same password again' -AsSecureString
        $p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s1))
        $p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s2))
        if ($p1 -ne $p2)      { Warn 'The two passwords are not the same. Try again.'; continue }
        if ($p1.Length -lt 8) { Warn 'Too short - please use at least 8 characters.'; continue }
        if ($p1 -match '"')   { Warn 'Please avoid the " character.'; continue }
        $StorePass = $p1
    }
    Say '    creating the key ...'
    $mkPath = if ($RootIsAscii) { $KeystorePath } else { Join-Path $SignStage 'new-keystore.jks' }
    if (Test-Path $mkPath) { Remove-Item $mkPath -Force -ErrorAction SilentlyContinue }
    Invoke-Tool -Exe $keytool -WorkDir $SignStage -EnvVars @{ JAVA_HOME = $JavaHome } -Quiet -Arguments @(
        '-J-Duser.language=en','-J-Duser.country=US',
        '-genkeypair','-v','-keystore',$mkPath,'-alias',$KeyAliasUsed,
        '-keyalg','RSA','-keysize','4096','-validity','20000',
        '-storepass',$StorePass,'-keypass',$StorePass,
        '-dname','CN=AAPS User, OU=AAPS, O=AAPS, L=Unknown, ST=Unknown, C=IL'
    ) | Out-Null
    if ($mkPath -ne $KeystorePath) { Move-Item $mkPath $KeystorePath -Force }
    Ok "New key created: $KeystoreName"
}

# Force English output - keytool follows the Windows display language, and on a
# Hebrew Windows the field names come back in Hebrew and nothing below matches.
$ktEn = @('-J-Duser.language=en','-J-Duser.country=US')

# Hand Java a copy on a plain-English path when the real one is not.
$KsForJava = $KeystorePath
if (-not $RootIsAscii) {
    $KsForJava = Join-Path $SignStage 'signing-key.jks'
    Copy-Item $KeystorePath $KsForJava -Force
}

try {
    $listing = Invoke-Tool -Exe $keytool -WorkDir $SignStage -EnvVars @{ JAVA_HOME = $JavaHome } -Quiet -Arguments (
        $ktEn + @('-list','-v','-keystore',$KsForJava,'-storepass',$StorePass))
} catch {
    if (Test-Path $PropsFile) { Remove-Item $PropsFile -Force }
    Fail "That password does not open $(Split-Path $KeystorePath -Leaf).`n Run the script again and type the correct password (the saved one has been cleared)."
}

# ---- Work out which keys live in there -------------------------------------
$text  = ($listing -join "`n")
$keys  = @()
foreach ($mm in [regex]::Matches($text, '(?im)^Alias name:\s*(.+?)\s*$')) {
    $name  = $mm.Groups[1].Value
    $tail  = $text.Substring($mm.Index)
    $created = ''; $owner = ''; $kind = ''
    $d = [regex]::Match($tail, '(?im)^Creation date:\s*(.+?)\s*$'); if ($d.Success) { $created = $d.Groups[1].Value }
    $o = [regex]::Match($tail, '(?im)^Owner:\s*(.+?)\s*$');         if ($o.Success) { $owner   = $o.Groups[1].Value }
    $t = [regex]::Match($tail, '(?im)^Entry type:\s*(.+?)\s*$');    if ($t.Success) { $kind    = $t.Groups[1].Value }
    $cn = ''
    $c = [regex]::Match($owner, 'CN=([^,]+)'); if ($c.Success) { $cn = $c.Groups[1].Value.Trim() }
    $keys += [pscustomobject]@{ Alias = $name; Created = $created; CN = $cn; Kind = $kind }
}
# Only entries holding a private key can sign an APK.
$signable = @($keys | Where-Object { $_.Kind -eq '' -or $_.Kind -match 'PrivateKey' })
if ($signable.Count -eq 0) { $signable = $keys }

if ($signable.Count -eq 0) {
    Fail "$(Split-Path $KeystorePath -Leaf) contains no keys at all. Use a different file, or delete it and let the script make a new one."
}

$chosen = $null
if ($aliasFromProps -and ($signable.Alias -contains $aliasFromProps)) {
    # Remembered from last time - do not pester the user again.
    $chosen = $signable | Where-Object { $_.Alias -eq $aliasFromProps } | Select-Object -First 1
} elseif ($signable.Count -eq 1) {
    $chosen = $signable[0]
    Say "    this file contains one key: '$($chosen.Alias)'"
} else {
    # Several keys in the file - the user has to say which one.
    $default = 1
    for ($i = 0; $i -lt $signable.Count; $i++) {
        if ($signable[$i].Alias -eq $KeyAlias) { $default = $i + 1 }
    }
    Write-Host ''
    Write-Host "    This key file contains $($signable.Count) keys:" -ForegroundColor White
    Write-Host ''
    for ($i = 0; $i -lt $signable.Count; $i++) {
        $k = $signable[$i]
        $extra = @()
        if ($k.CN)      { $extra += $k.CN }
        if ($k.Created) { $extra += $k.Created }
        $suffix = if ($extra.Count) { '   (' + ($extra -join ', ') + ')' } else { '' }
        $mark   = if (($i + 1) -eq $default) { '<- default' } else { '' }
        Write-Host ("      {0}  -  {1}{2}  {3}" -f ($i + 1), $k.Alias, $suffix, $mark) -ForegroundColor White
    }
    Write-Host ''
    Write-Host '    Pick the SAME key you used for previous builds, or the phone' -ForegroundColor Yellow
    Write-Host '    will refuse to install the update over your existing AAPS.' -ForegroundColor Yellow
    Write-Host ''
    while (-not $chosen) {
        $pick = Read-Host "    Which key? Type 1-$($signable.Count) and press Enter (just press Enter for $default)"
        if ([string]::IsNullOrWhiteSpace($pick)) { $pick = "$default" }
        $n = 0
        if ([int]::TryParse($pick.Trim(), [ref]$n) -and $n -ge 1 -and $n -le $signable.Count) {
            $chosen = $signable[$n - 1]
        } else {
            Warn "Please type a number between 1 and $($signable.Count)."
        }
    }
}
$KeyAliasUsed = $chosen.Alias
Ok "Using key '$KeyAliasUsed'"

# ---- That key may have its own password, different from the file's ---------
if (-not $KeyPass) { $KeyPass = $StorePass }
if (-not (Test-KeyPassword -Keytool $keytool -JavaHome $JavaHome -Keystore $KsForJava `
                           -StorePass $StorePass -Alias $KeyAliasUsed -KeyPass $KeyPass -EnglishArgs $ktEn -StageDir $SignStage)) {
    Write-Host ''
    Write-Host "    The key '$KeyAliasUsed' has its own password, different from the" -ForegroundColor White
    Write-Host '    password of the file itself.' -ForegroundColor White
    Write-Host '    (Nothing appears on screen while you type.)' -ForegroundColor White
    $KeyPass = $null
    for ($try = 1; $try -le 3 -and -not $KeyPass; $try++) {
        $sk = Read-Host "    Password for the key '$KeyAliasUsed'" -AsSecureString
        $cand = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sk))
        if (Test-KeyPassword -Keytool $keytool -JavaHome $JavaHome -Keystore $KsForJava `
                             -StorePass $StorePass -Alias $KeyAliasUsed -KeyPass $cand -EnglishArgs $ktEn -StageDir $SignStage) {
            $KeyPass = $cand
        } else {
            Warn "That is not the password for '$KeyAliasUsed'."
        }
    }
    if (-not $KeyPass) {
        if (Test-Path $PropsFile) { Remove-Item $PropsFile -Force }
        Fail "Could not unlock the key '$KeyAliasUsed'. Run the script again and try a different password."
    }
}
Ok 'Signing key ready'

@"
# Saved by Build-AAPS so you are not asked again.
# Anyone who has this file AND your .jks file can sign apps as you.
storeFile=$(Split-Path $KeystorePath -Leaf)
storePassword=$StorePass
keyAlias=$KeyAliasUsed
keyPassword=$KeyPass
"@ | Set-Content -Path $PropsFile -Encoding ASCII

# =============================================================== 8. BUILD
Step '8/8  Building the APK - this is the long part'
Say '    You will see a lot of technical text. That is normal. Leave it running.'

$gradlew = Join-Path $SrcDir 'gradlew.bat'
if (-not (Test-Path $gradlew)) { Fail 'gradlew.bat is missing from the source code. Delete the AndroidAPS folder and run again.' }

$gradleHome = Join-Path $ToolsDir 'gradle-home'
New-Item -ItemType Directory -Path $gradleHome -Force | Out-Null

$buildEnv = @{
    JAVA_HOME           = $JavaHome
    ANDROID_HOME        = $SdkDir
    ANDROID_SDK_ROOT    = $SdkDir
    GRADLE_USER_HOME    = $gradleHome
    GIT_TERMINAL_PROMPT = '0'
    PATH                = "$(Join-Path $JdkDir 'bin');$(Join-Path $GitDir 'cmd');$env:PATH"
}

# ---- CPU and memory tuning -------------------------------------------------
# AAPS ships gradle.properties with a HARD-CODED "org.gradle.workers.max=12".
# On a machine with more than 12 logical cores that leaves cores idle; on a
# small machine it over-subscribes. It also asks for 8 GB of heap, which on a
# small PC guarantees an out-of-memory crash. Settings written into
# GRADLE_USER_HOME outrank the project's own file, so we correct both here.
$cores = [Environment]::ProcessorCount
try {
    $phys = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
    if ($phys -gt 0) { $physCores = [int]$phys } else { $physCores = $cores }
} catch { $physCores = $cores }

if ($ramGb -lt 12) {
    # Memory is the binding constraint, not the CPU. Keep it modest or it dies.
    $heap    = if ($ramGb -le 6) { '2g' } elseif ($ramGb -le 8) { '3g' } else { '4g' }
    $workers = [math]::Max(1, [math]::Min($cores, 2))
    $kotlinHeap = '1g'
    Warn "Only $ramGb GB of RAM - limiting the build to $heap heap and $workers worker(s). Slower, but it will finish."
} else {
    # Plenty of memory: use every logical core the machine has.
    # Hyper-threaded "cores" do not help a compile that is already memory-bound,
    # and over-subscribing a small machine makes it thrash. Below 24 GB, scale to
    # PHYSICAL cores; above it, use everything.
    $heap    = if ($ramGb -ge 24) { '8g' } else { '5g' }
    $workers = if ($ramGb -ge 24) { $cores } else { [math]::Max(2, [math]::Min($physCores, 8)) }
    $kotlinHeap = if ($ramGb -ge 24) { '4g' } elseif ($ramGb -ge 16) { '2g' } else { '2g' }
    Ok "Using $workers parallel workers ($cores logical / $physCores physical cores, $ramGb GB RAM)"
    if ($workers -gt 12) { Say "    that is $($workers - 12) more than the AAPS default cap of 12" }
}

@"
# Written by Build-AAPS. Overrides the project's own gradle.properties.
org.gradle.jvmargs=-Xmx$heap -XX:+UseParallelGC -Xss1024m -Dfile.encoding=UTF-8
org.gradle.parallel=$( if ($workers -gt 1) { 'true' } else { 'false' } )
org.gradle.workers.max=$workers
org.gradle.caching=true
org.gradle.daemon=false
kotlin.daemon.jvm.options=-Xmx$kotlinHeap
kotlin.incremental=true
kotlin.parallel.tasks.in.project=true
"@ | Set-Content (Join-Path $gradleHome 'gradle.properties') -Encoding ASCII

$tasks = @()
if ($BuildPhone) { $tasks += ':app:assembleFullRelease'  }
if ($BuildWear)  { $tasks += ':wear:assembleFullRelease' }

$rawLog   = Join-Path $Support 'build-log-gradle.txt'
$baseline = Join-Path $ToolsDir 'gradle-task-count.txt'
Say '    Full Gradle output goes to the AAPS-Builder-Files folder, build-log-gradle.txt'
if (-not (Test-Path $baseline)) {
    Say '    (no percentage on the first build - there is nothing to compare against yet)'
}
Write-Host ''

$gradleArgs = @('--no-daemon','--console=plain','--stacktrace',"--max-workers=$workers") + $tasks
$started = Get-Date
try {
    Invoke-GradleWithProgress -Gradlew $gradlew -Arguments $gradleArgs -WorkDir $SrcDir `
        -EnvVars $buildEnv -RawLog $rawLog -BaselineFile $baseline | Out-Null
} catch {
    Warn 'The build failed. Retrying once from clean - this fixes most one-off failures.'
    try { Invoke-Tool -Exe $gradlew -WorkDir $SrcDir -EnvVars $buildEnv -Quiet -Arguments @('--no-daemon','--stop') | Out-Null } catch {}
    Invoke-GradleWithProgress -Gradlew $gradlew -Arguments (@('--no-daemon','--console=plain','--stacktrace',"--max-workers=$workers",'clean') + $tasks) `
        -WorkDir $SrcDir -EnvVars $buildEnv -RawLog $rawLog -BaselineFile $baseline | Out-Null
}
Ok "Compiled in $([math]::Round(((Get-Date) - $started).TotalMinutes,1)) minutes"

# ------------------------------------------------------------------ sign them
$stamp   = Get-Date -Format 'yyyy-MM-dd'
$results = @()

function Sign-Apk {
    param([string]$Unsigned, [string]$OutName, [string]$Label)
    if (-not (Test-Path $Unsigned)) { Fail "$Label was not produced by the build (expected $Unsigned). See build-log.txt." }
    $outPath  = Join-Path $Root $OutName
    $signPath = if ($RootIsAscii) { $outPath } else { Join-Path $SignStage $OutName }
    if (Test-Path $outPath)  { Remove-Item $outPath  -Force }
    if (Test-Path $signPath) { Remove-Item $signPath -Force }
    Say "    signing $Label ..."
    $sEnv = @{ JAVA_HOME = $JavaHome; ANDROID_HOME = $SdkDir }
    try {
        Invoke-Tool -Exe $apksigner -WorkDir $SignStage -EnvVars $sEnv -Quiet -Arguments @(
            'sign','--ks',$KsForJava,'--ks-key-alias',$KeyAliasUsed,
            '--ks-pass',"pass:$StorePass",'--key-pass',"pass:$KeyPass",
            '--v4-signing-enabled','false',
            '--out',$signPath,$Unsigned) | Out-Null
    } catch {
        $detail = "$($_.Exception.Message)"
        Write-Host ''
        Write-Host '    Signing failed. What apksigner said:' -ForegroundColor Yellow
        Write-Host "    $detail" -ForegroundColor Yellow
        Write-Host ''
        if ($detail -match '(?i)recover key|wrong password|keystore password was incorrect|Cannot recover') {
            Fail ("The key '$KeyAliasUsed' has its own password, separate from the password of`n" +
                  " $(Split-Path $KeystorePath -Leaf) itself, and the one on file is wrong.`n`n" +
                  " Delete keystore.properties (next to Build-AAPS.bat) and run again -`n" +
                  " it will ask you for both passwords. The APK is already built, so this`n" +
                  " second run takes about a minute, not the full build.")
        }
        if ($detail -match '(?i)No key with alias|alias .* does not') {
            Fail ("The key '$KeyAliasUsed' is not in $(Split-Path $KeystorePath -Leaf).`n" +
                  " Delete keystore.properties (next to Build-AAPS.bat) and run again to pick a key from the list.")
        }
        Fail ("Could not sign the APK. The message above is the reason.`n" +
              " The compiled app is fine - only the signing step failed, so a re-run is quick.")
    }
    # apksigner's v4 scheme drops a companion ".idsig" file next to the APK. It is
    # only used by "adb install --incremental" and is meaningless for sideloading,
    # so v4 is switched off above and any leftover is removed here.
    if (Test-Path "$signPath.idsig") { Remove-Item "$signPath.idsig" -Force -ErrorAction SilentlyContinue }

    Invoke-Tool -Exe $apksigner -WorkDir $SignStage -EnvVars $sEnv -Quiet -Arguments @('verify','--verbose',$signPath) | Out-Null
    if ($signPath -ne $outPath) { Move-Item $signPath $outPath -Force }
    Ok "$Label signed and verified -> $OutName"
    return $outPath
}

if ($BuildPhone) {
    $results += Sign-Apk -Unsigned (Join-Path $SrcDir 'app\build\outputs\apk\full\release\app-full-release-unsigned.apk') `
                         -OutName  "AAPS-phone-$AppVersion-$stamp.apk" -Label 'Phone app'
}
if ($BuildWear) {
    $results += Sign-Apk -Unsigned (Join-Path $SrcDir 'wear\build\outputs\apk\full\release\wear-full-release-unsigned.apk') `
                         -OutName  "AAPS-watch-$AppVersion-$stamp.apk" -Label 'Watch app'
}

# =============================================================== DONE
Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host '  DONE - your APK is ready' -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
foreach ($r in $results) {
    Write-Host ("   " + (Split-Path $r -Leaf) + "   (" + [math]::Round((Get-Item $r).Length/1MB,1) + " MB)") -ForegroundColor White
}
Write-Host ''
Write-Host "   Folder : $Root" -ForegroundColor Gray
if ($WorkRoot -ne $Support) { Write-Host "   Built in: $WorkRoot  (safe to delete)" -ForegroundColor Gray }
Write-Host "   Version: AAPS $AppVersion (commit $commit)" -ForegroundColor Gray
Write-Host "   Built with: Java $ReqJdk, android-$ReqPlatform, build-tools $ReqBuildTools, Gradle $GradleVer" -ForegroundColor Gray
Write-Host "   CPU: $workers parallel workers on $cores logical cores" -ForegroundColor Gray
Write-Host "   Signed with key: $KeyAliasUsed  (from $(Split-Path $KeystorePath -Leaf))" -ForegroundColor Gray
Write-Host ''
Write-Host '   Copy the APK to your phone and open it there to install.' -ForegroundColor White
Write-Host '   BACK UP THESE TWO FILES, OUTSIDE THIS FOLDER:' -ForegroundColor Yellow
Write-Host '       aaps-keystore.jks' -ForegroundColor Yellow
Write-Host '       keystore.properties' -ForegroundColor Yellow
Write-Host '   Copy them to a USB stick or cloud drive. A copy that lives only' -ForegroundColor Yellow
Write-Host '   in this folder is NOT a backup - delete the folder or lose the PC' -ForegroundColor Yellow
Write-Host '   and the key is gone for good. Every future update must be signed' -ForegroundColor Yellow
Write-Host '   with that same key, or the phone will refuse to install it.' -ForegroundColor Yellow
Write-Host '================================================================' -ForegroundColor Green

try { if ($results.Count -gt 0) { Start-Process explorer.exe "/select,`"$($results[0])`"" } } catch {}
try { Stop-Transcript | Out-Null } catch {}
exit 0
