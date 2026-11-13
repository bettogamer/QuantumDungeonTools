# deploy-local.ps1 — copia las carpetas de addon del repo a Interface\AddOns (dev local).
# Copiar a scripts/deploy-local.ps1 del proyecto y ajustar la lista $folders.
# Soporta varios addons por repo (p. ej. lib standalone + addon de demo, patrón Weave).
# Usage: powershell -File scripts/deploy-local.ps1 [-AddOnsPath <path>]
param(
    [string]$AddOnsPath = "F:\Games\World of Warcraft\_forever_\Interface\AddOns"   # WoW Forever
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $AddOnsPath)) {
    throw "AddOns folder not found: $AddOnsPath (pass -AddOnsPath)"
}

# <ruta relativa en el repo> => <nombre de carpeta en AddOns> (borra y recopia: espejo real)
$folders = @(
    @{ src = "QuantumDungeonTools";          dest = "QuantumDungeonTools" }
)

foreach ($pair in $folders) {
    $src  = Join-Path $repo $pair.src
    $dest = Join-Path $AddOnsPath $pair.dest
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Copy-Item -Recurse $src $dest
    Write-Host ("deployed " + $dest)
}
Write-Host "Done - /reload in game."
