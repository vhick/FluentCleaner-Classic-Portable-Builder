// FluentCleanerPortable — native portable bootstrapper for .NET Framework 4.8.
// MIT-licensed builder launcher. FluentCleaner Classic is proprietary/freeware.
// Always run this ROOT executable. This launcher never starts cleaning automatically.
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Windows.Forms;
using System.Web.Script.Serialization;
using System.Collections.Generic;

internal static class FluentCleanerPortable
{
    static string root, app, data, exe;
    static string appSettings, dataSettings;

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            root = Path.GetDirectoryName(typeof(FluentCleanerPortable).Assembly.Location);
            app = Path.Combine(root, @"App\FluentCleaner");
            data = Path.Combine(root, "Data");
            exe = Path.Combine(app, "FCleaner.exe");
            appSettings = Path.Combine(app, "settings.json");
            dataSettings = Path.Combine(data, @"Settings\settings.json");
            if (args.Length == 1 && args[0].Equals("--self-test", StringComparison.OrdinalIgnoreCase))
                return (File.Exists(exe) && Directory.Exists(Path.Combine(root,"Other"))) ? 0 : 21;
            if (args.Length != 0)
            {
                Fail("This portable launcher only supports interactive use.\n\n" +
                     "Command-line cleaning (/AUTO, /CLEAN, /SHUTDOWN, etc.) is disabled " +
                     "to avoid accidental deletion and host AppData logs.\n\n" +
                     "Do not enable FluentCleaner's built-in scheduler: it creates a Windows scheduled task.");
                return 2;
            }
            if (!File.Exists(exe))
            {
                Fail("Missing App\\FluentCleaner\\FCleaner.exe.\n\n" +
                     "Extract the entire ZIP, then use the root FluentCleanerPortable.exe.");
                return 3;
            }
            string id = MutexId(root);
            bool created;
            using (Mutex mutex = new Mutex(true, @"Local\FluentCleanerPortable_" + id, out created))
            {
                if (!created)
                {
                    Fail("This FluentCleaner Portable folder is already running.\n\n" +
                         "Close it before starting another copy of the same folder.");
                    return 4;
                }
                try
                {
                    InitializeData();
                    // Original vendor program is launched with its normal Windows environment.
                    // Never redirect APPDATA/LOCALAPPDATA/HOME, as the cleaner needs these real paths.
                    ProcessStartInfo start = new ProcessStartInfo(exe);
                    start.UseShellExecute = false;
                    start.WorkingDirectory = app;
                    using (Process child = Process.Start(start))
                    {
                        if (child == null) throw new IOException("Windows could not start FluentCleaner Classic.");
                        // Keep a fresh validated JSON backup even if the program or system crashes.
                        // Never save partial JSON while Classic is in the middle of a write.
                        while (!child.WaitForExit(1200))
                        {
                            try { SaveSettings(false); }
                            catch (IOException) { /* Retry while the program is writing settings. */ }
                            catch (UnauthorizedAccessException) { /* Retry on next sync. */ }
                        }
                        // A small extra wait helps catch normal asynchronous settings writes on shutdown.
                        Thread.Sleep(350);
                        SaveSettings(false);
                        SaveOtherData();
                        return child.ExitCode;
                    }
                }
                finally
                {
                    // If startup or exit failed, keep any valid user settings we can recover.
                    try { SaveSettings(false); } catch { }
                    try { SaveOtherData(); } catch { }
                    mutex.ReleaseMutex();
                }
            }
        }
        catch (Exception ex)
        {
            Fail("Portable launch failed:\n\n" + ex.Message + "\n\n" +
                 "Your existing Data folder has not been deleted.");
            return 10;
        }
    }

    static string MutexId(string path)
    {
        using (SHA256 sha = SHA256.Create())
        {
            byte[] digest = sha.ComputeHash(Encoding.UTF8.GetBytes(Path.GetFullPath(path).ToUpperInvariant()));
            return BitConverter.ToString(digest, 0, 12).Replace("-", "");
        }
    }
    static void Fail(string msg) { MessageBox.Show(msg,"FluentCleaner Portable",MessageBoxButtons.OK,MessageBoxIcon.Warning); }
    static string DataFolder(string name) { return Path.Combine(data, name); }

    static void InitializeData()
    {
        Directory.CreateDirectory(DataFolder("Settings"));
        Directory.CreateDirectory(DataFolder("Custom"));
        Directory.CreateDirectory(DataFolder("Databases"));
        // If a previous process was killed, a newer valid local file may contain unsaved preferences.
        if (File.Exists(appSettings) && IsValidSettings(appSettings) &&
            (!File.Exists(dataSettings) || File.GetLastWriteTimeUtc(appSettings) > File.GetLastWriteTimeUtc(dataSettings)))
            AtomicCopy(appSettings, dataSettings);
        if (!File.Exists(dataSettings))
            File.WriteAllText(dataSettings, "{}" + Environment.NewLine, new UTF8Encoding(false));
        if (!IsValidSettings(dataSettings))
            throw new InvalidDataException("Data\\Settings\\settings.json contains invalid JSON. " +
               "Fix or restore that file instead of resetting your preferences.");
        File.Copy(dataSettings, appSettings, true); // mandatory: activates Classic's native portable mode

        // Optional supporter settings (local to application folder).
        RestoreTrackedFile("supporter.json", DataFolder(@"Settings\supporter.json"));
        // Custom rules are text files next to the official EXE; preserve all user additions.
        CopyTree(Path.Combine(app,"Custom"), DataFolder("Custom"), false);
        CopyTree(DataFolder("Custom"), Path.Combine(app,"Custom"), true);
        // Downloaded/changed databases should survive upgrades, not be lost with App replacement.
        foreach (string name in new [] { "Winapp2.ini", "Winapp3.ini", "Winappx.ini" })
            RestoreTrackedFile(name, Path.Combine(DataFolder("Databases"), name));
    }

    static void RestoreTrackedFile(string name, string stored)
    {
        string active = Path.Combine(app, name);
        if (File.Exists(stored)) File.Copy(stored, active, true);
        else if (File.Exists(active) && name.Equals("supporter.json", StringComparison.OrdinalIgnoreCase))
            AtomicCopy(active, stored);
    }
    static bool IsValidSettings(string path)
    {
        try
        {
            string json = File.ReadAllText(path, Encoding.UTF8);
            if (string.IsNullOrWhiteSpace(json)) return false;
            JavaScriptSerializer parser = new JavaScriptSerializer();
            parser.MaxJsonLength = 64 * 1024 * 1024;
            object parsed = parser.DeserializeObject(json);
            return parsed is Dictionary<string, object>;
        }
        catch { return false; }
    }

    static void SaveSettings(bool strict)
    {
        if (string.IsNullOrEmpty(appSettings) || !File.Exists(appSettings)) return;
        if (!IsValidSettings(appSettings))
        {
            if (strict) throw new InvalidDataException("Incomplete or invalid settings.json");
            return;
        }
        if (!SameFile(appSettings, dataSettings))
            AtomicCopySettings(appSettings, dataSettings);
    }
    static bool SameFile(string a, string b)
    {
        if (!File.Exists(a) || !File.Exists(b)) return false;
        FileInfo x = new FileInfo(a), y = new FileInfo(b);
        if (x.Length != y.Length) return false;
        using (SHA256 sha = SHA256.Create())
        using (FileStream fx = File.Open(a, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        using (FileStream fy = File.Open(b, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        {
            return BytesEqual(sha.ComputeHash(fx), sha.ComputeHash(fy));
        }
    }
    static bool BytesEqual(byte[] a, byte[] b)
    {
        if (a.Length != b.Length) return false;
        for (int i=0;i<a.Length;i++) if (a[i] != b[i]) return false;
        return true;
    }
    static void AtomicCopySettings(string source, string dest)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(dest));
        string temp = dest + ".new-" + Guid.NewGuid().ToString("N");
        try
        {
            File.Copy(source, temp);
            // Validate the ACTUAL backed-up bytes, not just the earlier source state.
            if (!IsValidSettings(temp)) return;
            CommitTemp(temp, dest);
        }
        finally { if (File.Exists(temp)) File.Delete(temp); }
    }
    static void AtomicCopy(string source, string dest)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(dest));
        string temp = dest + ".new-" + Guid.NewGuid().ToString("N");
        try
        {
            File.Copy(source, temp);
            CommitTemp(temp, dest);
        }
        finally
        {
            if (File.Exists(temp)) File.Delete(temp);
        }
    }
    static void CommitTemp(string temp, string dest)
    {
        if (!File.Exists(dest)) { File.Move(temp, dest); return; }
        try
        {
            File.Replace(temp, dest, null);
            return;
        }
        catch (IOException)
        {
            // Portable USB drives (including FAT/exFAT) may not support ReplaceFile.
            // Move the old file aside first so it can be restored if committing fails.
        }
        string backup = dest + ".previous-" + Guid.NewGuid().ToString("N");
        File.Move(dest, backup);
        try
        {
            File.Move(temp, dest);
            File.Delete(backup);
        }
        catch
        {
            if (!File.Exists(dest) && File.Exists(backup)) File.Move(backup, dest);
            throw;
        }
    }
    static void SaveOtherData()
    {
        if (string.IsNullOrEmpty(app) || string.IsNullOrEmpty(data) || !Directory.Exists(app)) return;
        string supporter = Path.Combine(app,"supporter.json");
        if (File.Exists(supporter)) AtomicCopy(supporter, DataFolder(@"Settings\supporter.json"));
        CopyTree(Path.Combine(app,"Custom"), DataFolder("Custom"), true);
        foreach (string name in new [] { "Winapp2.ini", "Winapp3.ini", "Winappx.ini" })
        {
            string target = Path.Combine(app, name);
            if (File.Exists(target)) AtomicCopy(target, Path.Combine(DataFolder("Databases"), name));
        }
    }
    // Never delete portable user data. Avoid following junctions/symlinks outside the program.
    static void CopyTree(string source, string dest, bool overwrite)
    {
        if (!Directory.Exists(source)) return;
        Directory.CreateDirectory(dest);
        foreach (string file in Directory.GetFiles(source))
        {
            FileAttributes attr = File.GetAttributes(file);
            if ((attr & FileAttributes.ReparsePoint) != 0) continue;
            string target = Path.Combine(dest, Path.GetFileName(file));
            if (overwrite || !File.Exists(target) || !SameFile(file,target))
            {
                if (!overwrite && File.Exists(target)) continue;
                AtomicCopy(file, target);
            }
        }
        foreach (string dir in Directory.GetDirectories(source))
        {
            if ((File.GetAttributes(dir) & FileAttributes.ReparsePoint) != 0) continue;
            CopyTree(dir, Path.Combine(dest, Path.GetFileName(dir)), overwrite);
        }
    }
}
