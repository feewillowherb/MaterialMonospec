#Requires -Version 5.1
<#
.SYNOPSIS
  Sync GDXS20260520002 assets into graph fixtures and build a portable probe package.

.DESCRIPTION
  1) Copy snap PNG (+ note txt) from _temp/GDXS20260520002数据推送测试 → fixtures/
  2) Assemble portable folder (cmd + ps1 + image) for offline / VPN internal host.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File pipelines/graphs/govsync/gdxs20260520002-weighbridge/scripts/Copy-GdxsWeighbridgePackage.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .../Copy-GdxsWeighbridgePackage.ps1 -DestDir "D:\USB\gdxs-weighbridge"
#>
[CmdletBinding()]
param(
    [string] $DestDir = "",
    [switch] $SkipFixtures,
    [switch] $SkipPackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = $null
$dir = $GraphRoot
while ($dir) {
    if (Test-Path -LiteralPath (Join-Path $dir ".hagicode\monospecs.yaml")) {
        $RepoRoot = $dir
        break
    }
    $parent = Split-Path -Parent $dir
    if ([string]::IsNullOrEmpty($parent) -or $parent -eq $dir) { break }
    $dir = $parent
}
if (-not $RepoRoot) {
    throw "Cannot find monospec root (.hagicode/monospecs.yaml)."
}

# Source folder name contains CJK; resolve via wildcard under _temp/
$assetsParent = Join-Path $RepoRoot "_temp"
$assetDirs = @(Get-ChildItem -LiteralPath $assetsParent -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "GDXS20260520002*" })
if ($assetDirs.Count -eq 0) {
    throw ("Source folder not found under {0} matching GDXS20260520002*" -f $assetsParent)
}
$AssetsDir = $assetDirs[0].FullName

$FixturesDir = Join-Path $GraphRoot "fixtures"
$InternalDir = Join-Path $PSScriptRoot "internal"
$SnapName = "16cfa8c48c427f193da61f7a6903f9d6.png"

if ([string]::IsNullOrWhiteSpace($DestDir)) {
    $DestDir = Join-Path $RepoRoot "_tmp\gdxs20260520002-weighbridge-package"
}
$DestDir = [System.IO.Path]::GetFullPath($DestDir)

Write-Host "Assets   : $AssetsDir"
Write-Host "Fixtures : $FixturesDir"
Write-Host "Package  : $DestDir"
Write-Host ""

function Copy-LiteralFile {
    param(
        [string] $From,
        [string] $To
    )
    $parent = Split-Path -Parent $To
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Copy-Item -LiteralPath $From -Destination $To -Force
    Write-Host ("  + {0}" -f $To)
}

# --- sync fixtures ---
if (-not $SkipFixtures) {
    Write-Host "Sync fixtures from assets..."
    New-Item -ItemType Directory -Force -Path $FixturesDir | Out-Null

    $srcPng = Join-Path $AssetsDir $SnapName
    if (-not (Test-Path -LiteralPath $srcPng)) {
        $pngs = @(Get-ChildItem -LiteralPath $AssetsDir -Filter "*.png" -File)
        if ($pngs.Count -eq 0) {
            throw ("No PNG found in assets: {0}" -f $AssetsDir)
        }
        $srcPng = $pngs[0].FullName
        $SnapName = $pngs[0].Name
    }

    Copy-LiteralFile -From $srcPng -To (Join-Path $FixturesDir $SnapName)
    # Convenience alias for portable runners that look for test_pic.png
    Copy-LiteralFile -From $srcPng -To (Join-Path $FixturesDir "test_pic.png")

    $txts = @(Get-ChildItem -LiteralPath $AssetsDir -Filter "*.txt" -File)
    foreach ($t in $txts) {
        Copy-LiteralFile -From $t.FullName -To (Join-Path $FixturesDir $t.Name)
    }
    Write-Host ""
}

# --- portable package ---
if (-not $SkipPackage) {
    Write-Host "Build portable package..."
    if (Test-Path -LiteralPath $DestDir) {
        # Do not wipe unknown content silently — clear only known package files
        $known = @(
            "Run-GdxsWeighbridge.cmd",
            "Run-GdxsWeighbridge.ps1",
            $SnapName,
            "test_pic.png",
            "README.txt"
        )
        foreach ($name in $known) {
            $p = Join-Path $DestDir $name
            if (Test-Path -LiteralPath $p) {
                Remove-Item -LiteralPath $p -Force
            }
        }
    }
    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

    $cmdSrc = Join-Path $InternalDir "Run-GdxsWeighbridge.cmd"
    $ps1Src = Join-Path $InternalDir "Run-GdxsWeighbridge.ps1"
    if (-not (Test-Path -LiteralPath $cmdSrc)) { throw "Missing: $cmdSrc" }
    if (-not (Test-Path -LiteralPath $ps1Src)) { throw "Missing: $ps1Src" }

    Copy-LiteralFile -From $cmdSrc -To (Join-Path $DestDir "Run-GdxsWeighbridge.cmd")
    Copy-LiteralFile -From $ps1Src -To (Join-Path $DestDir "Run-GdxsWeighbridge.ps1")

    $fixPng = Join-Path $FixturesDir $SnapName
    if (-not (Test-Path -LiteralPath $fixPng)) {
        throw ("Fixture PNG missing after sync: {0}" -f $fixPng)
    }
    Copy-LiteralFile -From $fixPng -To (Join-Path $DestDir $SnapName)
    Copy-LiteralFile -From $fixPng -To (Join-Path $DestDir "test_pic.png")

    $readme = @(
        "GDXS20260520002 weighbridge portable probe"
        ""
        "Scenario:"
        "  buildLicenseNo = GDXS20260520002"
        "  carNo          = ZheA12345"
        "  goodsWeight    = 1475"
        "  endpoint       = http://191.12.15.58:8899/sapi/v1/inoutRecord/lantu/saveRecord"
        ""
        "Usage (on VPN / internal host):"
        "  1. Keep these three files in the same folder"
        "  2. Double-click Run-GdxsWeighbridge.cmd"
        "  3. Type YES when prompted"
        "  4. Collect output\<timestamp>\ back for review"
        ""
        "Source Graph: pipelines/graphs/govsync/gdxs20260520002-weighbridge"
        "Source: _temp/GDXS20260520002"
    ) -join "`r`n"
    $readmePath = Join-Path $DestDir "README.txt"
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($readmePath, $readme, $utf8)
    Write-Host ("  + {0}" -f $readmePath)
    Write-Host ""
}

Write-Host "Done."
Write-Host "Next:"
Write-Host "  - Test package on internal host, or"
Write-Host "  - powershell -ExecutionPolicy Bypass -File pipelines/graphs/govsync/gdxs20260520002-weighbridge/scripts/Invoke-GdxsWeighbridge.ps1"
exit 0
