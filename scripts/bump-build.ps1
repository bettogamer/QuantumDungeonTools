# bump-build.ps1 - release bump for a LIBRARY that other addons vendor (pattern: craft's
# bump-build.sh, ported to PowerShell). Copy to scripts/bump-build.ps1 and edit CONFIG.
#
# A lib carries TWO numbers, and consumers need both:
#   * BUILD   - an integer that only ever grows. It is what LibStub compares (MINOR) to decide
#               which copy of the lib wins when several are loaded. Bumped by +1 every release.
#   * VERSION - SemVer, EQUAL to the git tag (v<VERSION>). It is what a consumer reads when it
#               re-vendors, and what `/<addon> info` prints. (craft FR-029: v2.7.0 shipped with
#               Craft.VERSION = "2.6.0" because the release only bumped the build number, and
#               consumers could not tell which build they had vendored.)
# Both live in 3-5 places (main .lua, LibStub MINOR, .toc, demo .toc, a smoke spec...): list ALL
# of them in $VersionSites so one command moves them together. A site that does not match
# EXACTLY once aborts the script -- a stale pattern must not half-bump.
#
# Refuses to run when the new version does not go UP from the last v* tag, or when it equals
# the current one. That is the whole point: cutting a release without a new version is the bug.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bump-build.ps1 -Version 1.4.0
#   ... -DryRun      show what would change, touch nothing
#   ... -NoCommit    edit the files but leave the commit to you
# Next steps (printed at the end): CHANGELOG entry -> commit -> `git tag v<Version>` -> build.
#
# "Build tie" trap (craft P6): during development the lib in your repo and a copy vendored
# inside another addon can carry the SAME build; if that addon loads first, ITS copy wins and
# your in-game test exercises the old code. While testing, bump the build +1 LOCALLY (do not
# commit), deploy, test, and revert before the release. The dev build must always be greater
# than any vendored one.
#
# Encoding: files are read and written with [IO.File] + UTF8Encoding($false). PowerShell 5.1
# Get-Content/Set-Content decodes UTF-8 as ANSI (mojibake on every accent) and writes a BOM
# in front of `## Interface`, which breaks the .toc.

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    [switch]$DryRun,
    [switch]$NoCommit
)
$ErrorActionPreference = "Stop"

# ==========================================================================================
# CONFIG - the only part to edit per project
# ==========================================================================================
$Name = "QuantumDungeonTools"

# PENDIENTE (owner): esta plantilla es para LIBRERIAS (build entero + MINOR de LibStub). QDT es un
# addon que no se vendorea: no tiene build entero. Decidir si se usa este script o se borra.
# Sitio del build entero: NO aplica a un addon (solo a libs). PENDIENTE (owner): decidir si se
# quita. Mientras tanto apunta a un patron inexistente: el script aborta antes de tocar nada.
$BuildSite = @{ File = "QuantumDungeonTools\QuantumDungeonTools.lua"; Pattern = '(?m)^(local QDT_BUILD = )(\d+)' }

# Every place the SemVer string appears. Same group convention (1 = prefix, 2 = X.Y.Z, 3 = suffix).
# The FIRST entry is also the "current version" the script compares against.
# PENDIENTE: el .toc tiene `## Version: @project-version@` (token del empaquetador, no SemVer): el
# script abortara hasta que haya una version X.Y.Z en el .toc. Ajustar al primer release.
$VersionSites = @(
    @{ File = "QuantumDungeonTools\QuantumDungeonTools.toc"; Pattern = '(?m)^(## Version: )(\d+\.\d+\.\d+)' }
)
# ==========================================================================================

$repo = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Read-Site($site) {
    $path = Join-Path $repo $site.File
    if (-not (Test-Path $path)) { throw "site file not found: $($site.File)" }
    $text = [IO.File]::ReadAllText($path)
    $found = [regex]::Matches($text, $site.Pattern)
    if ($found.Count -ne 1) {
        throw "$($site.File): pattern matched $($found.Count) times (expected exactly 1): $($site.Pattern)"
    }
    return @{ Path = $path; Text = $text; Match = $found[0] }
}

function Set-Site($site, $newValue) {
    $r = Read-Site $site
    $evaluator = { param($m) $m.Groups[1].Value + $newValue + $m.Groups[3].Value }
    $text = [regex]::Replace($r.Text, $site.Pattern, $evaluator)
    [IO.File]::WriteAllText($r.Path, $text, $utf8)
}

$currentBuild   = [int](Read-Site $BuildSite).Match.Groups[2].Value
$currentVersion = (Read-Site $VersionSites[0]).Match.Groups[2].Value
$nextBuild      = $currentBuild + 1

# Guard 1: the version must actually change.
if ($Version -eq $currentVersion) {
    throw "$Name version is already $currentVersion - pass the NEW release version"
}
# Guard 2: and it must go UP from the last release tag (a downgrade or a re-used number).
$prev = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
$lastTag = (& git -C $repo describe --tags --abbrev=0 --match "v*" 2>$null)
$ErrorActionPreference = $prev
if ($lastTag) {
    $lastTag = ([string]$lastTag).Trim()
    if ([version]$Version -le [version]($lastTag.TrimStart("v"))) {
        throw "$Version does not go up from the last release tag ($lastTag)"
    }
}
# Guard 3: every site must still agree with the first one (a drifted .toc is how a lib ships
# with a mismatched `## Version`).
foreach ($s in $VersionSites) {
    $v = (Read-Site $s).Match.Groups[2].Value
    if ($v -ne $currentVersion) { throw "$($s.File) says $v but $($VersionSites[0].File) says $currentVersion - fix the drift first" }
}

Write-Host "$Name build:   $currentBuild -> $nextBuild"
Write-Host "$Name version: $currentVersion -> $Version   (last tag: $(if ($lastTag) { $lastTag } else { 'none' }))"
foreach ($s in $VersionSites) { Write-Host "  site: $($s.File)" }
if ($DryRun) { Write-Host "(dry-run - nothing changed)"; return }

Set-Site $BuildSite $nextBuild
foreach ($s in $VersionSites) { Set-Site $s $Version }

# Verify what was written (a pattern that matched but wrote nothing useful would pass silently).
if ([int](Read-Site $BuildSite).Match.Groups[2].Value -ne $nextBuild) { throw "build bump was not applied" }
foreach ($s in $VersionSites) {
    if ((Read-Site $s).Match.Groups[2].Value -ne $Version) { throw "version bump was not applied in $($s.File)" }
}

if (-not $NoCommit) {
    $files = @($BuildSite.File) + ($VersionSites | ForEach-Object { $_.File }) | Select-Object -Unique
    & git -C $repo add -- @files
    & git -C $repo commit -m "chore: bump $Name build $currentBuild -> $nextBuild, version -> $Version"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
}
Write-Host ""
Write-Host "Done. Next: CHANGELOG entry, then  git tag v$Version  and build (scripts/build-embed.ps1)."
