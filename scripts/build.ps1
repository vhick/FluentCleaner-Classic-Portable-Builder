param([string]$ReleaseTag='latest')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot
$headers = @{ 'User-Agent' = 'FluentCleanerClassicPortableBuilder/1.4'; 'Accept' = 'application/vnd.github+json' }
$api = 'https://api.github.com/repos/builtbybel/FluentCleaner'
$assetName = 'FluentCleaner-Classic-net48.zip'

# PowerShell's Invoke-RestMethod does not automatically enumerate a JSON array
# when its output is piped directly to Where-Object. GitHub lists releases as
# an array. Resolve /releases/latest directly first, then enumerate the
# fallback /releases endpoint explicitly with foreach.
function Get-ClassicAsset($candidate) {
    if ($null -eq $candidate -or $candidate.draft -or $candidate.prerelease) { return $null }
    $found = @($candidate.assets | Where-Object { $_.name -ceq $assetName -and $_.state -eq 'uploaded' })
    if ($found.Count -eq 1) { return $found[0] }
    return $null
}
$release = $null
$asset = $null
if ($ReleaseTag -eq 'latest') {
    $latest = Invoke-RestMethod -Uri "$api/releases/latest" -Headers $headers
    $asset = Get-ClassicAsset $latest
    if ($null -ne $asset) {
        $release = $latest
    } else {
        Write-Warning 'Latest GitHub release has no Classic ZIP. Searching other stable releases.'
        $releases = Invoke-RestMethod -Uri "$api/releases?per_page=100" -Headers $headers
        foreach ($candidate in $releases) {
            $found = Get-ClassicAsset $candidate
            if ($null -ne $found) { $release = $candidate; $asset = $found; break }
        }
    }
} else {
    if ($ReleaseTag -notmatch '^[a-zA-Z0-9._-]{1,40}$') {
        throw 'Use latest or an official GitHub release tag (example: 26.09.01).'
    }
    $release = Invoke-RestMethod -Uri "$api/releases/tags/$ReleaseTag" -Headers $headers
    $asset = Get-ClassicAsset $release
}
if ($null -eq $release -or $null -eq $asset) {
    throw 'No official stable release with FluentCleaner-Classic-net48.zip found. Check the Classic asset on https://github.com/builtbybel/FluentCleaner/releases or enter an explicit official release tag.'
}
$url = [string]$asset.browser_download_url
if (-not $url.StartsWith('https://github.com/builtbybel/FluentCleaner/releases/download/',[StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing non-official release asset URL: $url"
}
Write-Host "Selected official release: $($release.tag_name); Classic asset: $assetName"
$work = Join-Path $repoRoot 'work'
$stage = Join-Path $repoRoot 'stage/FluentCleanerPortable'
if (Test-Path $work) { Remove-Item -LiteralPath $work -Recurse -Force }
if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Path $work,$stage -Force | Out-Null
$archive = Join-Path $work $assetName
Invoke-WebRequest -Uri $url -OutFile $archive -Headers @{ 'User-Agent' = 'FluentCleanerClassicPortableBuilder/1.4' } -MaximumRedirection 5
if ((Get-Item -LiteralPath $archive).Length -lt 50000) { throw 'Official ZIP appears to be empty or truncated.' }
if ([long]$asset.size -gt 0 -and (Get-Item -LiteralPath $archive).Length -ne [long]$asset.size) {
    throw 'Downloaded ZIP file length does not match GitHub release asset metadata.'
}
$sha = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
# Recent GitHub release assets provide an API sha256 digest. Verify when present.
if ($asset.PSObject.Properties.Name -contains 'digest' -and
    -not [string]::IsNullOrWhiteSpace([string]$asset.digest)) {
    $expectedDigest = [string]$asset.digest
    if ($expectedDigest -notmatch '^sha256:[a-fA-F0-9]{64}$') { throw "Unsupported GitHub asset digest: $expectedDigest" }
    if (-not $sha.Equals($expectedDigest.Substring(7), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Downloaded Classic asset SHA256 does not match the GitHub release digest.'
    }
    Write-Host 'Verified SHA256 against GitHub release asset metadata.'
}
Write-Host "SHA256 of downloaded official Classic asset: $sha"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.ZipFile
# Reject malformed paths before extraction (ZIP slip).
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    foreach ($entry in $zip.Entries) {
        $n = $entry.FullName.Replace('\','/')
        if ($n.StartsWith('/') -or $n -match '(^|/)\.\.(/|$)' -or $n -match '^[A-Za-z]:') {
            throw "Unsafe path in upstream ZIP: $n"
        }
    }
} finally { $zip.Dispose() }
$extracted = Join-Path $work 'original'
Expand-Archive -LiteralPath $archive -DestinationPath $extracted -Force
# Documented executable name: FluentCleaner.Classic.exe (official Classic HELP.md).
# Some older third-party packaging discussions mention FCleaner.exe. Support both,
# but NEVER select arbitrary helper executables or the Modern edition by mistake.
$allExecutables = @(Get-ChildItem -LiteralPath $extracted -Recurse -File -Filter '*.exe')
Write-Host 'EXE files discovered in the VERIFIED official Classic ZIP:'
foreach ($item in $allExecutables) {
    Write-Host "  $($item.FullName.Substring($extracted.Length).TrimStart('\','/'))"
}
$names = @('FluentCleaner.Classic.exe', 'FCleaner.exe')
$candidates = @($allExecutables | Where-Object { $names -contains $_.Name })
if ($candidates.Count -ne 1) {
    $observed = if ($allExecutables.Count -eq 0) { '[No EXE files found]' } else { ($allExecutables.Name -join ', ') }
    throw "Expected exactly one official Classic executable (FluentCleaner.Classic.exe or FCleaner.exe); found $($candidates.Count). All EXE filenames: $observed"
}
$originalExe = $candidates[0].FullName
$exeName = $candidates[0].Name
Write-Host "Selected official Classic executable: $exeName"
# Copy the complete upstream distribution directory (DLLs, databases, locales, Custom rules).
$appDir = Join-Path $stage 'App/FluentCleaner'
New-Item -ItemType Directory -Path $appDir -Force | Out-Null
Get-ChildItem -LiteralPath (Split-Path -Parent $originalExe) -Force | Copy-Item -Destination $appDir -Recurse -Force
$packagedExe = Join-Path $appDir $exeName
if (-not (Test-Path -LiteralPath $packagedExe)) { throw "Missing official Classic executable $exeName in App after copying." }
# Do not include any developer's test profile or personal preferences in the distributed build.
# App/settings.json is created automatically on first launch and kept synchronized with Data.
$packagedSettings = Join-Path $appDir 'settings.json'
if (Test-Path -LiteralPath $packagedSettings) { Remove-Item -LiteralPath $packagedSettings -Force }
foreach ($sub in @('Settings','Custom','Databases')) {
    $folder = Join-Path $stage "Data/$sub"
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $folder '.keep') -Value '' -NoNewline
}
$iconDir = Join-Path $stage 'App/AppInfo'
$srcDir = Join-Path $stage 'Other/Source'
New-Item -ItemType Directory -Path $iconDir,$srcDir -Force | Out-Null
# Use the STANDARD PortableApps.com AppInfo location and icon names.
# The vendor executable filename is kept unmodified inside App/FluentCleaner.
$icon = Join-Path $iconDir 'appicon.ico'
& (Join-Path $PSScriptRoot 'Extract-OfficialIcon.ps1') -ExePath $packagedExe -OutputPath $icon
# Build the launcher's .NET Framework 4.8 Windows GUI executable using Windows' native C# compiler.
$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { throw 'Windows .NET Framework C# compiler not found on runner.' }
$launcherSrc = Join-Path $repoRoot 'launcher/FluentCleanerPortable.cs'
$launcherExe = Join-Path $stage 'FluentCleanerPortable.exe'
$compilerArgs = @('/nologo','/target:winexe','/platform:anycpu',
    "/win32icon:$icon", "/out:$launcherExe",
    '/reference:System.dll', '/reference:System.Core.dll',
    '/reference:System.Windows.Forms.dll', '/reference:System.Web.Extensions.dll', $launcherSrc)
& $csc @compilerArgs
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $launcherExe)) { throw 'Portable launcher compilation failed.' }
Copy-Item -LiteralPath $launcherSrc -Destination (Join-Path $srcDir 'FluentCleanerPortable.cs')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Extract-OfficialIcon.ps1') -Destination (Join-Path $srcDir 'Extract-OfficialIcon.ps1')
$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($packagedExe).ProductVersion
if ([string]::IsNullOrWhiteSpace($version) -or $version -notmatch '^[0-9]+(\.[0-9]+){1,3}') {
    $version = [string]$release.tag_name
}
$version = ($version -replace '[^a-zA-Z0-9._-]','-')
# Official menu format: App/AppInfo/appinfo.ini, not Other/AppInfo.
# Windows may pick a smaller native image from the multi-resolution ORIGINAL ICO.
# Every PNG is derived from the SAME upstream official icon; never substitute artwork.
Add-Type -AssemblyName System.Drawing
foreach ($size in @(16,32,75,128,256)) {
    $target = Join-Path $iconDir "appicon_$size.png"
    $icoObj = $null
    $bmp = $null
    try {
        $icoObj = [System.Drawing.Icon]::new($icon, $size, $size)
        $sourceBitmap = $icoObj.ToBitmap()
        try {
            $bmp = [System.Drawing.Bitmap]::new($sourceBitmap, $size, $size)
            $bmp.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $sourceBitmap.Dispose() }
    } finally {
        if ($null -ne $bmp) { $bmp.Dispose() }
        if ($null -ne $icoObj) { $icoObj.Dispose() }
    }
    if ((Get-Item -LiteralPath $target).Length -lt 100) { throw "Invalid official icon PNG: $target" }
}
# PackageVersion must be four numeric components.
$numericSegments = @([regex]::Matches($version, '\d+') | ForEach-Object { $_.Value } | Select-Object -First 4)
if ($numericSegments.Count -eq 0) { throw "Cannot form PortableApps PackageVersion from '$version'" }
while ($numericSegments.Count -lt 4) { $numericSegments += '0' }
$packageVersion = ($numericSegments -join '.')
# No PAF installer required: PortableApps Platform reads this file when folder is placed in X:\PortableApps.
# This is a community portable build, NOT an official PortableApps.com release.
@"
[Format]
Type=PortableApps.comFormat
Version=3.9

