import pathlib,unittest,ast

ROOT = pathlib.Path(__file__).resolve().parents[1]
class BuilderContract(unittest.TestCase):
    def test_manual_only(self):
        yaml=(ROOT/'.github/workflows/build-fluentcleaner-classic-portable.yml').read_text(encoding="utf-8")
        self.assertIn('workflow_dispatch:', yaml)
        self.assertNotIn('schedule:', yaml)
        self.assertIn('windows-2022', yaml)
        self.assertIn('actions/upload-artifact@v7', yaml)
        self.assertIn('include-hidden-files: true', yaml)
    def test_expected_official_asset(self):
        txt=(ROOT/'scripts/build.ps1').read_text(encoding="utf-8")
        self.assertIn('FluentCleaner-Classic-net48.zip', txt)
        self.assertIn('builtbybel/FluentCleaner', txt)
        self.assertIn('Get-FileHash', txt)
        self.assertIn('Extract-OfficialIcon.ps1', txt)
    def test_release_selection_uses_direct_latest_and_foreach_fallback(self):
        script=(ROOT/'scripts/build.ps1').read_text(encoding="utf-8")
        self.assertIn('"$api/releases/latest"',script)
        self.assertIn('foreach ($candidate in $releases)',script)
        self.assertIn('"$api/releases?per_page=100"',script)
        self.assertIn('Get-ClassicAsset',script)
        self.assertNotIn('$releases = @(Invoke-RestMethod',script)
        self.assertIn('SHA256 does not match', script)
    def test_classic_executable_is_discovered_and_never_assumed(self):
        build=(ROOT/'scripts/build.ps1').read_text(encoding="utf-8")
        launcher=(ROOT/'launcher/FluentCleanerPortable.cs').read_text(encoding="utf-8")
        doc=(ROOT/'README.md').read_text(encoding="utf-8")
        # Both known official EXE names must be checked in the actual extracted ZIP.
        for name in ('FluentCleaner.Classic.exe', 'FCleaner.exe'):
            self.assertIn(name,build)
            self.assertIn(name,launcher)
            self.assertIn(name,doc)
        self.assertIn("Get-ChildItem -LiteralPath $extracted -Recurse -File -Filter '*.exe'",build)
        self.assertIn('EXE files discovered',build)
        self.assertIn('$exeName = $candidates[0].Name',build)
        self.assertIn('$packagedExe = Join-Path $appDir $exeName',build)
        self.assertIn('LocateClassicExecutable()',launcher)
        self.assertNotIn("-Filter 'FCleaner.exe'",build)
        self.assertNotIn('exe = Path.Combine(app, "FCleaner.exe")',launcher)
    def test_fail_closed_if_no_unique_classic_exe(self):
        build=(ROOT/'scripts/build.ps1').read_text(encoding="utf-8")
        self.assertIn('if ($candidates.Count -ne 1)',build)
        self.assertIn('All EXE filenames:',build)
        self.assertIn('Selected official Classic executable:',build)

    def test_no_global_clean_or_appdata_rename(self):
        src=(ROOT/'launcher/FluentCleanerPortable.cs').read_text(encoding="utf-8")
        self.assertIn('File.Exists(exe)', src)
        self.assertIn('SaveSettings(false)', src)
        self.assertIn('settings.json', src)
        for dangerous in ['schtasks /delete', 'Remove-Item $env:APPDATA', 'SetEnvironmentVariable("APPDATA"']:
            self.assertNotIn(dangerous, src)
    def test_tests_do_not_depend_on_windows_legacy_encoding(self):
        # Regression: v1.2 passed on Linux but crashed on GitHub Windows (cp1252).
        tree = ast.parse((ROOT/'tests/test_kit.py').read_text(encoding='utf-8'))
        found = 0
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == 'read_text':
                found += 1
                self.assertTrue(any(k.arg == 'encoding' and isinstance(k.value, ast.Constant) and k.value.value.lower() == 'utf-8' for k in node.keywords),
                                'All test reads must use encoding="utf-8" (Windows cp1252 regression).')
        self.assertGreaterEqual(found, 6)

    def test_workflow_forces_utf8_for_windows_test_process(self):
        workflow = (ROOT/'.github/workflows/build-fluentcleaner-classic-portable.yml').read_text(encoding='utf-8')
        self.assertIn('PYTHONUTF8: "1"', workflow)
        self.assertIn('python -X utf8 -m unittest', workflow)

    def test_docs_disclose_closed_source(self):
        doc=(ROOT/'README.md').read_text(encoding="utf-8").lower()
        self.assertIn('closed source',doc)
        self.assertIn('scheduled',doc)
        self.assertIn('preserve',doc)
if __name__=='__main__': unittest.main()
