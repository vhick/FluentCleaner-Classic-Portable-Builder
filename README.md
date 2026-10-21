# FluentCleaner Classic Portable Builder — v1.0

A standalone, **manual GitHub Actions builder** for the developer's official **FluentCleaner Classic** Windows release. Generates an extract-and-run package with a root `FluentCleanerPortable.exe` and `App/`, `Data/`, `Other/` directories. **No `.paf.exe` installer. No automatically triggered build.**

Official developer: https://github.com/builtbybel/FluentCleaner

## Critical difference from the Modern edition

**FluentCleaner Classic's UI and edition-specific implementation are currently CLOSED SOURCE.** Classic is freely distributed, and its shared engine and Modern edition are open source, but we cannot patch Classic's source to relocate all of its storage or remove the scheduler. See the developer's explanation: https://github.com/builtbybel/FluentCleaner/blob/main/FluentCleaner.Classic/WHY_CLASSIC_IS_CLOSED_SOURCE.md

This builder does NOT claim to make unsupported features fully portable. Instead, it packages the **original official Classic ZIP** and builds a small independently licensed portable launcher.

## Quick instructions — GitHub Desktop (beginner-friendly)

1. Create a **new GitHub repository** named `FluentCleaner-Classic-Portable-Builder` (not a fork of the developer's project).
2. Download/extract this builder ZIP.
3. Using GitHub Desktop, copy all files and folders from the extracted builder into the new repository. Include the **hidden `.github` folder**.
4. Commit and push.
5. In GitHub, go to **Actions** → **Build FluentCleaner Classic Portable (Manual)** → **Run workflow**.
6. Keep `release_tag` = `latest`, or enter the developer's official combined release tag (example `26.09.01`). This is **not** the Classic version string `1.18.250`.
7. Wait for a green checkmark. Download the **FluentCleanerClassicPortable-...** artifact and extract it anywhere writable.
8. Start **FluentCleanerPortable.exe** at the package root. Never start automatic cleaning from the launcher.

The workflow does not run on a schedule. New releases require another manual build.

## Resulting application layout

```
FluentCleanerPortable/
  FluentCleanerPortable.exe     <-- always open this file
  App/
    FluentCleaner/
      FluentCleaner.Classic.exe <-- developer's original executable
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
    AppInfo/FluentCleaner.ico  <-- extracted directly from official Classic EXE
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
