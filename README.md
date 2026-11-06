# AAPS Windows Builder

**Build a signed AndroidAPS (AAPS) APK on Windows by double-clicking one file.**

AAPS must be compiled by the person who uses it — there is no app store download.
The [official CLI build instructions](https://androidaps.readthedocs.io/en/latest/SettingUpAaps/CLIBuild.html)
assume you are comfortable installing a JDK, the Android SDK, Git, and running
Gradle. This project automates all of it for someone who is not.

> **AAPS is not an approved medical device.** This tool only compiles it.
> Read [DISCLAIMER.md](DISCLAIMER.md) before using anything here.

---

## Quick start

1. Download **[START-HERE.bat](START-HERE.bat)**
2. Save it to your Desktop or Documents and double-click it
3. It unpacks itself, opens the instructions, and waits
4. Read the instructions, then double-click `Build-AAPS.bat`

The first run takes roughly 30–90 minutes and downloads several GB. Later runs
are much faster.

---

## What it does

- Downloads a **private copy of Java, Git and the Android SDK** into its own folder
- Clones the AAPS source from [nightscout/AndroidAPS](https://github.com/nightscout/AndroidAPS)
- **Reads the source** to determine which JDK, SDK platform and build-tools *that
  specific AAPS version* requires, then fetches exactly those
- Creates or reuses your **signing keystore**, including multi-key keystores and
  keys with their own password
- Builds and signs the **phone APK, the Wear OS APK, or both**
- Leaves the finished APK next to the launcher and opens the folder

## What it does not do

- **Nothing is installed into Windows.** No JDK, no SDK, no PATH changes, no registry.
- **No Administrator rights.** Ever.
- **Android Studio is never used** — this is the command-line build. Android Studio
  version numbers in the AAPS docs are irrelevant here.

---

## Requirements

| | |
|---|---|
| OS | 64-bit Windows 10 or 11 |
| Disk | ~30 GB free |
| RAM | 16 GB recommended; 8 GB works, slower |
| Network | Access to `github.com`, `api.adoptium.net`, `dl.google.com` |
| PowerShell | Any. If the PC only has Windows PowerShell 5.1, a portable PowerShell 7 is fetched automatically |

Run **`TEST-FIRST.bat`** to check a machine in about a minute without building anything.

---

## The signing key — read this

The build produces two files next to `Build-AAPS.bat`:

```
aaps-keystore.jks       your signing key
keystore.properties     its password
```

**Back both up somewhere outside the folder.** A copy that lives only inside the
AAPS folder is not a backup.

Every future AAPS update **must be signed with the same key**. If it is lost,
Android refuses to install the update over your existing AAPS, and the only way
forward is to uninstall — losing all settings and history. The key cannot be
regenerated or recovered by anyone.

Anyone holding both files can sign apps as you, so do not share them.

---

## Repository layout

```
START-HERE.bat          self-extracting distributable (this is what users download)
src/
  Build-AAPS.ps1        the build engine
  Build-AAPS.bat        launcher
  TEST-FIRST.bat        one-minute machine check
  README.html           end-user instructions
  READ-ME-FIRST.txt     plain-text instructions
tools/
  build-sfx.py          regenerates START-HERE.bat from src/
```

`START-HERE.bat` is a plain text batch file with the payload appended as base64.
Deliberately **not** a self-extracting `.exe`: an unsigned executable that
downloads and runs things triggers SmartScreen's full-screen block and antivirus
false positives, which is far more alarming to a non-technical user than a
batch file.

To rebuild it after changing anything in `src/`:

```
python tools/build-sfx.py
```

---

## Notable behaviour

- **Dependency versions are read from the AAPS source at build time**, not hard-coded,
  so an upstream JDK or SDK bump is picked up automatically.
- **Android SDK platform package names are resolved from Google's listing.**
  From API 37 on, the package is `platforms;android-37.0` (then `.1`, `.2`, …).
  There is no `platforms;android-37`, and asking for that name fails. The script
  picks the plain name when it exists, otherwise the `.0` release, otherwise the
  newest stable minor. An old install marker that recorded the missing name is
  not trusted.
- **AAPS pins `org.gradle.workers.max=12`** regardless of your CPU. This overrides it
  with your real core count, and scales heap and worker count to available RAM.
- **A workspace is chosen automatically** — the build needs a path that is writable
  without admin, free of non-English characters (Gradle and the JDK break on them),
  and not synced to OneDrive/Dropbox. Your APK and key still land in the visible folder.
- **Signing is staged through an ASCII path** because Java resolves filenames via the
  Windows ANSI code page and cannot open non-English paths on some locales.
- **If Google's `sdkmanager` cannot reach the network** — commonly because antivirus
  HTTPS inspection breaks Java's certificate validation while Windows' own network
  stack works — the SDK packages are downloaded directly instead.

## Troubleshooting

1. Run `TEST-FIRST.bat` and read the results.
2. Send `AAPS-Builder-Files\build-log.txt` to whoever is helping you.
3. Most problems clear by deleting `aaps-tools` and `AndroidAPS` inside
   `AAPS-Builder-Files` and running again. **Never delete `aaps-keystore.jks`.**

If the build appears frozen, the script now reports how long it has been silent
and lists the likely causes — usually antivirus scanning Gradle's output files.

---

## Credits

AAPS itself is developed by the [AndroidAPS project](https://github.com/nightscout/AndroidAPS).
This repository contains only a build wrapper and is not affiliated with, endorsed
by, or supported by that project.

## Licence

[MIT](LICENSE) for the build scripts in this repository. AAPS itself is licensed
separately by its own authors.