[Details]
Name=FluentCleaner Classic Portable
AppID=FluentCleanerPortable-Community
Publisher=builtbybel (original application)
Homepage=https://github.com/builtbybel/FluentCleaner
Category=Utilities
Description=Classic system cleaner using a community-built portable launcher
Language=English

[License]
Shareable=false
OpenSource=false
Freeware=true
CommercialUse=false

[Version]
PackageVersion=$packageVersion
DisplayVersion=$version

[Dependencies]
UsesDotNetVersion=4.8

[Control]
Icons=1
Start=FluentCleanerPortable.exe
"@ | Set-Content -LiteralPath (Join-Path $iconDir 'appinfo.ini') -Encoding ASCII
if (-not (Test-Path (Join-Path $iconDir 'appicon.ico'))) { throw 'Missing standard PortableApps icon.' }
if (-not (Test-Path (Join-Path $iconDir 'appinfo.ini'))) { throw 'Missing standard PortableApps metadata.' }
@"
FluentCleaner Classic: upstream release tag $($release.tag_name)
Official distribution: $url
Official asset SHA256: $sha
Classic program version (from executable metadata): $version
Classic executable filename: $exeName
PortableApps menu metadata: App/AppInfo/appinfo.ini
Distribution ZIP contains outer FluentCleanerPortable/ folder: yes
Builder version: 1.4
Unmodified Classic binary: yes
Settings handling: local settings.json is backed up to Data/Settings/settings.json
IMPORTANT: app scheduled tasks and automatic CLI logs cannot be made isolated without modifying Classic's private source.
"@ | Set-Content -LiteralPath (Join-Path $stage 'Other/build-manifest.txt') -Encoding UTF8
@'
FLUENTCLEANER CLASSIC PORTABLE — START HERE

