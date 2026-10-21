# FluentCleaner Classic Portable — Windows validation checklist

Perform these tests manually after the GitHub Actions build succeeds. Back up important files and avoid deleting anything during portability testing.

1. **First run:** Extract the built artifact to a writable folder. Start `FluentCleanerPortable.exe`. Verify it opens and shows portable mode in its About screen.
2. **Settings isolation:** Change a harmless setting (such as window position or language). Exit Classic. Confirm `Data/Settings/settings.json` exists and contains the change. Reopen and check it persisted.
3. **No host settings:** Before first launch, note whether `%APPDATA%\FluentCleaner\settings.json` exists, and its last-modified time. After exit, confirm it wasn't created or modified by this portable run. Do not delete any existing host settings.
4. **No cleanup execution:** Click Analyze only, inspect results. Do NOT press Run Cleaner during these tests, especially for cookies, browsers, registry, developer tools or Winapp3.
5. **Custom rules:** Add a harmless custom rule without running it. Exit. Confirm `Data/Custom` contains the custom file. Reopen and check it is visible. (If file deletion/renaming behaves unexpectedly, report it; this launcher does not automatically erase `Data` files.)
6. **Admin run:** Close, right-click the **root launcher** → Run as administrator. Repeat setting save/check. Administrator runs must not automatically clean or create scheduled tasks.
7. **Schedule avoidance:** Check Task Scheduler for `FluentCleaner AutoClean` **only if you may already have used Scheduler**. Do not enable the Scheduler from this portable version. Do not delete someone else's task.
8. **Automatic CLI logs:** Check `%APPDATA%\FluentCleaner\auto.log` timestamp, if present. Opening and closing the app normally should not run `/AUTO`; a previously existing log is not proof that this build wrote it.
9. **Upgrade:** Back up `Data`. Replace only `App/`, `Other/`, and the root `.exe` with files from a newer artifact; keep `Data/`. Confirm settings and custom rules survive.
10. **Relocate:** Copy the entire portable folder to another writable drive or PC. Normal non-admin run should preserve program settings. Paths to external files stored in settings may require correction after drive-letter changes.
11. **Interrupted close:** Change a harmless setting, then terminate the application process; confirm last fully written settings are backed up. Do not forcibly kill the portable launcher just after changing a setting if you plan to replace App immediately.

If you observe new files in Windows AppData, ProgramData, IsolatedStorage or registry, capture their path and timestamp. Do **not** delete entire parent folders; they can be shared by other programs.

### PortableApps Menu
- [ ] Extract inner ZIP directly to the directory containing PortableApps.com (not one directory deeper)
- [ ] App/AppInfo/appinfo.ini exists beside appicon.ico, PNG icon variants exist
- [ ] Root launcher is exactly FluentCleanerPortable/FluentCleanerPortable.exe
- [ ] PortableApps.com Platform: Apps > Refresh App Icons; FluentCleaner Classic Portable listed under Utilities
- [ ] With portable app closed, verify Data/Settings/settings.json is unchanged by rebuilding
