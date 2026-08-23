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
echo      1. The instructions - please read them.
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
UEsDBBQAAAAIAOqBF11eCHJmyQMAAJAJAAAOAAAAQnVpbGQtQUFQUy5iYXStVm2PGjcQ/r6/YrQq
p5zE7kGkNBESUQghCW16hxaqthFffF4va52xLdt7C1HV356xzdsdUSPlwgfYF88zz8w8M8MbRmsF
qqqSYvIHDJ/wCQAwGs3m8GwkS6N4ideXoCTLqOD0Dm4bLkpm4sHfGuugVM2t2L92NbdQccFymNwz
s8V7uQImLAN8QRqn1sRxmkf7kyPBUDJWWhD8nlngEp+xwCV7G51m7xEY4ZW/yZ8erONORA+w85AE
0HnLHa2De6qkVXjIKfhz8T57lSe0php+fdHr9eG1bAQ8f33RTxLLnFCUCH8B6cdJMRl2/it1L42I
WZbBh4aYcgCaKY2AqnJMPsyddYbwVe0wdMtLBgQ+T2egDbvnrIWWy1K1Meq/wrWFRmpC76xnR8Aw
UmZKii04tta7LHVDFKFo/kpCRbjwyQ04GF3VWJ/+lmxtDmPi4+YOiCzBki1YBVoQjqB5EkTW8aF1
4F+ssSyRMFxxuKKDdDnS+h1xZPnJZ2G5QAbLNCbo4gJWChkOuPzC9XdggmFBzC8pwI+av/zijb9t
Hq+lcvE2OUHdRfg0SUUI+Ec1QAwD00h5UHdl1Bqm1/Ppu0moiq9uaJUH7mFREweUSCQJrTJ3kB3q
Haobi85KLLkvtDLEbLGSevsIZywUdl3wvNMOQqMCiumHj4ts/Gk6/v0Bje7eEL+9ZTrZoCCpg5EQ
eZ6n3aAKjCg2S+b7Jr9FriEuRNrbR+XhE3xHtGbE2J+W2zzRpLHoaoMqvboFbL1jNUPvzeb9YdTH
+ehYnjDXto/NySvweUY4nGRpB407KTxLAKKz+PtE3nsQmBTFTTH4/7Hmx+SaW9+U+RmNx5lf+/lr
MRPXk78XsLhBSexQsAkFK4+G5/66OGfvoj4G547OfD149Y3MnkNMK9hiGzS+NBrlGsSLiySKLT4P
uWhrP2G9DMkKZ81PzboHi4oBOGrmMk7lmWEV5mqmWmbmNRMCXgIKAieuZdJ1QSE703LshX0Dnhx9
kfeTFt8z0K2tc7ZhJ/sAUTrMGGUEu2eiMxz2gqgOJ7NrNTPKJwKyyYbRxnElZwrXwBbebjWxFkJe
95JMLuMODSCeg/UcfhAqiY1SjIenHNNdfyH1tFOMO+lwmD4/9kKcaSUvQ78QSpl2oXoltxRXxBo3
MlyruMxbYsPOcfme+K7PDsi9U+TFYUVZargO7ehQMbiGa5xsuAq92VEXN5p9589BXGAMvwJuJtQq
d5ujiHEJoOow7tBvmEvtaaNckXByDBenMNDHYxQDaQ9jSJZx7e+15YkmXwFQSwMEFAAAAAgA6oEX
XYoUTOGiEAAArDEAAAsAAABSRUFETUUuaHRtbLVbbXPbuBH+7l+BKNNecyPKkvxyjuw4I8fy1W3P
yZzdy3TmvkAkJOFEEjwCtKym/e/dXQB8kSjLuUx9l1giiQWw++yzL2AuXl1//PDwr08TtjBJfHlw
gb9YzNP5u45IOyyS+btObPIO3hI8gl+JMJyFC55rYd51CjMLzjr+csoT8a7zKMUqU7npsFClRqTw
2EpGZvEuEo8yFAF96TKZSiN5HOiQx+LdAIUYaWJx+Ve1YkaxaSHjiI3Hn+5ZwLRMsljAGG3yIjRS
pfri0D5+cKHNGn8zNsqVMl/gA2NBMJ2PXt9c3RxNjs+Z+zn8noW54AkIjIXWbB7zXDCz4ClbLaQR
7PtDNzjkeQTDb0DA8Nxdk+ly9Hp4hf+dVwJTZVhWgJhpzMNlJWEaF2L0enBz8uHsykuY50KkcHFy
enV84i/mAmZ6ezUcDk/9JZ5MRT56fTY+Gff7ePG/8Of7L1P1FGj5b5nOR1OVRyIP4Aremqpobbc9
hTXMc1Wk0eiR539BLbyxUkMVq9xdhJ24qzOwUDDjiYzXo84vIo94yjvdzgNfqAQ/3Iu5Euyft52u
5qkOtMjlrDYSViNGw0H2ZK/FMhXBQsj5woyGvb67KIyBpeqMh7jyfq9/JBJ7awW7qN0YDP2NhOdz
mY6chIxHET4xPM6e2OAU/jrr2ylx871VzrMvCX+ywBqd0k0vgfHCKHxsMfiyse4jEHdeX/Kgd3Je
VxOa8E1zQazPzmBUqX5jVDI6gRVpFcuI1ce5VfuHBsfVkhfDzbUMf/jqtRyjNvqsLhfVUK5zAAsl
/cTguF9qUx2564jxHajBW2/cLkfDcnuvJ/3rk6sPfvs5j2Shy53VDAUWYMNh3Qx9NqzZrIjLlZZ6
kintXxueA3pO7SJj6R6sq5FWr43I/j+rR8XVV19OjZaPpM5ivh7NYvF0PueZvcpjOU8DYJBE0x27
ixKhaZE4g8M9Ugai8tzi9QRnclanz831nfT/dL7DtQkSFiSvZ7PZec3GoD77dWUFT1UcWTGNDdTX
HQJTi/z8t0IbOVsHjrv95QY2y42hEVjPPJkvtLMBG5T+1pvJWGwZ6PXkZvLD9XHdOBHXCwHWuXo7
fns22Nj92Ra0kAL6fneeuT6oIpciZ3di1ekmKlVIKqKukL4XBCFNUAAZQVwrzenAN41VuDynWEC8
JEapQnqpuIbn6Zf6fiBEHF2f+v0cbTABEfmbciQ6ft2p7W0PM6OyUd+pVWXNWa4mx5PjXbNABHlT
jtucA29uzzBXKmrMMDmFSDneNQMFrjflyM057O3tWaZyXiee4xZQEh3mX9y8qUqFRwCKOdpy3gb5
0SS/F1KY2jTkkM4rTsYnR8dn/z24OHQ5wsWhS2MwZMKvSD6yMOZaQ44CdoYkBBKdwXYKcjHNL+/b
chB4GIZkXghyLQh5WEjILgoZCSaeAGAwhi2szIQvBYOEgxIb9BGIAjlbA4BZtoDt92CN2eW2yH+p
gkWK0o1UgL+AqCWAE0StzQI8g/GpKgyE+SQrwGH1c3JUGq/Zgj8KlBLGMlx2QU7EVlwaNw7UkNPf
w8vPC25wgXbeqYD1CvpOJAcqGOKDNU0i/2I6V8SYlF3E8nLMPn1gK2kW7ALcKvUPAj46l59lGqmV
Bq8GK8HNSwb6eOaxgXvs4hAEO/k3AEBktiWzXtsy/qjPfrxqGTpOwaKgsFSg8tLUkkP9iQeZgESr
3m258HUBxvNrNwswqMy1YQaGWTEXh6iJi0NQUQMshFxQ1J2yFkT9asKdRRmPY1A4SeuxBxCc5Wqe
Q/oKikhjxeFh8ShyZ39pnIDpGj5rEc+2TYlCkLN1i9Xweof2XLsIkatzOXBLb94C1qfHGS0Nkawt
pngMOXa0hl2IlBUpGGQJ2wAlK8YB7DE4Nwvt3hrqRBGdS/I2q8weSUfXow+3BsoAo2GXTwa1ZNy0
hEVCsYiqIeUwBHwIsyTqkXJ949ewWogc9cd0gWJBihu9ZeNrFRYJxEHtrQzeDVuBiMHAuUOxsdCG
AGfkO8XGUQI1D5AHN4DwHClQk8lg2bi5UGWgQpWi9RhYGI0LX2Z2o3bNMDEgA3nlYyquc/korOf6
R4lHCkjTqRbDTzCFSoNJOo+lXrhkXPfcRtCk1rYlOl+EiOEeRFwrMopHAsGixdacZzpYijXErVz0
fluW+p3lKgENZ2AfqQptifh9U8vlHFrtnKCUDZ6TidxI4ad4zz6obG3xAKwLeFIt2NmGAvgqcjoP
DVAoIQjNs2ZzNap0WlvlFfi2c44EMitEcItUB+mGhO3dXKEWAnSQ3pSb1una+Clidx8fSuRa9FSQ
2jUZThPQjBCLb3ADmxM+i/dbwiJGLAhHOF3ipwZ6SsALIAx2aRme1CCyyRDUhAtGX9V2FCYpDKnX
hcne/n03l0DYSCFagpXA2EA8XWt28CXAxEyQKdGZe2wM/rgiPKxkHCMPY7/AgIN+o8Mc7XWYYhqL
gFisJLbRM3v8Y4hwmhm7ZsWKYioD14D8hMIzZzEkGAo4BxCJQcfqKVV5wuNvVcLxHiWMWxe0DelY
zHmM4R4uQpDN28PFz0A9GBRdpBBpW3B48PreniVciHA5VU9VZAddaL7WzWk6txZhyHSEXUingWEN
pskoGPIGT9K3jIehyADKBYArFzqDFFJOZSzNutfZXtxHTNNARgpuZN2hZZm3bIzpt1/ltIBaNYW6
GaILK7Ie+0CQwrxuLywwjgNdQfBwUsDysD0gWmA9O02HBajTMFYYWWrZB+6PWBrBQpde7qiULTvT
8ywTPKcwSNJZXqQVDiMRSyiZwCO/FYsnL8hpPDNxvaT0gIjh90JoKh9fEi18rsre2eQet7ePsIfV
GA3VjllxEy5eMvCoGjgFE2yv71OOTU+EEagA1Ni14NqWNMGEuN2r2uz3k4LAlgmF1VG4UAANNvhW
+5zuJUyhbbaDvE5p4ALiWctmNOII+AJzAR/8m3saO31AQgpJkvEY7G0pjIgRvoEopzvS1IsSh9sE
e+I8NT5PYJnnnvvxTxPaBmIMUjZYBncFRJekQeSjSLkoI1MuZvAgcpsrFOiBIovQNV4coQ3lL1Lb
ghCF084orYIbgHtYy1e7MwkGf8UdLbgu01ktMo6uyzJ4Glu/diYfae1sGOWJtNW3IuiHPQjaTg82
d07ahcTatEYhv4t2P3lYZwIz2HKrBBeDV2F7fM5l+qKqwbFrxYo6xGYLnle4ygdlPhOpn6WMzzme
ehC23EJxioxDXkSMvhQiw9jxjaY422OKOyD+7cVhN6JduT8qWh0kl1olwqpIxFr0XCnqy2+GWaZ2
pbsr1F+g9WvbZqEgR8qpZ0vfqou3e3TxGXECEJlhrbhwYd8FR8w+2srTj3eTKr9n1I2zxIFaKmtu
m1XphVqhvojVINlF6uy1bMb2DDa6Ogy7mHQYiG0hV/xslDe2tXCRXWK9DhoHUo6VWgK1LvFxqUeu
MZVjL2Idi3edZk8WU8+AOtOjWMxMo9P7Xa3T+11rp3fwdusk5ex8o2OLh3rbxwOtDWjqNZcnA3j2
RP1FyOnyWaxWwdOIWvmgE8zCfz1g/4H/g4A1M3NW/vw5Nudwu2xZkEbskIfJ/UNwc/vz/QMOsdd+
noyvf5r08Fi2FH0xbSucp5fNGeCpv05+nrzCO+W41nrYjdw5jipBij1BD354tqSl/OpvNYrEX+uy
YmH7QTAUW1G5qPcjCboHVB/7EK6pPPb9naYKy34mHvi2VOUbBe7XVLQgGulgj1jiGpcfW4/aarH6
ht52uopH2LZfoQU5TWJLglwkgjIL7Ppxmw8kmLdvinbaAh5zTWAtjHHNY/TBsOxmxBJrZ3LO4MBd
Bpm4etuvQKaEcsiA00HUhwC9EnHsJ2zhMnJ8bPs7x7+xzBT1GHWGU7V6X/r8wUPVq8LuNOZktlcG
a8WWFGxZFfMFTFzxQWnZXUaz4DvqHfeGvdNg2B+eBv2zYPADYrFs6Tpw/FS1+XBOo5q9dTT01Zr9
8/6KhRxK7i72I0TCoQizPVQ3APunXUy8HiWHeKPmIIv6bTUcfkyrtAwCPM+qliTaNlQphKKELros
jSPJ7VN1jWN/wQpI+syxx1xk0kuZkepKvY9nRlggUBHW3d1jYq09A5cK0usQK2WdcdTucM+37lpc
aV8rrhXq1J3DMsbl3FsADrAp5HpZ4GoWc69cw7uVJD4v1rUxHqbvGwu/EiHHxFq69pWIhUuQ7HmN
RTZocYYnDkVmzxu6B84LP31gEWyMgIPjc0H9YX8vOHDVA5LDHPPt7VXi6cpjrfqiZT34RB0S1RVf
4wIgYmIQwuyMynMkAp6uqxMk1AJpEUBNenvPHhR2wICVMT8CM1vVauEsXT+vQQeBOjdc1k9C6n7A
DuG3yqhBUj0xQU/acKPmaYslUH9MhetZqOZBSQuhjrf4jSqWWjOzbh5l/VJjBxy0TmrDHB4Jtkat
OzDSBMQdeQ3mklScUYFFk3VrJRm1irTrKhLzl/ODsWsT3pb1Iz4E+aWpi6FKCJcKoKPp2mo7WhWe
aawotfKneEXqHyZNIP9Q+opXiAAxXgDF2f4qeAz44npnABvb7NrGmTSyKHEhGo9xLM6A/xUdoFiW
Jy/FkxYNqRuWLBqDCx2rNAmvPI7CY9ZI1TWbenW/33GuWLJjky6u7KlkeRiKFNG1drEsYteO/AaR
nJzyj9EbaO9r2Q0NRsnxtM3fm63/Fzd5d5rOQmxNW0X7EbFDssHuJp898FxTGziUW+O2tRbqmHsu
XnWsEifuTMQjv9fsaX/1vmAnpnbQ6csVgJuGGIrURUAvDzu7B84LyyvIekQ2MI5IW8UWAfbMrXtA
3Vpd7yNtHp1uoIyOT4F3UWlICRKrnhDABYQK6WAbyjfhi69ouOB+X9aukaQ2C74Pt/S5VEXG/8Dq
iZMlbWMIqxs8B2yrTWvH1lUm9jXJML20SS8stIyi5CKI1Rzf+fEWY/dIEZbzV44RJGagcYabs2c2
1bqoMLUtw1wBQBJrFCjCHqkBV2aFjTr9Y7bZqdyzj25zvIvku1ydwOE1gLhomyqNciWj6nzaxx9p
NiajzL5IG52exqsATVjdkcrcCreY59UzHO1exqChtgtv+a9rXzPR+F4qt7Gzal0y8QT0rw+aCVW3
LZ/aydyfXYXjQFimUjvfBckuMWa5fgDWQModbrRkHy/lCuAvnNz6UFlR17HWIqlWUdfF4GEgn4s9
g3d7TVD2WXqtLxBYLlbIFlU/rYmJzSTeRV3qR0ZAWFt6Qg8ff/o7xbY9C9950h6U5LdHwu4I52VU
DdE2pHvYTqozI5fHkw3R/2wupEFWiAVt5A6IgW40HjsBpUjQQ+rdbtsYWGNLY0/LqIMHFRjGsudy
kDGbQVhJVO6A1PZqTMsLTZYL2L0pIqlwbS2Rveoe1N7ywGyU/B0b/Q1ibH0/BK3/EtF1Qb5rbF8W
ca8R0fs37iWqHqtZAR5Y6yqVrny/LvIzlJ9EZ5AgYOHynv0NM5pafeTB/5d7ykgd1VAv9tWb1veg
2lhii+QwxtPbNhrgJxKbY2NfBRMBXHURI7/a4g2x4HubVIb7ow3yKTGXaYonGVUOTWkZndziE2o2
k6HEo2X3vg+V666Wx3f/3FY/Tn/DdiWWIY6AQUSMBh3Vy9/qH09wixbwwR5OBjJgBt2TqlkBe8X4
Tqx7R/HQ/tuM/wFQSwMEFAAAAAgA6oEXXRzkMm9MAQAAxQIAAA4AAABURVNULUZJUlNULmJhdKWR
MU/DMBCFd/+Kp0pBVCIhQYIBKRUtKhsQ2o4sjnNprBo7ih2SLvx2nAQVNoZ6ONnWu8/vnh9IVAam
LNlm/Yz0jDUC8NZKcYCoyFdXceeLtMgeIbhG3kpVYLnMttGk3vEDWfDctA4cH1K3jiKsBpmFNr5X
769QmE4rw3+vkMt9dL5hJ52i0c70JDUIYUmVcGQdE5WocXcbxwkWulW4WVwkzJJTRnA1bDDLtkka
fBV1PEDCH0j4JBXZ9/EUjsPWNpkxWQ72Qb20vjPwrcEMlwwYfwDrzeZ1c49/QSOkNK0uoKn3+Zop
4tJrI0+reWtpoPbS4TpHwuasq6gh1J2tIurpzzTeU0BNYxpFn6SCNI1HRydl+GKyxgxohOueROuk
0ZlRUhyxOtbcWowmT/OEWx/fbkhvDlKWJpzpqLEVKXU2lA1hRWwaknQx/cU3UEsDBBQAAAAIAOqB
F10AAPYSRFwAAPIwAQAhAAAAQUFQUy1CdWlsZGVyLUZpbGVzL0J1aWxkLUFBUFMucHMx3b3pfttI
si/4XU+Rw+JpkGUC1uZNPuoqWZJtddmWjiiXu6/tdoEkKKFEEmwA1NJl3xe7H+aR5hUm/hGZiQQI
UpLtU3Pv8NftEsFE5BYZW8by//yv//s/f1jZ/s6fFbWzc9RVrZ3JIE3iAf3dVskk8vujuH+uerN4
NIhSNUxS9S6eDJLL7L9hBO/OwlzFuRokUdZRl3F+plrhaJxkeVtNEhVPprNcDdNkrK6T2daKUmot
ULtnUf88w5NUHe2qszBT0SSZnZ6pQZydq2wa9qMAbdcDtZdcTkZJOMhUqKZpfBHmkeon02uVDNUL
6jie5IlqhOE08/MkGWUNfnHDfTE/i9SI3styWbCM+u0DyiBSrXGY5bRKvTSc9M/aMlSC+3LWY0Cb
gTre39nrqpOX+6p7+PZ4d19Rh0NaUJXQ1KKrsJ+PrtXlWdw/U38LL0J1EaVZnEw6+pneHQCjT3fv
FzWlwdCujFVIQKQRb5ZMgIZLSzoN0zzuz0ZhKmPWQNUkigZZRwOjiU1o5fU878+mA8ySlinqx1lE
o8rPkiwK1JskP4snpyrOaK3TgY+ZDzq0DtR7NNHAZtMsT6NwTGMZT7HaafSvWZxG42iSEyB6N+un
8ZR2MxmNCJlUOMuTcUijDEeja16sB4F6TgujdzaLTyfo9Ty6zvIkjWirBA4BIMTsKELMPvWIIRPa
MqLSiwzpYaCeYUkyXiNAkm3cOfqllbXRTIXZeTTAS/zCI9rwNJlKK9qdODujX3XzSXSVY9fcWQBu
Mo00XBlSsLLirlU8yXKaG8HJaAbR2L+MB7yaamcwRhd5GtLEVBqfnuU0Upoitica0Ij0rqtuPhvE
CaC9OTxRs4yAoWd80es7UL4MLJahJMNh3I/Dkdp9dSB4gWEdR346m9C7tKnxWBYrnNCmEdL42Hbd
VL0Kgc7UVgY0nhF2DRnHg+9//H/468rKD8cyj0z5v2okfRCsrawQBofj1vuMaEL/7GOzG42GJ3QE
2ysrzf00TdKdfk5tj9JoGKXRhM7jtvK6eTL1VppHaXJKADPnR/rg93hE2Di63k0meTyZRd7K+zdR
HnSj9CLuR0cJEYPX4SQ8jdKPW1vdqD9L4/yaoOVJPxkRAN26/PzkehpR85NRtrZO01EEPEtGEZEk
OieECh3CYEZ7Qlf6ibadfrkWWocNexn10uhSRYMYEwpW8vRa/cGH6r0GRdAPZzlRwn0NEkM5IaQM
zANq8fbk+WN+q1lpW3wWvfVF9UNaZPWH+oIJ+N/+UVmU0wqfZivNHSKtx9E00SPwzvJ8mm3dv39K
8yci2U/G9yd8APpED+8XvCigBp68/oyJq7wu9JZ++EWThTfhmPeeSbihFcHv55m02RnFxB5036aN
h2nyi0wsw+k0CtNMCAzR+uiUjs8kIdIUgdmEk9MIPCoeMuG4DEHQkoDGNiMCmTIcBn9CLxvywD9x
P29xaJMJkVMCAPgu/+iHE+pI9SI6ziGTI/p5zN8yIEPzOVGQXtg//9vg3O6it77mFb8cGXZAv2w8
LJ4zATxJGHG9jYfBarDK43nOtIo4Gk0m18g5iEZxLyJyBKrfw8En4h4SOUovklkGukPjiuiMCm/G
4oDKba38QACV+k8m2EIE//qBH+HDI/DBf4IeLbPz+U9faNWEmQywlMjrIJn1Rlr8sDDwtj89g1wS
0CecnldgWGJNu0iTAvs4o0NvAczhhTsIHjf9SOxiZ/cXdXCi3h4F9lX71pRYQ0QMNcqKV2Mi2dMw
yy6TdFD/Ohj/6/3gLB+PVPmjh346I4ZQnukzkbr850Spsg9F84gY+LWsVDTKInVGbzLCylwJSPM4
SXLBD8C+iLOYVlNvCgl5R79gr6870msbw2x2Z9Npkub6lfkBWFZ7iW5K/G8UX0BiC0fJ5NROgT+W
sI2SU2qBv4yMQbskMgp4WOUoEK6b4WAOzaNul3vCtFbs5PBTdzqKc/8opG7sK/SVCH2+QkeMeEae
CnU7yN7MRqPD9N1ZnEddiIUthtRuE60TmNsFjC8E/QewPpHiQjUgeZGOIg/gVXKKJeEB/I0YRaV/
TyQwmnKQX+XCg6YZv1Fqb+bh1eCW972I73Q0G/doBVaGswlzSdUNrxVNWXhqc9xW74iDRf5LnOXm
WPnPaSSnaTKbDHaTEdGgFym98MV5P4+mi95v/DYhXk5gGvNwdq9JyHDgHOL0LoLDLO/wl4/1oF6k
UVSC9S5MJ8th/V8fVT2sf0QQQV1gz8N4pLmuBcjfyhP9to2pGclxNJjrRnVPDo+O9ve26gdf+8qO
GhKm48gRf6JDGl7wWSMQGnFvCejbJvjbZEk3LNcoiGj+CTF0TUc+KxJXfBxTZcWQL9w+uiKeu7ZC
IondpRdRzoSptFPmuDffpqOOst8ILJo6T6BryqaCSkCY1IdSN21rsPg0s/jf0eseRCbSUc6Ilhxj
Rq0WhnBAwnzxVvAqmpwSmPtq7fWzjlprWyDoxgDyT2kyIDt0BBo8FKKd4PnXLnW0zV8/azeekhSQ
z1IgvYF4HI2Ti6g8AF7xfsRtpCVOO58AAxlsQ/okFtoQKTEfT2l2DQMlgMbYqFsdaohxl7rGy9Kt
7rI5gApGVGAYEnuyYLBau8l4DHrfzakH/xnxTd5+ksyV70jyqiqcu9thcGceQlc4CDZf+Xs06ngS
MjgZIz1hPOMnvALlPgkbnxaDz9NZ5Ky2kYrvuCAawhe7Cj5EPO5kfk4Hk4vkPPLfRT3oQbAx+G/T
WM/H7LCAJ0HyWZjFfWJ1GXbUPyFNjmQ4UkjU2uPV1ZqR52cp0bnGbjIbDSC0WYzQi8GMjvsixkO7
2Gp+Cvav+hEvWPCadChShtqN0oxel2ddh4YFjpdwu3XHs7RGfBoHoUQD9q+mhE3+/4in9VSAfnDO
/B6rjDVYzT9Ud3GP1/8YCl4WlRH8TXQpjfhf6Hxqj7TWPvHwa+XANG8VdI1f3xkMfH7J38myaNwb
XbPa0GXDQHBwGNApmUJnxbpjKeQXUQPrW9FE0ZCWc/8qT8N+fpLYEbVkGfT03eXT+MZ6gbt+FnXs
0u1fFcTz/cePzZ30dAZjTuaS1CQ9p05xdiDZdAooZ2F2lockgRKgycWvUK+21c9/fKFBdfPBwQSv
TGh1AEyr+P81i6OcIciONUn4lJf4K+k4UUhY3WqeQ/A1YAMogiXSTa+9b55/BO2mNnGaTDBsWifC
N+cBvRxjgASvINmVN7qL3ujY/tFV2zkeP6jd44OTg92dV67pVB0ll1HaPSPBA+aNLbacQcMiYkUy
5hQWi3CsLsGKM2LcGlSWk/idsrgMfSNhzR6WnjQa8F7TuWJ5e/2vf1nrqKMugCswDW0HHMWTiG2c
GiCJY0z/CMdZb3mHl2vtKdtiTWEx/fnBcfdEZbAFAaCB1SPJV4xOmpmznjKRueGxmRYNmNSkcxAt
knWHEZs8MSnw+EytBhoiqfw0symDxQ/9EQjzVJtzSF3UC8K2x8Yu/cqmNphwwdjUeczmNupaA2Sp
HO+x/qTGhD9YEF6aQSwk8YxkJXd7HgVEY2ggUEoI1/swNmsRhgBGJDh2aJDjUFsLXB2WwUZ91s1o
tfo8aFKMSbicpWKSVoutV4VVShrSSb84usQRAKF8lfSZsRWylEXarvOzMmfS/voDcTk2zPJoBYMY
LXrX8t+dLjTXnePjg1/3u4Fqkdg2oi3ipdUG8tCBdqFPAWneKdG7cXhOs4UaqHW7UZKcg7H8m5AA
J2AMo+OYJkaYHbSdYzqD9gW6etj7nfozxNB0n0yy4EU0idK4H7yKs/x9ws0+lsUr0BDl0yyErLiE
gHsRYvNZ/UWBoKmfLRXjI0M/ELneJ7Qwgyi/ziThIokHHzHcgKg4ccj2U4erM9ECI6lqH81PDSsK
MHUQxb0M///7URX7wfYoosqvdron+38/ONk93NsvrzW3wFqvVpeZiF6YpteMYsACj/D+kk4dUF3l
MJ8zGuHnyIoXTHyABWxXCCsAfZ6Dwu0AH6BMCJ22PNHJzkE+SdEV+wRuQWK2VI3o1AVlJLg8u6aZ
tRjlPtNxAX6ZpfVfhbQ4aw9qFp2EGCxXW/m/kwavSP8TeI0y9HF2ypJ0yzVMYFv9V1E4bPPoDZ2O
DGWR9S5D4kWmsQYnaTxuiZECwO8R9C3TORo0nH3DR8Q8tK3ZWK1EYPLCpmAyw53LQgqiCY/9tcp5
icEarnsXhqn5cttKk99mbYaRYkBkiNfV8AgCqB/3idWxLQcYSHjXi3LcbEDNwd0f/Uq4lwbqmNrQ
noRyZRWOiOCDZxBAkO8OAcxhG3DYL0xfHWZf51E05bunLA/zWSbkVK7RBmBR6JdtpxhMOLoMrzHA
LNIcCJZe52ZtOo0mfF9wqS9F6ekg4SfoLMUNJ+3aGW31MEzF9AYznr4OJa5L/aUKVu+jMMt4NtR+
RgI4fm+yKTxQTFNDJu+h6sP0NIxp52GITLUKwreEPPojYgo7J/tiOaQZ0ajkMCaQXi5TkH1jBSX2
j3FSf/E5oMHqyr9BeKFlhR09swdYs88hdE8syuB8LFcvmHaoYDHmHh3OzLdScc7ojtve/ngQRDhn
3C99U2B0Oda48bTBW0qj1KSVlh2SLknHgXo7+dcsyXGH2TCXqdnTUK4e/I2H9GoK018GEPllQvBC
S6CN6dLc7qVWYmkchf1zmoG9oOXJEgKSstMgapfSDsdsLWUDbTia8Z0m0Qzaj5HiIWWan2IyWDt3
utSWxaE4wvW2lej/C+/5R+en1hhmxXPoGG1DAFpew1P3FD+k/9I3nMQCDitHGnd4O2vVK2oAAu/o
ALi0fkmY7DwydzMdh0rZH7v4BZ04LzBqlgGUWkD/2J+cjuLsjFhltgAurT0JPoW6N28I3h9Pc1KO
NHimsIY8suHCUdqXW5FtZ0ykzTeoHKSlHYmWS1LbSTSe4lvLED1tdnEtyObdVoPOC0ubfoP2pwzo
mNAuGUPfw/YRuHuqEfSztNGukQddHc8HIzK7pnyjsBXd+kY9+/kP9bedX3c+vTx8vQ85wOwrMQzN
i/1CTGmVWaCzNzSyn1ueD8JC5MTreH6IzfU6epM9exlDj+oQpebj+dwKB4JeKhDIMyRGQOlnICn0
AGaadlUPdxkirD2aI2p7yVyTwppVxzXvZhdaauz6Fp4oTiFCe0RKgpxTENQydR1GNFVq9yJJTmmd
MvMmkZdBdEXsCsQZiKBluEmUG92NcJBgAS/0bw73UHKboXZoPsT/iRm+PDkhfZTI5FSk+Q7YTZIS
rURz4q9X16QcgbaCCRANRBcH3SPVIyJ+LhyS5LqRq5x5WeGvItzXjM0XGZDAEfsovGoKkbR4EzsZ
GTo+cddGU3Lwj4PDQlLVw3CtqfRGPKStbzCcU2YWs2nAN3EnZ8y4I60ag9z+nvQUIUVanopeWkgP
/XNmKFE42JKbYOiwP8iedIjk98+18EwTI2ZEMgpfv9kpCePFVqLdWMRt4kMlTnEgLMvvDs41q8rE
YlRP6qkZG3Uca5rujt6ip9THx6a5fXZa2YvnrK012V6YRe7d/2AUnDL68fW/Zrz3sfpZDPPVfc/a
sT0WQIGzomFH1jWmjLdiDqE9D4JA3n5/NR59bAIoZP95O2tLhkWcsOh43d8I6DXijMutreur7QBH
F1eOMkV4BURsripII1FUpgzbdWKGXbnGU8WGQxqkyxZk8Z03P8y/SVylU9eb4w721NkO6gmfZb05
b35w31zQk2dGJ694T8t0e0lP1TcNg9QoU6gcl6xyyPK2FxJft4vLgPv15HLZvWBt2wsYgsvctW1v
YWBXpe2kNeoXNLnQjqfnUPIYnQKPSIZfII0XpETy88iIf5/VO1yXF2pk81Mwxcj86F9K90v8ZE4R
fc72lLXSDEWdp87bhTX/pOYQeMWMPFBAvDaCq9EAy2dpPZ+VoFGaGagJpkadBIaymD9q5+KdJbTs
SebxhLxLsXB6d5sSOmDZ6W7dy8vuGBb36ujAi/v9uVXbc/v96sel7+u9eJNYGsw2MTNwFvpZ93R3
prLysxS+OQwShHA6ivIooIdlqwtaoe8xyyjeP5mI/kRU1ON5aCCalvFXt49/xxV506HhqmWGpoDO
4BbKe/9066PXUd4nD0KmFxAAr7Da2RtYH5dGMjZ7S4W+fL72aVTxs1iERjE4e08pnItvKYuDaa8q
eR5zcnNpHt6n2eTfn7wbxeZiIs41Ev8jg2fCgb6KQf6gYBOCyYCYD60xtSNlPYFvKbQxXGePooto
ZDxtJtSRNvaYY+fAIp4ZpRNYGZJBhKYkuLjOuxsP9WKw7tkwJH+NdFKfLQqkHTrgYCmAaVu7m8YD
kWv4kiC3XjsRS4jRFQSxzLofx3lhJWvGk0mUakvzLgwgjvha3HPd4XwzQEZQF3QBtURb2Xen4tmj
qbhx7JnrwZW8BQBT99vc0+n+5m7qKgfe6UAGMyfdmzHW3hji49yV8jIEz6kbVsDtu8WtKT7zykMF
9lItwoKp8DjridwotIzqjaCYzWCSNe6zN9wPyguXt70jXHo36DQ/Di9fJaeuOEmUDYY1nOL/o28H
9RXSDkSNixh+lfqOaDgb6ZuqnBQDGLFLxj6+QMnD7JzPrhxjfZckX1juXK275XbXrrQKF3hDbgxY
jt/aOkmvIepGLe20wcJtGQIhY3jZ1tZp2qE0Gn5sXogJxBkJAf/iTrkZpSltKdvIZXcDetKobNsQ
20bc2Oy/fouhV2Y1nDuIQ9f5QjrNpjEumb3P9/0PJJfy94PBlV0p4/RBq9AchVl+QguM9hmcTMCK
BL89/fNeGl7iZ3zXBv2St0uT34vMbd0eDKrmGi/pg7ax88qRmJUVM1GZjT5HhXUFl12qOEpitKER
FXTM3rv/tsRu4r9JiBjK/TMoX5adnKUzEBTRlWhAk0GYDsRdXOmFn/+dCY7ZDpmTzKU7ggLuv45H
JGlGJDUTS9xY1as7zMwN/1NIzeGAeQA/qLFYoTk+dfeBxNDZIYIvMQv88A6n0QSCyjEBN//l6y5H
XCl6roUrMI+5DWGg0VcFPWTDK9eJ0YhH2TJ7TIqi3fpySw6zIIT5Y3VrdfXL1h9r+A+JzEOtOEej
4CQhqvxabkaB8CPEFmAZy5DiAXuR8mutSs98774FBJVt3MnbJbBlSFOaPSPx/LWTPb9wVJu735O3
HW84At968qRjvz8fJUnaWltdVT/qk3W/oAmO2FUaCq0jLU9n48t/KMUr05yWW36pLKkcUXtc52eB
FsaHCBPZfMjESb/owTYAIZmbdWc9YTGV19TmRrvaM7NPgsCd8H74JNQ+APAGWCLzYfXH6pfxxwZP
hNuYK19a8LmpXPH0xU+V3vuo/lj7otQf61/+2Piiib36Y/PLHw++CECQr/eWiP2H2vzYERzr8Fp2
ZNU7MreOHnG7ZoWoY74uN0StbqudW+NW47e0wWt2lZM0MThGrAY2mgizUBi+9Kr1/J3fdY2vnz45
JBWQl+36oqauBFlzDlxCbNtdhunE4Zb4iG2vxdbgOe+B04SocdWxsfqmdUFoNUe6sZCdAJQF75Pi
UXuiHPDWGF23XjfNy3x4h2U/jLb4V8WMrfWhe68tCiPw5N69Mtdrvg7ZKvx+7WNl+fEBFteAbj3f
OXj19nj/84cfJY7zEoeA7wR1VwWjrHhW3gD5r8Tu2cMzScd0QD/vFZbXz13Nnz+TiDKMT2dp9Pk4
ypIR6ezKq1tlXkh3rujLOf3r89TpyzJ81Gfw3r2qJwc4xkrpIYQ9LdhhfRCoStLAYNaPBvYelCPx
tP8MWIY23jSyUXLZ6FTAyaVwls/65wGrz7iSFbsxNFQMbaKBilo4UUybdDxsMQnQp9csIH07W7FE
EQBBF9ceKB9qqDlu/kh8n+fx257HtWU0qMKv5n5V8z8jNqChPQEqy26u8bHwdtjGP0md8N277MGE
0C8cBY058BxOwZbp1xgB7rtJVu+HswyMHPe0KR3/rflhFy9yIHNxWcKBNaFsnviq4RbLujiwW2AA
L1Ko88vhqrpQImOdIAWCY55C23N01R/NMva2Wg53HYsTmYBruFbgmomwbkySeCr+fJjGpVxzc0RX
THx1OdQNgSqn5DSazOhw4uYmGpxGg6XvQv4T4qZjNreAibtHb3kkHAkuIbVhqv4dpUnHPT3KXwa6
P0oyHe4k1k1xwKApV0LawtMwnpQCpOnNvLMMdm5nSzo2SfiZOGGLrYZGSDwB0YU3oPwSAjV3HDdr
juP68uO4vuBEdXMS9i3pCofwqKmeIROPLJOMbcwgLgtptWhzNf3a1ascVRc5NgvbqExzfp5QroKX
YQaPTUwNIMQApXkr+JBcKJZXabEKs7laCAfFO9/E7L8zXy7+MlyHny64odbj4z70UPfibEpr32pX
LF5QgfgLeHdW20xW/F0Y5/CWo1VvFeyzHkP/u7zHrL1DhoSx7NY6KP6gujCjsEOy9v7S4YnClklN
GRG2wYNKnJxKbltTBByXjKX103Sf4jvfzGMr2SssM71qiq55EBp5i+LTSkZ3a5AxavoJvNI2V29w
K6hxaqx1CV1k+NRGGHqtNAht0ZFBrH+vQTjDqFvN23xuXkx9caP3YYFvZgWn2sZualGOVVyjKrP7
pFmbGsub8n9lZy/9lo3M3+nuHhxoqMbjBE3ECeSrUiqUHNlVL0lyZJmYErj6QATQZ44chPR4FqZT
BcablUJ94WeRqbOYI/qJyebwYOMQg2r8gpeZiAXxGqflJZlR3IA7JDZMBhBF3p489x+rHq3/dUf7
lKCzeDwl2gXazf6PMHrymQEThh9exLeZ8Bs+DtnRkQ7vBGk8KoHqGF1iTN4Aw8yqI04E1Pbo8Phk
59mr/fJSWf9kuYfR4pKMLo38UThDCoIEpvgRO3tM8DuRBeTzsL6AHciXpewenYJbDgbRQAan9yJQ
+0VYtzBTnu4UiSgwmDQC8RS/R3a4PJ+QJuSfJsmAdosGHnDAc/Ooq1NnnIBeBvZr8Dr8nU4AGP4j
LQNEk4stiC+fjt51X356dnh40j053kG4KRNOb81zmajNukHkVOx6QKln4s5RGPMKEt9nKZANuTo0
ulO6m0f3rw53d15Rl3s7JzvKK2RVr92RBif7r49KPPRmfzz0y6biftmhyh5YHpjhvu//+eFqfdX/
cPVo/6O34K2ygdKwvl4lnpvBekX6oLJgdqvLKAZae7uTJ9M6/7W5fWAQT0XMKYQEJ6mHwzCb08vs
DD6B2phl4GAVnHlZ8B7af8A/cLX1CpuWSEIlNqwhF/hTuqOTX0v7egtOegS3v1SclcdEiolGOue2
hbwQYgULe1BHYIF8/azNhr7lNqlSL7VZe2gLWFfC1fwMh9MX+TyymUJcWlHXIcLolyGUvrufVHd3
vik3TyM01/d1x7S0r6P8jEiB9asKp3Hg5FVhF5X7xXK5fxKsiPY3uy+ZrbxlVwn+SxYb2UXUe0sk
1t8hTY3eMSlVdK4wYIfrJvVwdX4OYZZFuUjNo4C/ZLVOJnI3bqTlYuD++w+D4OM9n1QG/+rh5gf4
JzRv5XtiPoyr3LPrP8EPgh7JBjS/T8an45O4U7ivV8+VC1aIJr3jQK5LeHPDlpje7188CjaDh04b
nx+YybNvRlUtmvf4KJ9lfqn0xi19OrwSv2yBtoPbtMvArM9e4dPhvGed88xniRtGa+EUvLLFrnQT
yO/f5ap83vkXH1F3i7hpER7KK7AgWrodSDAUpg7fUZMORSQKIliOWlujy7hE9Cb6eXiOay97Yyky
iTvIYrGXMf5tsH1Xp7SDeJMcpQlbouBH3p9x0GIyivvX6hk7XstFJrK16DB/DNaCYol6PqBMz5fX
2DueidULGT3qRdQivxlCu9Qlnos0GKiDoZXwVC9CKCdJSgOWLI0EWNo0Y2IQ+4L3tZJ2KUeUakkK
r446PnnVXmmS2twnhXIcpS/BZn9urOwddHdf7Ry83j9WO2/21KuD1wcnOycHh2/U4XP6tvPs4NXB
yT9WVk4cqbsn+evmUjR2OO2crzPnZMkwv4SZCyZC0j8Q1BlivdIBMqjl14Fy01SxVzLwGd7bAN0p
Hg3gxUQSR5x3jC2PHq+EQ9r/OLSRxhwSytL5ZXgdYMzOKMSp2smSl7JucBEjAQDiTLsd66BOL6Th
JL+WaKxrRbRi0FkhZTzVYbNQCGIE6cST/mg2MFF/4to4ZnsPydIaTCwq9jDOJ3idreorThbE6SyF
LaMDF3RIYGhF87wg/S/s0QRz6CL9/iwN+9ecWnCSTPx4MoTowTkMaaq8Fwddzr6380bR4Tk+/JXO
z+v9PY733tv/9WB3n5DSWpBDleGeIc5JfpBg2GiAhIcr4QAZ52j14/B0kmQxT5ijl7gv9TYTkUcy
B4qdQrzUWUKZkWrJSbugP6zATMHGZ0W8ix1LSJMbu+uWwhpKizWKhxFN5B8Qa9DeKFiyXR1jpIAS
LEig94ZJAO28NqPzYaRxkiw7ul6hobGcBJzijvCipHBEHjzaziny3skqU+8uQpLOKQZFpEAbsbmn
w6oOdSpnrBdidaASZgks4x2du/Bau3x3Vghv5C+FUIM4HHU40R7cvGmIBILaJ6wxDsIxnBF9F6NI
FUdqtsnvs/S6swIT2oTTJ44SwUL575DezUNEmtEM+YYFRlttKKKfGWUkLEyjE4L4Z0C40gJzfDwR
euw/54WTBSfUNAvEmjgi7WWwtF5GOBULMbRujUW0tCRNEMIMJHBTcjoi7yCh8anOvJnwCNlivYJ8
grOR3i7GNo5l0NByzt4pKuc41BEf1zpwz94cYCHDKZ/8WPg7W7STK4mNl1C8kf6pcaB2TtMoamBH
hjFC4hiVkUeP4+5hkOysMOPKcqi1eJ3OIfFUpHQTwwQ6IPH+ghaj8bPjuQaznl9QW80YfyAZhCCH
kua1yN1psxRIGGMRkmmz79EijHUqUpNxZs6w06pL/lXQd87+1bYGnxIrKAw/yLpYEiRFNbPzttfN
ekI7EpmqzeQS5jygYcuhN2yzL9kiM5NUcESiGAitTjBJzMmZmuXRyzOTGEvFcw5nnFNPbwkF1/dO
KsrFYN6X+gt2psQBJCoZaU4mIA+/xtksHHXza5ppy3XYGdI+4Y+Sr4/umeBN8pbXjUh7U28PvI5a
c/I08avP4tNbv9pR791feTA0wGck4pVHlI7LMMvTw7/l1gHyc7py6LYYSJS+zCMC5OA7zsorcEJ9
/If0TVMfrwJ3lzgpDTT+d2Tg1swUP7cera921IPHq+0KBL4wOULIA/rike1G8Gbu9pGZrdoh5vaM
r0F5ddD8eXwVDfaItian1dav4wnN49/RMyIjMryKv4VuFl7dptlJMuV72WIRy+4V0oq4UNKlIx+9
hsmXJ4TNrA6NHV5OklfRMDc78iapNnpGqo6o/KZHiyD8GB5SxDB20tNea/0B4c/65gb9s/7YRRfQ
0CXYAtSgiZfaB6+JnMd8s1QzTTTArdQhLt0WNaDtS0ajZ4gAxdx+RagMrYpXAeOsQnUF8PtzffjM
riSOyzY3cFeoZnXYlld+w+YjUAvQlfP1toCu6y628qQsoi9D9YeP6d3NuZfdM4isEWUibgIlGr+l
P/02aXTwB/23OgC2RbQI/qq7xf2z82VbzJH8pT2mFyrj8Q4KzqnD/izztIxShLcDzUnFwl+Rw7xy
JzUbSBSx3GYZEuD3O+zY5oMH7fLLd9iyjfW2G5/BEobKOEOD2OU4o7aTFURyEcXjkDjf1JAwaDGG
Nw6YKjnxEL188o8oW7ZXz2Z5nkyqb5QJOO8WD8+ba+gueO2K63buuixZmLVHWNWH7bn33U1Ztisb
mw+I7q+uzkMQvjsoRlomubqVEPbjiAXM7Sond3+l404vrJQgvEnuuNZvkpql3ktgya1bcWpet+DV
Nt+y2PT6bdf6wcZqzVoTgDst4pvEPQUcFcgnocerhahikm0HIBMz0oNGVk7HgYiR0yoon0CS4T7t
SrYrSXo9aP0xhwTb0la3U1+CF1FO84QvxyzlCKuq5EH6VDSSHeRANd5sVQx8P+vbpBp/pwGSZD2O
SDhvDBLRoVmBqEKlzSO+lWHQxxhr62fcZVx1eHgdM+yO7q80rNQsrxZsSIuQlXVcGVxZvGXeQLjj
jXit79mcRapKUtatohiTE1+o+626kCz2/ildZDjSIa+dmYVvryFxlwrbUl53YVG5K69+7prC1XzY
Dlj4FFVzE2n3lYo69IMymcxZYTbaT5ExXYo/EBPMWVFsZVEKn8c+8kngHnYQZec01Lag+fwClhfO
qnDLl6X0Es4c81ZJcWXvhZZk0i6rijfsQakz1gOMXWmCdOdpgiy/Rn0fRBecsN41IsZZ1fx2hw51
vq1aQ12gdmja0D4dS5CqWoLuMj2spWTN11iLmbJJyJpFTOeFBUjsOYVx6A4delrnpgMOGdkOA0qs
+sd+V8FqoK0WFXuFqrVX1ElZXmHYD3XcFGknb6fTKG215cKduvIW3Yl+5+P8NcfXObpfvsEvxTGd
rwaqe7JzfKLuq1eHL1buMihx2nOaaUOMSc4+n3t1RZy/JkUOSFjvRuxT0THGLnuDIKn1ORFXhqRU
re55TF8E4XzjDLGlzbFcv0Fyb+HQ6+SS7Gaqjfd6k4L2SkHgHZeKOQMWrW9tw5XdURSmjBQrDn78
3PjmkiyFAQfUpVwLirCsKNKDWjimJtR36PXE8a29hE8pMXunxkHvGgnXaAGCFSYMkoAUFzdF+pcM
7YnuvXgmNkeiiYiOVhur/pNV69C9srSizQpERqz2vMevOHyKy7BOMvPtFXBWGj8vcEuQWHgd6ae5
xZZk1W18n3O3Rudu5w3umRYgI3L8e2v3HyvJKIdxlPwfvBJ+Vlw3D7KHm8/i/HCqc8uJ5Q9wObW+
t6Mebvo9Wk5TiYrouTFccj5bKWYUcCfNNBy/WJB8fTcecx4bJE0lABvrn3b1+HSXEqhwdHadgS2+
Fuf0+2rtxTNWxhdM3qQiON55Tcsu/b94Bs9I8aHlB3CkesxpNfl62DbDZOhFTESM4KyEGuM80Y+1
h9TK9XQfU38kwghFojckM0T94S9I94Jk4TUuBt7yBDZw2dTOI/DtmI+BN7KYbB4J7CbPkiQwQGLO
ZDKRxE5glEXPAQog4RdjdbdvmLtXSfcpF7BuxitCuwSnsEhbcBaFF9d6xTRZvo0nKMH7BzFsUATO
EeXeSDJwiIlg6QjccK/J9pK+xNw6WwXvRCZFOisikjaaEXKoyBbfvXL2D3O1WfEAHEIrS4YECZeK
Olca7lWQtRt+NS3tjWrUoL/t/UI/01Zrg8a43bFlv7LrSZ9vPgnc4STa4xol97l6GZS7+zrrhJIf
WmjOd54zSFS9oijabCpk9H8SLjAGE7zfZ5PztsxdLxcyT5miaHCnGRkN1+A50ljSk2wYc3UgfV8T
4rq0nFnwnVmk2lxTnKeg5nbiNh50ksDkDg50dY58/G8j4EgbH94FfvPoYK9QO2tcfLXnnlz1eFfe
knuNkovKEo+/RU4qi1PWzeUv/FJZd9LMZ4OuIM0NSy++pLya2vGq9VPcTiYRF8L5PBAU+yypuz5k
P8rjDx/o4YcPn2PuidHOcxMrOqF/hZ/oBVQlz+Cv17F/wo0kSnEDW3o4QahMWhKUm8ng9kkcLipV
ORIdK8LTlbuNDLkv8Atiy9MBYikOTic04t0wi7z2gimVvbfFNPalUrGEjj+xidvgvQFUw/eOuvpE
O0lS/P+ahaOYjl4qE5HcDPv0irdFIw7Qs2F9a+0KadddrRoSzGlu4M8acz1A0Gh4LNvSZbCvcpYh
4xvdz2ccbkIqQpZnkm6V4ETF+he5wn3nrLEHvnZoZidSJMfqFLZsjGV5RnrEmrJrFhK+u1e7RHzZ
9uskvcPN5K6dVWkTahKO75Cqe40EDB+b+LeShsT5yqmd7alZ7pzM/rUO/nxxNlzn8UZnnMjbvV9m
jzfpqV2yj3xZaWbXmeAD2zLh3CWz4YduKnDTkF0S7Vu4vdv6APbbtFteMXcvW50VPeziXclCrm/E
22r55weTrKjGUOIr+oHEesY49S+N4NlKeR/dUS93Kjc9kmDqIzygQ3wc/F/4KBuKQrDrmzo4evvs
1cGunkBdB9qZgGOJJLTjdsCdnVwMnAOJ0iiDu0ELwiMxkbGuKsk9oC4mtAdT1Ix9ih2/fA69Kro1
hFSnRv+55XCA/iI/eWAQ2t8j7IHHPAdN1Ys0JuGBDSdy2VCzbxDEAehksII2Nhv4WtIRcuMCbPbd
HA+PVx10cwByyj3YupOEw6tLEJBlfZeIqxh1V+d81q20QmNtV4bJISpLRb5lXZVYGEuG2y6XaPbL
jIpbcMTmqjuOBlNl+ZWkN5EwJ7oCBbCpXLNnwUBUCWX6T0uRklYlwnwlLSyhBru9YhCSE997qojR
QEMtKI6BaWbKOkTLdaaFDS+cXIsYnc30UpK+IEVoUUbMja5vOIqTCOHi7L8ByRVpZXmr2VzJy2LQ
ccQp3zNhLaFGpHnguRPybaVrK1vf15J1oJibzqZOkemKO2mDS+00OWOmZIN2iLld6VK0SLOb9tFU
LWpcGGSo8d5I2pYb2/48axyhtn8bnNcALtr+PjinVi/ifGkrKcLavQGWSVOXAaZOEayDI1rnJmF4
OD1HIWZEoqaSsEHcCuHpn2kEy2aT4PfJLLC1c1d+0Le4pmo0mL2xG+y86R5IwN5U3PqgH72dxFxO
kjaQq90ILvhQXEaREwfH6GIvgLVMk6QS+DmR2rDRtQlL07cOkrq/yFpfbBThz+kshJ2cENRlArBl
sU+lWAr19TzKqxqrI+LiTGRYWKydxKrTxAY2AzyfF+DcmC3/fDfC8yh8nDs2DzKi9In/6Ko9xksI
ZTZpFzj992Ks07W3PSm8eZDtZP045qsw/t1JR1lmEYT9Q6FjZaJmIN9kfeEjJkfLBsSzeZAP/5Yy
0B3LjH4CErmxWthmDi19FAsN/gqEYoi9qTDO+E5MPlirk9pASskvts1woj32poV5VEpCXOsRw/Kx
pbQJz4zWLrGUrDHikhBKACsonbY6MDCOiido9v2GJdEsIrSYhmkkpun9PsvgfAyjjawml7pli8gg
QppRjrHXxcDb7AZ/G03bnHhUFhvJfwtkmje+F0vmYJGZrHj//6MoHCyH7ga5IigyQ8vM+bjo06kl
MPjHC9qDL2R82Ewxec7MzSWxwDZwSk0nVcCXJVOsNc3YcsNDllZhUe4n09icRiBtkQ9Cl6SX4sZf
H23gGHG7+6+eq5P97gkBOp7p6vP2EiLU1aysatYPiWzkJQMYY/ZEHEr1lQVXOTGCjJvl/DQ+DXvX
kFJpIoyV2ilYrjXUyWViDO0dcy/JVVUE2atGzCZHjEjKPQRe6z+RdcKmZCqMF46cVFPWAqoYT6iH
6iYfm2yyLpT8mmC7lOXcvyjd9L2/9lEL13xtwCkBIGVzYY6Oiln3V5DornW4fhlenL2TgbcItE8L
bMbX1sE7drz0cx+Zkt/tHL/xanJyCaS2kWBL2bfooNBbEFN06Y72omu+pzZvDxb03r1KfJpNtZRK
Hmqd76ra29FOt7u8Ny7EW3SGPa3tTJU+cx0hedTyjo6jAecTNz0BZUo9LQjdWtoPCmco5f9VP6oJ
4ArYwNJ6D6LzcW0VmaDrB1dGh9IgK64OJuBpqQvC3FkvOf6CF7Bdco5+LAt0LZcV5hgopbbckKjm
4ujxNsv6c7/uD9h/rq2TIpS6MMIVcapWxTJ3aIPSDfia93VteryveeNcI8+Ux6tmhG4tKr1C8xCZ
G2vIpt3bJoq+DU90KnxUTM2VFJfJxKzO9u1C9h8S2iFH1UGmX6xxF7JAK0eZWFj3l4MjZWskaR7R
wlvpXMhduwaJ9sL0XNcBL1Ert0v7ywkpASYZBAuvUJB1FiidEsIGmnHdSMdq51Upda8slmKFPYKA
jEuVYFM3J0nPmOJ/bnk/R/2zhAS4odfx+E9bQ3Ish1yt/fUv6/gR7g33e2oVQRvlxBzlMbGhcrum
tE7PKarDuDBXK+fnVvtpxfP6S3nhirxXIB+xLqUoCgDEP2Hjt1qnXjj4lnUqSpL1Utw/VZZp44Zl
Epvmty+WvsywJs9q/sDS+mXRmFS+UTKx2eZFpcxm6QXjIyL1CdGqdcNutZ5hepp95YJujZJkSv+l
U9P4j/+51tjebjRUgXB6xXeOX2zTr/Q1O4uHOf33NEGkHt69ASelgubXrXKrKBvm1dVA8ypJW9/3
CP7HltRQtPUQG21rK8Q86gHV7FoF/wvXPqhNGTvstGDp0a43LJs5Ebft6tYJ3n1TKNNTg2QW6URe
WzRqiZPkiCvJE5UiaYvktinsGnM4NpzHsVZjJjYLqfvFcsfq1erq/pPS1+e7XPQrv8ob7YXI6L+S
anI6UXb5dtINP6vb3CLavAKmbgtPVCNUs4wtd6Kwak0JHmlS/qJQd9sNXHVwL4UKXIJVAhGXzOjF
uyX9eYEJojLEXCGpgrYVip3UWhbkNrwxl/R1gfFCblXoZyTVE1uDQRkrXMuPYqs1+GMzprgl5uYW
ky31onQZV4rqyBY5gdzS/8N1+Kg4gxSSy/wxuOWw2W8ByritSdUKBwlJ1rNxMIkYA+42GSQzcSHc
v9i4H0+GyX0dtD2KPpmMGTd4u2x8twmasiaVgmKtUkGru0/1xnpYfUmugEAv7pozgKxtrK1tPnrw
+JOkcJFsILff9m9aFSyGk4yqvC7GxcvKL9NZb8RWk/+/roz9k+MwMl0VPJzCdJzAU00Who0zPVKf
LerAbnRtKs+SXO6EZPxOeC6Jmhx+oa36Xi+efEADlmNK8rmTMkRDqIYSEPPSRvmi2Lo1lFu+SzII
h5jBoMmsbI7p8ijP88UD1L2Ux1i8mdWIW7xdv59n8+3nxRzqul7OWVjRUsb2pSwJzfWEj+f/zd/D
VUAwCienMxIqt1FtoHjcx0Vaer39tounJMBzJco49coFLs+zogCmR8Ldgs7ojXB0Sk2OuzsGQvxv
+MWsr24+xpMLAjKAR3nHg6zoFsTkRVtb39j03IKYztMFnQ6wrdRw9802YtYXZBrjvaqX5v832gDU
OuNlqlv/2rWaz/ptRdxRrYDb+iket//JRUz5QGxVQNxQ6r1OORfjdaGZM59xSMM1FlMuGIVCaCkJ
rnjLVPY6ytTMBuevT9MT/F0uQKtPLGlFoKK6+J9Qzg84xkWBzLIi1NTk+FmYn9wRpH6zDK9CvfR4
a6jXPCcOtcOoMdprDiRGab7dgTaLYqaXyMBUR8n07s/lrXMm2f7mDTej7rKD57J9v+v23joP5LLA
MoUb1H0l3vn0v/qETIHJRwHE5OupmuxYjKO3iEnRBtKa3MXfoRTWV9ldb/tZZneVm0lcccz5fJQz
38qVCP6BL5JcheAfQoiso1ZNflpfZeHQ8ZBoLDDLr9Ri4126lFHDaL6/V9eNa/euYHhkkj9pdR7J
mc4SU56O8GKqQwrq0MLA/fKn7M88Rtw1NortOK1ma36n4VFpVL419aXd/j7hG+uBevdy50SdHKpn
bw9e7a1IvMY64jU4P9+AE/QoVEq1iPKTt1KeajWvsqIhIs7n6Ay3oiSwiuTqfFom+Zpk5ZVc7hyq
gzfQW631WBI6zHe3zt29Q1L+w67KxmGaX/K6mr7vAGuDYT1DxPDUjh9XbxbirYB5K83+WYJEbuVQ
QPqwNQnpOnABuiG1FdmMvI+gBtXie3b3CaxVa21v5RYZa7lLcS6z3SP97peV7DLOxWuPn+vAQUNE
0Ibe4Ysh2Tad1+Op0k95dU2gPi5YsXME3G6yMWp56zWgzFslUAa+AfWuWGENauO2o6qCKlDvnpoD
O4iGIUKvF4C+5XxVazaBx8fphJNu0fG+hCOo+BxBPNDdtCUeBX4Y71yvEwBsfI9DvBGoFwcn+uhu
4Oi+YAer0zifU/W0axaEqA/0u2hRteUv5W2LIE3UzInzt5XkspXrqK9LJksPfMJxXxf9xff5VLLf
IV/sV+aJfR1PaNn84Edfos1Meljx9TetC9Nhb5Zd95KrW9cudvLGlhb5xuyx1ayxxQ2ehVNyDHWh
12WQXboPRf7Y9WDzEQlsulWwdl8vkDzXi1TOCCt+OYWzJhKs0ysvZz1riicpGkaaF8gUOdOJCh1j
kDX/SGEi7bIj8wau/o+5ksTs1ujJnIvRVPLSFktSZKfV0HSC2hdgyZW8tDX5aNHMJqKdS0BrQEop
YDmErntr/cHTgXIvuIKAWTrcZRASz6aB2hOvK07QY90/S75FqKBjY+KQ2BWwuDS59z0oz2aguodv
j3f3FadhZQrU2AQFYjcDnU6UnSlbPRKA+mdE93ZoqM/4S7shRGqCwqF0rImKfTrZP3598Gbn1aej
48PXR1ABvVXvqTLKvnUPlcWrr9Wu3V89UBrPUrBi06YDyVHIMSb4g5P62d0r07R5C4Wmq4WVQvdn
LRRmUnVXZB6rNTAo+FNSdWAqSdL4NJ54HXdl6gwn33skrCsSlcRghn9+9yTgRNy3fxamA6/TkHW4
74yj8eesA1E4tgINB/gXW8KOvcE0TabIXBZl85aseTchoXFwtSzjlc41aQ+Dc5AZE1kTcx3kQtwo
wUGR3nYyapVUVzPBsvaqaWI9YVlyQuaOiDuc0inWCfHZRX7KnAHzmNJ5Qq3s4gzdYo+KW7e5Xao1
5Hl+n3YGiVgCRF6wG+Y2JDZsmv0JuQX66Wi4zXKbY6akbU74uOHgid8GfxG6VEJ/PJaMDuVfj0la
6ei1Y7glrEDUUzIex1yDs/X9T8uFP0UpZR50dkYMif56ub+zBwqn4yY8U0f5jsRdPQjUMYHSyuDL
g676df+4i1zSb/b397patnzAaqG2hnG2ZXBIVuWcAHwm/RxR4a0UvsRgOuwrmxs36NKhGIj7umRG
0C63Oqky8dyV5s50qs1O4AizCUsGKJt8HP3rb4NzI5PKgyPtMVB+ylI98w8rwa40L5jll+2M+myw
PElfPmT0/3GIq4ckH9F/9ECy4DxfIDsz1EJ0Np1wpoEzgiruX6XunJMcj6D0eW43N9VCKhse5wVa
WyHeCLUfPtjpffisv/ij5DSm78sEV+AyZJsjIY3XykDWREfPdS7RfHVFTq5MzVHr8XJhq4FrhQOB
uKRmR1coDYxht/i9Dsn7Fhs+ZD9u0/8brff/bHy812547afuSvCQxkFXSqKziO1gEvBgHLwgPX6K
YmiBuDV8ubF7XIGV+/+b8yTQR+dT68MAZdie1o2iQNtFA3D83Lmt6AdLBnUxPgnT0yg3Q7Lfg7/9
+vrrB3OL9UAuDxTTHpzrvm1nlU99385xlSrWX7MnPXu6Wz9tGWfQn+rQo34QZepQN4KSBbSq0HD0
mXNiTdIuTeB8ReyIffDYoT9PalSbjH3557edP8Uu8YeGaPKY0bOnjgDS4OsfQ455aOw2g6KtPJYO
KV/ZDHqP3BRpuIGJJrGdm22p2SbbuXn2VHdeYMINXRtXLhewhMT8YKrZESxTx5JvYVLk6kgrC6vj
WXwJTpGbZ66r1zy9BI3K6mn7KXfxQcP8IF99/dWV+1aaMppfud67J1U1pZlX0UBMj4XFZB5bWyWK
Z4YImtfumFH5LalG0/ZbvXjyGRW32eLgOdG0ZfR1h1iPurSq5pZIr+7RaEbCdqfwhEtO2VJKK7dz
OtXTNXx2pZkn49FiVqmXcxT3ssBiM16ZWyMD5/aLZHs2qyRXpqAyP20ZNGr/pNduytMqjr2sZMNZ
O20gKS3gNwwiPJ3W9OZGyFbYj1ncBRvFdkIWoVxO1dKSpZYwSXFGszcQsrZKx5gYd93Rosd63x1k
+ax2XhyZEX0XS+TDgK/m1T3cRWpzwEMIjaUhmqgn596yYdP1PAwDbr1lSq1wEYTj/aNXO7v7WFCh
BahsPeb7R9cvSKoJSpG7Fevrchtnlya8aJi8GtlwudtLxe55ccheswgEMr36ZmDrf/3LmpXQlXPT
XcvNCBChl3m3oTlp2V5Yxigz8iWyRDnNA8Mwb4kR035DAKGVNwpOJxhJtECHSpf2E/VT5IEBU6p4
xo6RvpIU16IC6GJFJY1W70udRluWm7Vlz8rJ9GyW0vb+qD2ybqga6nbq9OEu40TUuYJa6N8s0fp9
cL7A3tgwozFslcbUsC+J6bWxzBmR0DJMr7XV+76Gcv80vG+MslcPN+8TqPtnSZ5Nk/y+1BO/H/VH
8TTTKW0rRk7dc2Hh1OMXC2ejtJmtfQGkTmQi7UpQaGHx5Neswj8XOeNEcn+i/j7R7wuMo2Y0Yhyl
dgIwnkyYUFZ2ny/ti4CZpRb2YgcZWGFSPZnzKx0lyXlmclqhCNSNxlWbdcyUJbKGVtO1Qz4EuzGA
WyC9BvG6aMfDL7Q4/d78IarxaFhkZjYErVgUcRz6DobmJiC9JPGtcM9aaRrvwFt69oG/8YDYWo3Q
r9YS6roICxBPZjlLL7AsRzt4chVl8fZZ0a5BIl1/iyeT49zzLQ5MEIQl6Rpi7rkcW4QCrfF0KkbC
EhgbpUJMRnIbFMNikwoyAZxxfacpHR2pvKUl6pAvsrng7aVq6EE01O6rA2RtQ1ok3bCfhtkZ4nYn
vKZivZTUASGsZVk5VqZTFMUBPlWL53KdNYQXE7AaJg620dGFlRFXfkkUCF2JW5ANrGUNSoKv5WKI
sX3e5as9b5Mo9qldYnZMHcquYJIjQfuDYZniCVSdMI8RqWBG7zI5JNgryvTxUI0fGar1eXNnt3UT
piBw587OSot60LdjpQ5Eybg97Aph1oO2fDmwIoD/o3crqPXc2U2TULOvZut+UL8UKnUaXcS8JZzj
NUDMJV685ILsoQS4X54hygZ580bReEsfNi/TwORYWoTWBToGOv+BjabT+WF03sYypovbdbM/d2le
ZFCicUphY894l8MVd/3R6urGE4TIra2tPnr4aPWxV6rQ2AS5deSIr/Nnb/5BvX9xvNmLvISLPOi5
4693ebcrQWBsWqC5isJlxt2v3mLLEX2DNddG5AUhA9auwgfXxnfU2GJgxmaPMk1wRyb1nNxJO3cw
NRkArsaOy8NXRRsUf677GwHBuyHypFIBtymBiVVdIspaGFugdVgx081jASsYGgm0maFqTjYfOo5I
51cYlt9Ps/4sI9044ScffyZJQmwEzU+ifzylA32h7XoPNz/S4xr74qL+uklqGTrAQEDsRxNcI5Re
YH1GognY7ymviNk3bkBTv/5+9WPAxgmT54oR8pYIqoWoiknQ1XPnhQ4rfgaSHVlSI9dlw70P39fo
UvhnVd7SZGaRC8Q8ka9TEvoVL4i+6wSxeAoLHSLKDPR2ekI/X6Im9PM6LWHA2QtuFLME5m1C7xlg
fez9Yo8DfsnTrkrtqpi/uOWNkn+rGstSFQkWw/4m7aBgro7G5Dqay7Z+D23Byud9ks+l6IEk1R/F
fWToRHa0YYo6O1liKxRItsUc1lMkuMrOV5rUfC4/msEFBoWYvltlJNKQ5pGgaeCwv4q4KDppynz9
s+cQJ6SH8dY3NzY2ho/Dhxu9h4/XH0Thk/6DB2ubw8cb/fXH6096q6ubg7VhhLvdx082NnrhYO3h
WjjcXHv0uLe29vjBYC3ceDTs0YMofLD+EG9T08GDh8MHa48fbT56svmAfukNV9eGvUePw+HDwbDf
I4kifLj5eC3SqFAa6RQSEi2FM2Ie6ePNxxtrvSebq08ebj4Mn6w9jjZWHzyiEfU2+0/6T9Y2Nh8O
Hoe9QR3MMB37g14+D/PBk+HG2qOHTx4OHz6KhhuDR8ON1fAB/e/Bw9Xo0eONzd7mxpPVDQNTiLV/
Wr+gApMW6WG43qNBrj4arq31HqGP9dVo+GQwHG6G0YP+5qPBk0ehgTmOCRHtYK+zGDU+CvAMM3oS
9sPeg96DYa9HIwsfrfeHYUQY+fjJ5sPHNPrhwzDsPbFzB50eWaDRVZ6Gc3OnMTwYPnqw9vDJ4/DR
o97Dh+vDtfUHm4NBL4oGNOm16Mkj2kWM84uTWZNdCpFc0yBc8Et0bW8WlhcQ1djLMGzR0FaDUxQS
aAPxPTf46EYltVGbmw4IU/dqkgAkIaRdts5a5RgsrfA/RSnq48ODPfuLnMDiOdGOT8eHhyfFby4J
IEbYepMozyiXHsqnjrj4sVE+kUyiIt+ZBL3Gskzg7Ce6CvtWjM+UjkOERFhYKKMrVASNSROx5Wav
UYe6XQwsCtRRDGmx8FTM8iJMXdM4XVHZKKim/oAyKQzKF2zFlaPrf8Mp62CN4uLrU7dHtyupVlNj
6SdO26gzUY+0T1JdzJ02fTiuKVqXs64peufrXFMaPk7/pzRJ8m39YgM+KiZ6zket30k02l517Nic
NbZWaG3ZkTqY2dGx/DL5py13xh8CEmH5n3ajVnadk1trxdDPJXnTfzuJ/zXvWcGb5DRDqmXBQpJt
4XhcI6JKcllMt/6umX8i0XPOVl+9Y8a6MO+12GxyjzgmKK+odOVYgJCBkOOEdegPsIckTKiyMLBl
dIqeWg2YTsYgupKEhuEASK4BJmC6RUCWl1kYdBbocHAd6ssz+gf0wOMAD86kZqrC3YD+81hrDgUz
AONCxIUXrbkLQ5VS3Vxxm41AhbhpPu9JFfrYjAcohtr6M5W1tfXVttHBymob7/s6MICGFXjgoAVw
L0hJcsujI5lnwMloF+hJ8/4+xs2n8U/31NQfmmZjsQZWd3SKYqVeCbpHGqa3BNRdj0356KzXnp2f
7a/F+SmfIaOzfbmJ9M7B5r5dwsoJOh5iHI2S18JqsNpw8nEY1wgLzESf8T3aC0I3xhGXlpf7Dho6
WuTtDQ0d0/aQWKQ2rzLDo6NwaRIQC8drjcP0nCnBeYSDzaWLmAVO8vZKU/9aJzw3HEOeO3G/Oppa
RUIAz3uYapiYYYmktTJT6kZqg3AuUUd9pGOy58YU3cpj+/b8rZsPDiaq1fGuPfWj2lxtL4kqr2V8
ReIjraKVA+WdDEmN+cRG7vKC6bmtqyfZWfl2rZu0u1TzJT6KZpKsvdFs1eUtbDfKfIyTdDt1PA4O
CeH0O5+J28RD2vrP2jmH7WifnwvLITWNLSJ6pz/vWuPGZ+zxAFLc52731ec+XG+GqNAelUpz2ENU
0kUNbqaOLipStLCzCh8oUrGacOTQMjFtCtZJR81XMfGyYeZod2sRNAQN0kmKL+J0lqmXJycIf4A5
WLKeReF5Vr5wJExnJRcWlWTSXgqXi2WRTHo/658BqWlkV9dwiwiRFCqPEBCoSBKA2Z35LU2smlvM
QtxzXLvZkQqqhj1+c5zUlzvOWSa5Xzn5r7Om9UHqTOrqd0kLIDrhe11aTNQKSq/ljkuGU9zSmkue
Aiu/LJEcNEn06WxqPpqJrq/wiH3PLSUwy8LkQXsYWNJf5gMOmygfxDJ/rzt+9UcQn7l89ua6rOIp
M5fH3nwaCDMlQQ5XpbUn+bfJ4ld3JALX5Dq2tvUs2lr8kkL1tx2L9OL0McWZpr2TI0Aq8ZCOMu0o
SpSwepQMh+zSEw4QM7kMulIFbWGJtSScdSp58pdBWg+4dhe0Pi4Qo88ThqGPlKEBPER7hhgTVXjD
IM+gkRoAfColcFh7aCwd2UZQnpXcTkXjaZKGaUwHDjGmRM049YLqSt54az/jW6o0aFRTqVVt1BoV
F1vzSnY8y+6tcflPuulDVzX2OTFSu+JEjWmOjQi2GgCxnouIMxC5bLPIyawVao7kNWmtEXFNgwxW
mr1cV6+osSQ68HDVbztc4DYmoKyQ2bNe78Vq6t7KPi0lYdkU9bEic8BeIIWUa3/yViGOenyr4gjV
N3vJ0ChYwnYn5My+lxfOJ55tw44KFeG6AIA0s/OJT2y9BouMjeKVyzBz/Ia5bpNZn1s65OiaGTra
0UXxIuqRy6U76flBlIi7T9P4Av4Mch6m18HKcjubcX6tiRUzRjcodQHxsG3kBtYoFByL+tTyPngd
78MHDt+p2Nq+gyvmo0D9sv+P7snhsY7L9B7BEbOrU9afR1iL5i86qRHPqIiW6cqzLHOeUVNOU/Q2
k4Lt5jsDqbTl3FTP02RsXLB1uE3lcPCvJW/gKdsWHaJjHHBt07p47SJU+0P24/t//vAx+HFbgliq
+msh9Z5f8DWl8jNIIMrbJv11nYY+fU8/4SJQAqk+ohU9WDMPKvSV2nu8ghib97F0Sw/VVCuSTl7o
gwx/AKWjwdzrfAbLzwrV0sE9kV2qDUuiurPOGEhVkp7bejQqtyiwQLFbrOkOj4jXDbyP88o6tTnX
iIHVUBy5UEWdUqNadCm1qKSBd/opRtLW/RhErP5egVGo1+xAEF0TeRhH414Ea22MCp+yOM6xhsjq
VMmT3fWljlpVHP1SclopLbVFdaFxsGHUhoUJTxDWd5fYr7ror/0rOkTioQQfZE6F1/GCIqOZF0zX
1unEVL3keYwu5vxAnGkcgW1aiyIKOKKaNUL3Jro6ayZp1m3mVatLgOXrEEAnKaGUQ1i4FDpp+9et
xndZEXyKy5kh38zwoKunSji147g5LPhma+78DoOiSEE/elqY/6USD8nxpgVCJvXaIhJRL2xjztBV
oOB/L459l1V1qCgP1NQRQyL1EiGtkipuzc4aJviwRBvKwHIGpnXSri7vjRMvtVZkiXxTi6xVAOeV
dz1B5vM7VZ5KtSEGyPYCGweeFVwX6plLRkpzE3JSkyBL8gvVDQTfWUpGJc2ppndF/jc4bsLARXuS
9ZHMS5cg5wIy9Fq7Lm1WubdmFvXnkxhZ0oq82F34FERdzkxUvOdKEe+PaTficRQcwLklmXaj9CLu
R1nwmkZ3Fo6IMR7l6UkiMHZmedK6xStuvyfJs+7JcQujbbdvTYUrqDV3RM3vFsuWp33D9zeJu99O
5upY+4vL4ZVyXSZ5oC3vRJsE59wbktxV+7xF/eobPnfrTx28Pjo8Ptl5c7JlqmHrwmssmlv2+ft5
pi9lYwc7kXbujhNU+2wtG85y2nAJMdfux6/fdk/Y+wQqxKBwuWW7Fg2EjQ304I79iQovdbKi4Szj
PHnGJhPLVTNnRmPNmTkhNZhNdJM79sYTYscq1Cpn4pFF7Aed3XWh3uH+rVBudGmprCPJKIy4w3t1
+PZE7DwWKe/YF9eWe9t9hozMfbZ9cJFNKRapnce5W+qAJyVlfyfZDGkV7ooDfyaSy9EWWmkqtBly
VuJN2do8bdQl50OHHtuU8Y+dumPtJcSTbwbrEsc5NlsNnHXeJaCma38uAV5zUpo2p+t/bufr7Uqw
HM2eo9qm60UtLHuLkF8mdh3FT9jkdsUSa/OfeKo95SpyLA59qfZgK8eOaIPbRQ9JojhTB8kXOlkK
CEktLizvwGq4iC0tpnAkQMMLdrSkUTcKiAsAlnX76Zojidm7OeZBrnJUXL+NzzWnlOvRUgW+Cjet
01uLwn4eMb4Sn1gQOCUdzgVO6XHcytYocGsyTeuIJOdasKg7uDDbtAlt+lLrDGPX+U6ppp23ykm/
q5mnZdpF9u+Sau2CWZz7G659ldzf66v0KY3CSW5dIIybCNx56rzmJP9mjvaWS2MfvuVv9If+76vt
txJY3lHdk+Lv3e2DV4Jmc/eZEvaq9xynuSLMuSqXblaRrF33WomdvmTU1vLWVlnUa4g9WV4ySeyl
Xh+dZYM4deVjB3E2HdFBMrsu1xS4dSB4ui6saStCUwTLO7vwI+OBBCWQqKjb4m0jzItz2lgcpYKV
5nm+PxE3wzsgGzu1vQRYvo8MdZKqudKVuv6xkSY4NzPHWbGJlnr/JaPlYRjb5cVeXqKz9F49adDi
M7CtSNu/S8PUO1zaWQdeETBU3AUu9Xv7/hSgIACyO/d4dxYlkrdD7yw4csjzW7ouXGJBLRPIwmBa
Qn2xuLNgZuUHW0ONa5zeqJ4Gv01QJdSptaYvo1jQNyKKTt7kiEDCVWHY4MsxUou4aAWyr6XRoB3o
Mwc5jZNM6QxTiGXEkvGVjs7+gYDy23xWmnl0lcN4WetVyEGpmXjqth3v2/EY/cyH0wBYpyZnP3JR
BPd+atN/m0Wkljjxclj+XFy+NMixGXw/TICD7qwnuX0xABJ7BtGViDJNTaOQkQMpr4hYSnoOfDmP
J/KDNB3U5BRAN3bYu8zb6bhDeaqMXOfGGZTSCxSd0w8L8vIkN/V6iCHP9VYScpJSrzJHXpxkUa/5
Tb3ug+YxStZ1zb3mpV55MaXXfFGv/Ymz3P2aIfDQaQzEBFvv/9n56KRd6pdXdsJ292pH+qLB9Mco
em+7LthKUHBbMO2p2i12Sm8aPXvDXydP1S+CKDJHSQnD5ayJbKUwb58luhCvvQhj9hhOWLNGEd6d
o1+I7OMbOz6z+x2Pri6FLneH7OWeJwUnzSMtyB5JJ0Rf2B7Iy2NAG9udyX3u9ik9asPOojccUncj
OXOLQwuh4YzkowDSC7ugDIc0uUnOOjNbE9xq16SyR27dSXawK+w6QtWQczuLJqVL4uqth4QnFzOS
zfXt6CrtnbjX4+LqgvMTcbAxdCfOK8mUfUosI5JEP1yKXnQajcN2bHaZ6zZUjwdVfisjX5Lm2Cli
VrNV1spbM4b3qx+tUsJ2VbFSxCOnmjf4CJtUvWZLg5Bhtr1GOV3XD8qx/GYmhxRD84tVAU9CadHw
WvMdbKCmqzpl+La+M4c7SquJ6vUoNh2z5leZIp7fu+caC0rr8L4Zf3QX1UjyjPBFdwT7HjL+O3ra
UhMkrxX7tlkzT4FC1V1o83JsLTU4z/f2VXNvnpd2lyZf/MShM5oLl9bqPNh9UyRAk2b3QAPoeVVJ
pmdC9NpzbTVddJTgbDYcxldGjeXGZkX+YB245XGwjIDRuXuIprfpqdd2yu95bilH9k5h9sE5CGTr
2rK9Jhk83vlP3+SGXwSpUm6aF2D1C1cm+GPtyx/r9OcfG19o37jSN3fTwVQZgzpmfh0ZUU2h6WJ7
b4FSYu830S/dHRKDgVuwfs4yHUzA8WTJLNPlD43RVcyodzPzLbC58ikVky/HIZRvWKBY3sGcWGPe
E/pRQtkp5uxa4Xgr3hmR9CddycGvOVe3K+pgsaLsZbu8xgNGpR0FZHwNA8a9rGqCmq6WwcZcM/sk
vUaggoakpY0OxJjhx+ZE58mg1/kerviGmODqLCsuBTVUHG+qteKsL/EX1cYs1iCIf87A0khFyC+h
Jazxis4v9JwnKCSbOYcDlzc4rvXAYq/U2Ct86llHQgt7040bNhSRNSpNx5UNTJpCUFwvK9ST8gWU
Nh+XXBUKg9xcLO4vhQuDwhdWVgut1WqihU7qGwnH1Yt/q7u+NR+/6N8Zii+cqbySZjzF8I2xgBTg
TGu8PqvPZWW6yK9yC9YV1e0L8+bbbMCteRm+W+VUZ5JgdikpJZffi1YBtd7c8r41WFzWho9QxZfK
4beS82PtqU7CQTA35HCWkEt+rrDerIaKWbwyCSDrDsPiOwXt2/QnGvbPK4b9P+2AfOUREf+gW56P
GucsgwYlv6yl7vY63kdfYEzdDa5sbA3VNMtaJVXza/6Vlid8RCUrfNxnE3haL0K/YImZCfcyzuk3
k9UT0/V2PMfb0fp//twgCt9lO1TvWrHzvq+rVfApNZdAYXYeDYyihPSpUprqLBE1wWojO2/2RBbh
y24RuK3SPJ1yHhmUJ1uxrnrbN+qkKyU/u+0C6VaMV9x2aalWHF+3bbN5K42fWTGr+rC6G/T9/U4f
B6VKYo/hdMqLbKsdH/1igkriTKeepZ+mYZo7+eLhrs+CYBZBGhglkjI+6p9N4j6pcWwxUwXOIwdi
oGjxxL8snXHkTQAfV8kMe6mWZK69lJRr9eVYpIWTCsN5B52PY4nosyKAk9S+5LWsvZGBa7Veyxy6
q/vT2fNq06ToVLcIO7hdPgsH5Lzj/EqTRXYT18/np7B3Fx/H8s1tSoH+RZtukZlwLuR/rsWL4529
V/uf3nb3jy2cbXe80mpRWRj+9Wjn5GWVYHM4W32WQa/9tPSTUxALP0WTiy1AdI3Ru0dvJckdUTnY
E2dMU+7sfAAiwnTmLCaqIHN0/UvZcyVUL3eO93yU09lTjSQ9DXRDBJfgmngcXm2vrTcCNt9R8zEX
Eo/k7XHCKeqI/KytK87mT0cFZTF0aoIRzkemn8QE9qm5mcrG0LEMMHhoko7lZ7MeSG+PuDNSMISj
jHOtSPaBx+rFMxzKsyicdqzBxIF2tKtOZ2EaEvGJ4AYEg76fDH29jpzQIQCBYj8XdUkyFZEp9iJF
8sMqbiDLQzgRbkHLBkOTJ/KgGOZobJfFvUMPBfxgxApQliOVBFmE5HGaTHBVA8kkTWCLTVJWJdw7
o+nZNdqL12Q85jgyZKJ5F0821j/Z9+gYvSadZVZYynxbF+EN6y+Hw13u2+/Oxu2A/iluM7kPuCeK
iRNfd804OQs+Nyjiit0GekZfVpz64bW/i6UxDccvemymWVsvzIavZRs0EaajMZCSNRN4tsbIGGZE
CToAgfoFbl6EGOOE0wzR7OnLIMZFJK8Z0EDOXqnPSHHItLd+amwdlZ/ZX8LbOHVNIZunNq2Vxnus
ylgc6F+HV621TvE1nrRkvh1lnD+aUqnjJYaE+oenWtdgQYmt3noAgsHHO6+JJY3icWy9HsR5Kk/0
vPgf1kDNeOS/raxNGDxKuPIf8iDTmkjxWna7CubMkEfwTeCaQHIKttgjROc7cg6sdvWV40gCR6Df
f0kEPvXzM0gzJJ40eOINY+ZFOVQd3gb2nmv2GI5Y+NFd+j1oHh0NkG+n3bMudwBleiBB4zGwQQ7t
M76JXt/kOkAZDRqmGjPFl//oHuzuvBIy81SFPXH67hRTlfyfy/DmNCLojBmPS5jxoA4zal80Z8C8
6qLPegV97NnpEDoWNy8uEtUPbrMWq2E4qWK9/WY9EMQGYadBAhBC6EbKPNBYbdHivnvG8VdB3TsO
PhMya3OSBGxraOwIzVkUHIu6oEfTacVtCjbCYguYljFI92kxCHmJA4l7LUvT7zTlLsnTgTqkrU7j
QZTVkOw59hesOMzu94txSBrTtv/38ZUgiP/3v2/dI1H3SK/Si116lGVrq+ubJPrsgQMEkRZmt9+e
PPcfu/DM2pLkXbMqvFNcSMrZKykfRQ/aKwu4sAHi/t7nA3PKZanc54OQjt5EalKtCF7pZ5hrkHCM
q55vgXamZTzpIzxlkocjgayfm2kFOZhygCeyyNJqTv535R5HJvTmNsOrCUlrcifaSs+LWNRO5fMm
v98jertFes8WqleOe6MIPvrHUkTSU9rEVVRYbavKq5f0sP5dCMdpePkqOVXVFM06QMSzZYx8PaX8
CgmZe/Q+57RaLlBjFD57ysh7VhnBMEz9BO0EdAqfCR2RAWyXoHAio891VIG4eNcPqFbPMIOcT5XR
miSKNqYPBDjlCOYiPYbwKV87RYj6fybZaSXKGalPoV1QWy4AT4e2bIQzGgebKMSZiMbmC3ZK/iZC
zYTUVnYPkvJjSPdDUkI/8joN36fT4OvDYE9FA1clsrErTZO9WmJf98I8cqQt7ZYj6/uOxNgjXZ5N
6WeXVglzPW3cYc/VVCsMOkWKD6vmoIYHsMhgk/9ML70kvrTY4kYXl5xwCv9R7WPNOQ0CdRzlkrgg
gbDI+iDXFjT67jC+ItzgSHs6NCQKD/lVkh8zt/RkXfE8M//FxeOK6dWVj6vuKVInlooaVkuRf+Wu
tL4b/nR0XcYCj9rutt5mIb5in/l2YFfkJ47YaLaMpHAMsaklhWGAwkQjlcHsdnCSEHUmYWKWEzte
o0M8lr/thcK3fcSehKTifJrGU6aBZiis1o+RqPWaPv7r1/5gQHSPtot4tqHZK8PZxHjInk78nem5
RmewkbG9dGq+nUgoBclI5hGtD7winSevwl40qoQLutTMAHHCvOUdG+NN3GYw64sVrpC4W9EVMkgg
+s2CgI4YFaQUNDRoWNejWc491gXv6GFLQwBb5rtsAC13WzYw652VNQxmaiWbqB1lySRaeduMcM6i
aodeetvKcSbaSC+wTQDYzL4uWaOGf1NSJSfSf5n7pIxiqa80Puz0ycThPKt4RtITOE3e4PPMQLit
OFE28J+twnTKOQkBpvSztpU25uBcbPrGDTXiC0fUhq3WFNVtuYau3aVOgbk3F41tDiL2ArxNAqYb
4w9ZWjA2b8OUOIFzsVdZGA+2ll+UV6A2nHHW3K4tftEZpPgVylTd9FFp1OfLfNqXz1LUyVjyPxs3
2eIiA5QDdRfYwPN5V3LtawhzmaJ0Pp27XSdmEWhhHhW2XOeGcHEal5t9zOROsWNLX3GGnYm+b8yk
nlWwLEGPNiPXxqVP4ONK8p6je/VC7YNgrcvKXwzcGC1QlR1XILDusf3MhsYEfC8L071jTgBFztnu
BulmMfiMtsjUy2FDghQRDjWLLOxMQ8ghTOfnU9osw6I3iURasgEVe/yZ/1XBj9a3+a74oS/S4tv5
Q//37Ro1YC+PUNy5DFrCmbl+jebySBnBgd03eRvHQlmMYSYz/v1ZUp9FqcFv9Y1QRMqdYmEWSYIl
oo9vPTTdyXDvI8RHh7imkY8J0Tv/msHjpOGGfztJe7xMXWwiIRPpupxWILOpmrgWWhAPqGFDTo1Z
PjuzA9gyNEgeFPsmkXDRCAc960Xk+44y3eDFxhUOCZpc7zkT03YWDyKdI83YyWgmNDjUpyE0oyGC
Igz1EgIK0kmNomHO5IxTp0oQv5igDfYW3L5h+YWeVpXrzzW4bbCTK75/T3aNonTx8Jp5NP3ZS8AK
HaGlLmSnkFwQtGPFo1K8jm1jpaS5YB0t2egQXyw3jyXGhftfrUwmnDKNcuQaM8BMDHjZWiHykZGP
720XIrFvmHdtrh/CfamV/EHsANkHWtYPoFsfUrFT0IOpjwe+fuDPNMCAmnrtZb4GvhEupd6ez85z
vlMH0hfZH5AIHWRRPJ4TTqUpH+taV756prDD3DRVtPlec70EOb9xru+Y6Ou5fofb6r3DN/sVe4j7
7RvBb9fIWS/gFLRSFtowCiKl7EWgeax4K9zm9f+2MTpVipgPahyqceViF1XOLu+yytQIP/dYhGyh
QUWXhv4qRCBt6xja+2uvn5H+zC+9foaM3gvcpap2rIrE+lxu2LdEF6yRW1+k4bUcF5BDSYUCIqWN
iRzFWwaJYwWRgGDaV1QLyQzAiCQooC55B3pSX6oD1Gi+pW4u9rpg8LXDgxBULgnbqc0T31mSWLgz
Xyz2lmPYPXq7teRKgyZXudTQ91e3At51MjxIJpWS65VqsXh0o7x2m/Ws0AEl4YfWfyVP5LBKkgi+
QkPoHF+QwQ5buC0vdiOswH+2s/uLenukTl7ud/fVybtD9fzg1T6CZt+edA/26NHLg656fvhqb/94
if42l6JBzWfkuNPbNbLrrd83aza+KVHEjklOAR8FztwICe7W/ZQTq4B8vjk8oQ4RSjubIgqmcMLR
bQgWp9rAo6PdW/dk9DcI49TNKbYfAiOKjwXlHCXaV30Mv2+bnuTWHek0JrQe1TwmN2UmWeIF/6ew
DbHs6/tSYRlOLiZ2dujCaOprNwquvkGQUtT9VI37GUcSdX6DPUS/j6zAvzUanNXSGqmlm26eTP2T
NJxoF8F6g3Z0RUdzdeX/BVBLAwQUAAAACADqgRddP6Samm8MAADLHAAAJAAAAEFBUFMtQnVpbGRl
ci1GaWxlcy9SRUFELU1FLUZJUlNULnR4dKVZXW/jNhZ9168gBig2WdjKTKdfm20LKLEn404SG7Gz
6QB5oSXa5lgWVZGKx8Civ33PvaRkOXF2F6hfEkvk5f0891z6l1/+yicSSTKZipOkyCqjM/x/Kvpi
Xus8EztTV8JsC5FMPglTiAddZGZro7904C9R9HH8IGZjcT8ditEs6nc/0btYTGon3EpbsTB5piqx
XalKPeEf6CNyvVZQcGDSeqMKZwWt04WKIyHEZyzIjLgdz0ShVCYuzx+FLNiQg+dJttGFtq6SzlS8
c7ZSwqaVLp3YmmpthYESC1MJ7azKF14HfKHjrFwo4Yx3Uhx9G4vRgo+QeaVkthMr+aSEFFYvC10s
xVrtxKIyGzwqYYg2tfV7eyI15Y6OvxjPPsKMXMGeQhRmex7RY/pIWdo+RFioquIva9u8aJ+VlSlV
5bSyUTBlJ5awdvj7jNx8QUf1KcrxXDr4jtygC6szWLFStIVe9nmdqvofWA3v+70atOSx+SL+3e8/
l9t+fsY78kaa63TNgTzYNhtOZ/0Po7vpjLYdvLobJoObYbxym/zg+QsXdE76OLwbHiw+4pbjix/x
4KXhj+3iXHEYc1Mo9sJJiDLqpCTHbRonHvHefCc2yC+5Vr3GxyG7MuVUirR1K/iMcnNjnpT18pqc
wynxafQ+RpbX81z12ZPnlCYHLo++i0UCNZcyR8o4nULbslSysrGYed8rZFix0NVGOo0CnpuvrE/h
g0NqvRmJZFkp9SbmGpjXzmEhVN9ZkWkrcX4m6sLpnMVBApUADlurLA4CBkg244IccQILhjbtCfyl
Lb+fCvUVZSS22q3IRM59FAZvH7lGaUIYKvOdqOoijr6HcYXdouwRAPFHrSyZcC7KFX3Hnp7YSpeu
/L84a27cKo5+iMUnRSVYZDnOOKczkPKGq3CnkP+/chR18QT4oJKU1qLkMxyTIlqSF8LEFLXsgo19
lkn1yUaI8e2Ql0EWHL+iIgcepCtjrDq6YTr81/AuuebkpF1SFPVmDkjJAGi2dcE/RRni5rN0mtz4
g0jj2mI1pcchiNjGz94xW53nolILrPYy6FVdZrCFcYrzbs0esgRujO+ND3oexoB00iK+XoBHQWFV
KYGXKg9gRnLJwL/ZdjubnuB8swhQWamN8nb2hDUix/6KwmvpgMZ3cfRjLB6kdj4Fka7wCBaJVBaC
aki8f9v/x1tUVFE71ApVDfpQkRuZMbZYShsUwdVFHP0EUZTgpDHl8ACx4pznJtak2ivYCMkkL/Q5
Mfxa5kASZGCpCs5P6BhFUXIxvp+JB0ITNDBxcT+6HkwP+1jbzz5TD8XRPd9NyfOkPymUmyXgZUta
Ur0R8nfaHg7yBUmdOHQhal5W/Pn+LUwlJwNTuARsKVH82C+bnklhjiDrRJ6KbaUd1XFbgAftrydO
5qcIqVIksTBFf1gskZSrKF0h4CkiZntirlKJlBJXlcwgqTHht8EnMUehrMk5hGE99uFJespdxu5Q
UxnVxrhQg0oDT8/EAPhJMHImroxZQhi/aI+IaBNgq6rq0rU5TgduTQ1X1CXFXfz5beOEL3WxDs4K
GOsqgH6P/IGkpCaGmIJXdJxLT9C3v7keXybXyWQySGbJN497IKf3wF/wh3sL+x8nwGGdPlvwHS/o
PGOvqDy3XEbblUZoqCaRi6UHTKrA9huilenFAtVRuMjr1fP1GYKoKedQb9JzEg5y6K2ojEzl6CUk
Tha7yOnNPiyF+uoriNHA6k0JKZVqcgnemprzDodi8XGXVPnO1kZN5qheT4z6DE/B019qlGrbwcQK
LXMHOKhQfGajPGmyEuwMjeqjQqZsI4S4KuSmK7PHGEMCLL1APllTUKE9fExm4vP4HvU6HDwjin8X
P3zXn8P6plrfvSUkfPcOb5I5pbkvE85sdLK1rxK8ffcDPb9LbnBSajawOEMwTn6ip0EftsvmBu3n
lOSh8gsUQoH+gYZaoIOjF+HF7fiwmESllytnwxtPqcXU1Zk2cJzHRKCex3ICnDz3ayd01HSF5CHf
Ozyn9Qt2yuTSpwEhNn1HcrRUXHR3fh+/81AXorNQAAcCTFGaykNAZ/WPZJOBhKYLOGPylnRTKlXo
uYilbeCnLjgrgdO3oesxtwsKwyIS2KhG8UPT+yxGN5Px3Sy5ncGi2cehmI6ubke3V+LT8PNxzOxG
uVPVviHDBVsTqPJxFA+c9RXS+HPfA3GHnEevsOmwnNyzb5AWpDCjXhY6ZUsnj38o2NxLhVxKXRBM
Iey5ST0hQzqgjDU6JPdnpu6W0oTRVDxpqylqDThAWrTSWUb97TXuyY2WUYQ1TF2N2ECqYra/iXxg
fVvmKUZ6xrEBsobeSRsbtICSkvo0Fk8uexGRrOD9DdXIHLyDKB0JYaWl80Vc5h6tGIqQZi+mkLlC
0St/Vh0660Vy+cnPQvcTMR3fDH2PRbedjgZDZM9oKj6MrwfDOyxOeHryR+aaIIirZD/Z+Ml2j6Uc
C1YVlkYDD59dvIU3gAi51JsOYPTwzBvja5G5Jk14EX3PGB4XUue9Fn0DgVwS9COVNsC/wkEzBgAg
N+kxV1GllqrgwGckkrDoiRnhnCjCztBMG12SiR2nQ0UyFwjpuBDMgrsbZEvM0xcgEoHX40m3ve77
brMcZHsjidVzKldU4O0rH29gI2KLZhkNmZYvaldXwaueUYqb++mMcoCqCZoz1yUXNMS1GY2jHMwY
5vdaUOzwVFKhAb09WxXkDf7uMG8Rq+CmyhyAB2zsqotmnw81M0dMbsZSafs6V87hCzMI1A7V+I4m
ix2T5ZVhVO04mDorWUNUkVgqSeGSygyXn10RPaZ6IYCbzpLPhGVIV+AQWMTwCKRFH1gvQDFXGsH+
C2yi3DkGQYQwiCl3cTakKahnoBe4PbFLqAdFu40g2oBEUxu4HT4cMNAXI8PxUEQm3L5UNMlZVoMP
ZtZV+G6ZdWbVF7yasC9u8siXO07s03WJ3ZeqxQkpjawZK7JAI+GZ2DOp3+STjCDAAjh74VnbYsFD
UaQOkLLxXJFfM4T1fV9jRkzURKd1Lit/YhDnibWv4GC+9TXJlW8DctbO0CCdEqDGz6lwo0p4PMnr
JQARNaTaeSkKBjqiJL6nxmJq6HKp8PpUUluOVKX+qDXBdHEYSSBVTmQH/mvYvL/copgANcJAFZ08
Ix+toTx22qbB8KGZSTnRhK4qgOKTBB1l5tb3lFnbcJOwAZRlfYzVzVhCtocDCF/5ko6oTXyK2vgw
uh5ORXI7CJB9ZELi9n7Y5EjQWvFFSdMXAZ1zqMd9/bVLp4PsC3dOneukg55MEa5qpnC07LU7IL6L
8DRH5Za84W+EiHD7S6FkQeOsbC7z4CTbXMG0ZUqea1kJH8VF1/8Z0n+NZbluZnTsi15lLfvhsS+4
SWLsvJ9Er9IWv7692jjYFI1eow7PPVzad3uvsY7MJpgkY6WvLkyxsfvaCQXPtcZT11z6Ub67ur/k
Cmk2LWpgTSgapDM6DhYPRtPL62R0g0Z/IJtldi68Go9xiT8eRJngoieuuj0HKEFBaG+6Dzdwle0R
yE+UDVp2SSAztOfxFeNbMbm/m4ynQz8iMRIzRyCM9XlEpcq0qbmug2SmTkS9uteL1J0D0kZMJ/7f
m8aGLPuZDHrCpQTTxGzoWSerz5sJ8qXUWFx4dsYrSIkGWnqCeomwRASkJ2AI9dF+Fh3LTbbKdqZD
6Bf4WvfmIxp9YP4HxofuejUGkDzcjW+vXhsYMETdoZfsc45AqkW5eU4+3vJcEmPpFBPfsbI/TGhH
wGwY06AaRqYyhJBE3BgcArsAOhsPngv91XO3xmd89Jt9er4J10tv9gn4Jlhs/0uAma/XBQ8roY8K
vnEdz5oAvnB/L9yRMeXNGqLLfCdXAYcavK0LnGK7xJUyki59S8Y9HyamVhSYfWV2YhFN0dAOaxb5
DCK1wtx57o9rCDgzqwqpmEUblVEzhYZPOuX8pV9XfALjP1qlaTRPpgLEn8llgaDIqkKLosSjtBRr
xNUbTKyFSAz2om+ifdLdidv/jFWB1Ps7RrRyqBbJNFV0yQSpuZZznWuI3YIoWI47TSThrrq9QWzu
ZFx7U2mdKlHyVZN/ZG2UhasUP+aRcsSm20CY+Re6Q6AaBStZOVfa87Mz6RMD0YxJGhZSa47RXcOw
VDOv1ZybGTPqwtY5pcSs4zp/Z+TJSriYMYuFTjVcfXk9Cr07U7R8zvcQ/1uDM1Wc0e2tdWdTz6jv
ywTLziCQfeR/tfmLvwz+B1BLAQIUAxQAAAAIAOqBF11eCHJmyQMAAJAJAAAOAAAAAAAAAAAAAACk
gQAAAABCdWlsZC1BQVBTLmJhdFBLAQIUAxQAAAAIAOqBF12KFEzhohAAAKwxAAALAAAAAAAAAAAA
AACkgfUDAABSRUFETUUuaHRtbFBLAQIUAxQAAAAIAOqBF10c5DJvTAEAAMUCAAAOAAAAAAAAAAAA
AACkgcAUAABURVNULUZJUlNULmJhdFBLAQIUAxQAAAAIAOqBF10AAPYSRFwAAPIwAQAhAAAAAAAA
AAAAAACkgTgWAABBQVBTLUJ1aWxkZXItRmlsZXMvQnVpbGQtQUFQUy5wczFQSwECFAMUAAAACADq
gRddP6Samm8MAADLHAAAJAAAAAAAAAAAAAAApIG7cgAAQUFQUy1CdWlsZGVyLUZpbGVzL1JFQUQt
TUUtRklSU1QudHh0UEsFBgAAAAAFAAUAUgEAAGx/AAAAAA==