Extract the INNER FluentCleanerPortable-<version>.zip into X:\PortableApps\ .
You must end up with X:\PortableApps\FluentCleanerPortable\FluentCleanerPortable.exe
If the platform is already running, select Apps > Refresh App Icons.
Launch ONLY FluentCleanerPortable.exe at the top level.
It automatically stores settings and custom cleaning rules under Data/.
No installation is needed on Windows with .NET Framework 4.8.

WARNING: FluentCleaner is a powerful system cleaner.
- Use Analyze, inspect the precise matches, THEN decide whether to Run Cleaner.
- Leave experimental Winapp3 disabled unless you understand the rules.
- Do NOT use built-in Scheduler or /AUTO with this portable build.
  They create a Windows task / AppData auto.log, and are NOT portable.
- The root launcher blocks command-line cleaning for safety, but the program itself
  still exposes Scheduler and its raw executable can run command-line cleaning.
- Never wipe Windows AppData or registry to remove traces; other apps use them.

UPDATES: Close program. Replace FluentCleanerPortable.exe, App/, Other/ only.
KEEP ALL of Data/ intact. The next launch restores settings and custom rules.
Updated external databases stored in Data/Databases may override newer bundled
versions; update the database from FluentCleaner when you want new rules.

Portability is not yet fully verified on a real Windows desktop. Application-owned
scheduled-task and /AUTO log paths remain known unsupported cases.
'@ | Set-Content -LiteralPath (Join-Path $stage 'START-HERE.txt') -Encoding UTF8
# Self-test checks compiled executable and packaging; it doesn't launch cleaning engine.
& $launcherExe '--self-test'
if ($LASTEXITCODE -ne 0) { throw "Root portable launcher self-test failed: $LASTEXITCODE" }
if ((Get-Item -LiteralPath $launcherExe).Length -lt 5000) { throw 'Portable launcher unexpectedly small.' }
Write-Host 'PASS: launcher self-test, source asset, standard PortableApps icon and metadata, App/Data/Other layout.'
Write-Host 'PENDING: user must verify Windows GUI / settings persistence / scheduled-task behavior.'
"version=$version" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
