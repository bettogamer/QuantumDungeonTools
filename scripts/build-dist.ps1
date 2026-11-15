# build-dist.ps1 - release zip (CurseForge / GitHub) built from what is COMMITTED.
# From AddonTemplate templates/build-dist_TEMPLATE.ps1. Pattern: SMRT build-dist.ps1 (born as a manual
# routine in Coffer, v0.89..v0.93). Use it for release Route D (doc 03 section 7): you tag in
# local, build the zip here, and upload it by hand BEFORE pushing the tag.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-dist.ps1 -Version 0.2.0
#
# What it does:
#   1. `git archive HEAD <Addon>` -> dist/stage/<Addon>   (tracked files only: a local scratch
#      file, a .bak or an untracked media/ can never leak into the zip)
#   2. checks the .toc names CurseForge requires (exact-case <Addon>.toc; extra .toc files start
#      with <Addon>) and replaces `@project-version@` in every .toc with the version. If a .toc
#      has no placeholder (a lib with a literal `## Version:`), the literal must EQUAL -Version.
#   3. checks that every file the main .toc lists is inside the stage (triple-sync rule, doc 01)
#   4. dist/<Addon>-v<Version>.zip with entries `<Addon>/...` and `/` as separator
#
# Why not Compress-Archive: the Windows PowerShell 5.1 one writes entry paths with `\`, which
# Linux/macOS extractors and addon managers do not treat as folders (the addon "installs" as
# files named `MyAddon\Core.lua`). System.IO.Compression with explicit `/` names is the fix.
# Why not Get-Content/Set-Content for the .toc: 5.1 reads UTF-8 as ANSI (mojibake) and writes a
# BOM in front of `## Interface`; [IO.File] with UTF8Encoding($false) does neither.
#
# Refuses to build with uncommitted changes in the addon folder: they would not be in the zip,
# and a zip that differs from what you tested is exactly what this script exists to prevent.
# Order of a release: CHANGELOG -> commit -> tag -> THIS -> upload -> approved -> push the tag.
# Upload checklist: docs/curseforge/upload.md (templates/curseforge/upload_TEMPLATE.md).
param(
    [Parameter(Mandatory = $true)]
    # X.Y.Z, or X.Y.Z-beta.N / X.Y.Z-alpha.N for a pre-release (pick Beta/Alpha as the
    # Release Type when uploading; the tag carries the same suffix).
    [ValidatePattern('^\d+\.\d+\.\d+(-(alpha|beta)\.\d+)?$')]
    [string]$Version
)
$ErrorActionPreference = "Stop"

$Addon = "QuantumDungeonTools"

$root  = Split-Path $PSScriptRoot -Parent
$dist  = Join-Path $root "dist"
$stage = Join-Path $dist "stage"
$out   = Join-Path $dist "$Addon-v$Version.zip"

$dirty = git -C $root status --porcelain -- $Addon
if ($dirty) { throw "Uncommitted changes in $Addon/ (they would not be in the zip):`n$($dirty -join "`n")" }

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

# 1. Export what HEAD tracks. git writes the zip itself: piping binary between native commands
#    corrupts it in PowerShell 5.1.
$archive = Join-Path $dist "stage.zip"
git -C $root archive --format=zip -o $archive HEAD $Addon
if ($LASTEXITCODE -ne 0) { throw "git archive failed" }
Expand-Archive -Path $archive -DestinationPath $stage -Force
Remove-Item $archive -Force

# 2. CurseForge's WoW processor needs <Folder>/<Folder>.toc with the SAME casing, and every
#    extra .toc (multi-TOC: <Addon>_Mainline.toc, _Classic...) must start with the folder name.
#    Test-Path is case-insensitive on Windows, so compare names with -ceq / -clike.
$tocs = @(Get-ChildItem (Join-Path $stage $Addon) -Filter *.toc -File)
if (-not ($tocs | Where-Object { $_.Name -ceq "$Addon.toc" })) {
    throw "No $Addon/$Addon.toc with that exact casing (found: $($tocs.Name -join ', '))"
}
$badToc = @($tocs | Where-Object { $_.Name -cnotlike "$Addon*.toc" })
if ($badToc.Count -gt 0) { throw ".toc names must start with '$Addon': $($badToc.Name -join ', ')" }

# Version into every .toc.
foreach ($t in $tocs) {
    $raw = [IO.File]::ReadAllText($t.FullName)
    if ($raw -match "@project-version@") {
        [IO.File]::WriteAllText($t.FullName, $raw.Replace("@project-version@", $Version),
            (New-Object Text.UTF8Encoding($false)))
    } elseif ($raw -notmatch "(?m)^## Version:\s*$([regex]::Escape($Version))\s*$") {
        throw "$($t.Name) has no @project-version@ placeholder and its ## Version is not $Version"
    }
}
$text = [IO.File]::ReadAllText((Join-Path $stage "$Addon\$Addon.toc"))

# 3. Every file the .toc loads must be in the package.
$missing = @()
foreach ($line in ($text -split "`r?`n")) {
    $entry = $line.Trim()
    if ($entry -eq "" -or $entry.StartsWith("#")) { continue }
    if (-not (Test-Path (Join-Path (Join-Path $stage $Addon) ($entry -replace "/", "\")))) { $missing += $entry }
}
if ($missing.Count -gt 0) { throw "Files listed in $Addon.toc but not in the package:`n$($missing -join "`n")" }

# 4. Zip with forward slashes.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $out) { Remove-Item $out -Force }
$zip = [IO.Compression.ZipFile]::Open($out, [IO.Compression.ZipArchiveMode]::Create)
$count = 0
try {
    $base = (Resolve-Path $stage).Path.TrimEnd("\") + "\"
    foreach ($file in Get-ChildItem (Join-Path $stage $Addon) -Recurse -File) {
        $name = $file.FullName.Substring($base.Length) -replace "\\", "/"
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $name,
            [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        $count++
    }
} finally {
    $zip.Dispose()
}
Remove-Item $stage -Recurse -Force

$mb = [math]::Round((Get-Item $out).Length / 1MB, 2)
Write-Host "built $out ($count files, $mb MB, version $Version)"
