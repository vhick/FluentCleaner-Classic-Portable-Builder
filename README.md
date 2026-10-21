# FluentCleaner Classic Portable Builder — v1.4

A standalone, **manual GitHub Actions builder** for the developer's official **FluentCleaner Classic** Windows release. Generates an extract-and-run package with a root `FluentCleanerPortable.exe` and `App/`, `Data/`, `Other/` directories. **No `.paf.exe` installer. No automatically triggered build.**

Official developer: https://github.com/builtbybel/FluentCleaner

## Critical difference from the Modern edition

**FluentCleaner Classic's UI and edition-specific implementation are currently CLOSED SOURCE.** Classic is freely distributed, and its shared engine and Modern edition are open source, but we cannot patch Classic's source to relocate all of its storage or remove the scheduler. See the developer's explanation: https://github.com/builtbybel/FluentCleaner/blob/main/FluentCleaner.Classic/WHY_CLASSIC_IS_CLOSED_SOURCE.md

This builder does NOT claim to make unsupported features fully portable. Instead, it packages the **original official Classic ZIP** and builds a small independently licensed portable launcher.

## Quick instructions — GitHub Desktop (beginner-friendly)

1. Create a **new GitHub repository** named `FluentCleaner-Classic-Portable-Builder` (not a fork of the developer's project).
2. Download/extract this builder ZIP.
3. Using GitHub Desktop, copy all files and folders from the extracted builder into the new repository. Include the **hidden `.github` folder**.
4. Commit and push. The updated repository should now contain `scripts/build.ps1` and `launcher/FluentCleanerPortable.cs` from v1.4.
5. In GitHub, go to **Actions** → **Build FluentCleaner Classic Portable (Manual)** → **Run workflow**.
6. Keep `release_tag` = `latest`, or enter the developer's official combined release tag (example `26.09.01`). This is **not** the Classic version string `1.18.250`.
7. Wait for a green checkmark. Download the **FluentCleanerClassicPortable-...** artifact and extract it; this gives you an **inner** `FluentCleanerPortable-<version>.zip`.
8. Extract that inner ZIP into the folder containing `PortableApps.com` (for example `D:\PortableApps\`). The ZIP includes the parent `FluentCleanerPortable/` folder. Use **Apps > Refresh App Icons**. Start the new **FluentCleanerPortable.exe** at that package root.

**Important:** GitHub workflow and Windows GUI operation have not yet been validated for v1.4. If this run fails, share its new log. The `EXE files discovered` diagnostics will make further release-format problems easier to identify.

**v1.4 fix:** This release adds standards-based menu registration under `App/AppInfo/` (including `appinfo.ini` and icon PNGs generated from FluentCleaner's official ICO). It also packages the application into a ZIP that always includes the outer `FluentCleanerPortable/` folder. Both reduce PortableApps Menu recognition problems caused by misplaced metadata or extraction nesting. Earlier release-download, filename, and Windows encoding fixes are retained.

The workflow does not run on a schedule. New releases require another manual build.

## Resulting application layout

```
FluentCleanerPortable/
  FluentCleanerPortable.exe     <-- always open this file
  App/
    AppInfo/
      appinfo.ini               <-- PortableApps Menu metadata
      appicon.ico               <-- original multi-resolution icon
      appicon_16.png ... appicon_256.png
    FluentCleaner/
      FluentCleaner.Classic.exe <-- normal official executable
      (or FCleaner.exe if present in an older official release)
      Custom/                   <-- app's working custom rules
      (upstream DLLs, rules and translations)
      settings.json             <-- working copy created on launch
  Data/
    Settings/
      settings.json             <-- persistent backup (created on launch)
      supporter.json            <-- if Classic creates it
    Custom/                     <-- preserved custom cleaners
    Databases/                  <-- preserved Winapp2/Winapp3/Winappx when available
  Other/
    Source/                    <-- readable launcher and icon extraction code
    build-manifest.txt         <-- upstream URL, version and SHA256
  START-HERE.txt
```

### How the launcher works

- On first launch, creates `Data/Settings/settings.json` containing `{}` if no settings exist. This also creates the local `App/FluentCleaner/settings.json` that turns on Classic's **native portable mode**.
- Copies settings from `Data` to Classic's expected local path on every launch.
- During execution, backs up **valid JSON** to `Data` about once per second, reducing the chance of lost changes in a sudden shutdown. It makes a final backup after Classic exits.
- Preserves `supporter.json`, custom cleaners in `Custom`, and known root-level rule databases. These are the documented/local locations; **other potential user-created files need Windows verification**.
- Never deletes `Data`, Windows AppData, registry values or Windows scheduled tasks.
- Does not change `APPDATA`, `LOCALAPPDATA`, `TEMP`, `USERPROFILE` or `PATH`. A cleaner must still see actual Windows paths when scanning.
- Blocks passing command-line cleaning arguments to the root launcher.
- The user can use **Run as administrator** on the *root launcher* when absolutely needed, but should first review the cleaning rules.

### **Known limitation: built-in Scheduler / automatic CLI cleaning**

The Classic developer documents that automatic cleaning writes `%APPDATA%\FluentCleaner\auto.log` and that its GUI Scheduler registers a persistent Windows Task Scheduler entry named `FluentCleaner AutoClean` pointing at the **underlying Classic executable**, not the portable root launcher.

**Because Classic is not open source, we cannot prevent those behaviors inside the application by source patching.** This builder **does not enable or remove** scheduled tasks; you must **not enable Scheduler or run `/AUTO`**, even through the underlying executable. If an existing Windows task has already been created, inspect it in Windows Task Scheduler and disable/remove it **only after confirming that it is yours**. No automatic global cleanup is included.

The root launcher is intended for **manual Analyze → review → Run Cleaner** usage only. Never select broad rule sets, especially Winapp3, casually.

### Upgrades (keep Data)

Close the program. Build a new official Classic release from GitHub Actions. In your existing portable folder **replace only** `FluentCleanerPortable.exe`, `App/`, and `Other/`. Preserve your whole existing `Data/` directory. Next launch rehydrates Classic's local working configuration.

If a new Classic release changes its portable-mode storage paths or file formats, the builder may need revision. Check the `START-HERE.txt` file and test new versions before replacing a working build. Back up `Data/` first.

### Portability acceptance tests

See [docs/TEST-CHECKLIST.md](docs/TEST-CHECKLIST.md). Workflow validation **does not prove real-world zero-remnant portability**. In particular, do not describe it as fully isolated if you enable the app's scheduler, execute raw `/AUTO`, or discover other host-owned files.

### Sources and redistribution

FluentCleaner Classic is created and owned by builtbybel; the **upstream binaries** are downloaded from official GitHub releases by the workflow, **not bundled** into this build kit. Its Classic source is private; we do not redistribute modified proprietary code. The standalone launcher and scripts are MIT licensed (see `LICENSE-LAUNCHER.txt`). The original icon is read from the official executable during building. The official asset SHA-256 is recorded as an audit trail; **no claim of a separately published upstream checksum** is made.

## v1.3 Windows encoding regression fix (carried forward)

The GitHub Actions run on 2026-10-21 stopped during **Validate builder files**: two of the seven Python unit tests attempted to decode UTF-8 source files using Windows default `cp1252`, resulting in `UnicodeDecodeError`. No application packaging took place during that run. Version 1.3 introduced explicit UTF-8 reading and regression checks, and v1.4 retains them.

This is a builder-validation fix, not an upstream FluentCleaner application modification. The actual Windows compilation, portable launcher behavior, and any further build steps still require a successful GitHub Actions run.


## PortableApps.com Menu integration (v1.4)

The GitHub Actions artifact is a GitHub wrapper ZIP that contains **FluentCleanerPortable-<version>.zip**.
Unzip the GitHub artifact, then extract the **inner** portable ZIP straight into the folder that contains your existing `PortableApps.com` folder. For example:

```
D:\PortableApps\PortableApps.com\
D:\PortableApps\FluentCleanerPortable\FluentCleanerPortable.exe
D:\PortableApps\FluentCleanerPortable\App\AppInfo\appinfo.ini
D:\PortableApps\FluentCleanerPortable\App\AppInfo\appicon.ico
D:\PortableApps\FluentCleanerPortable\Data\
```

Then select **Apps > Refresh App Icons** in the PortableApps.com Platform. In the menu it should be shown as **FluentCleaner Classic Portable** under **Utilities**.

The original icon is extracted from the official Classic executable and rendered in standard PortableApps icon sizes. No generic icon is used. Do not place `AppInfo` under `Other` — `App\AppInfo\appinfo.ini` is required for standard PortableApps menu metadata.

For upgrades, do not overwrite or replace your `Data` folder. If Windows offers to merge during extraction, back up `Data` first and copy only the new root launcher, `App/`, and `Other/` folders.

This community package is compatible with menu discovery but is not endorsed or distributed by PortableApps.com. It uses .NET Framework 4.8 present on supported Windows systems.
