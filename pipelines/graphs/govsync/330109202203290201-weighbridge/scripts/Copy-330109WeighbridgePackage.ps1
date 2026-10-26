#Requires -Version 5.1
<#
.SYNOPSIS
  Sync 330109202203290201 assets into graph fixtures and build a portable probe package.

.DESCRIPTION
  1) Copy test_pic_v2.jpg from _temp/330109202203290201 → fixtures/
  2) Assemble portable folder (cmd + ps1 + image) for offline / VPN internal host.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File pipelines/graphs/govsync/330109202203290201-weighbridge/scripts/Copy-330109WeighbridgePackage.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .../Copy-330109WeighbridgePackage.ps1 -DestDir "D:\USB\330109-weighbridge"
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

$AssetsDir = Join-Path $RepoRoot "_temp\330109202203290201"
$FixturesDir = Join-Path $GraphRoot "fixtures"
$InternalDir = Join-Path $PSScriptRoot "internal"
$SnapName = "test_pic_v2.jpg"

if ([string]::IsNullOrWhiteSpace($DestDir)) {
    $DestDir = Join-Path $RepoRoot "_tmp\330109202203290201-weighbridge-package"
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

    $srcJpg = Join-Path $AssetsDir $SnapName
    if (-not (Test-Path -LiteralPath $srcJpg)) {
        $jpgs = @(Get-ChildItem -LiteralPath $AssetsDir -Include "*.jpg", "*.jpeg", "*.png" -File -Recurse -ErrorAction SilentlyContinue)
        if ($jpgs.Count -eq 0) {
            # fallback: already-synced fixture
            $srcJpg = Join-Path $FixturesDir $SnapName
            if (-not (Test-Path -LiteralPath $srcJpg)) {
                throw ("No image found in assets: {0}" -f $AssetsDir)
            }
        }
        else {
            $srcJpg = $jpgs[0].FullName
            $SnapName = $jpgs[0].Name
        }
    }

    Copy-LiteralFile -From $srcJpg -To (Join-Path $FixturesDir $SnapName)
    if ($SnapName -ne "test_pic_v2.jpg") {
        Copy-LiteralFile -From $srcJpg -To (Join-Path $FixturesDir "test_pic_v2.jpg")
    }
    Write-Host ""
}

# --- portable package ---
if (-not $SkipPackage) {
    Write-Host "Build portable package..."
    if (Test-Path -LiteralPath $DestDir) {
        $known = @(
            "Run-330109Weighbridge.cmd",
            "Run-330109Weighbridge.ps1",
            "test_pic_v2.jpg",
            "test_pic.jpg",
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

    $cmdSrc = Join-Path $InternalDir "Run-330109Weighbridge.cmd"
    $ps1Src = Join-Path $InternalDir "Run-330109Weighbridge.ps1"
    if (-not (Test-Path -LiteralPath $cmdSrc)) { throw "Missing: $cmdSrc" }
    if (-not (Test-Path -LiteralPath $ps1Src)) { throw "Missing: $ps1Src" }

    Copy-LiteralFile -From $cmdSrc -To (Join-Path $DestDir "Run-330109Weighbridge.cmd")
    Copy-LiteralFile -From $ps1Src -To (Join-Path $DestDir "Run-330109Weighbridge.ps1")

    $fixJpg = Join-Path $FixturesDir "test_pic_v2.jpg"
    if (-not (Test-Path -LiteralPath $fixJpg)) {
        $fixJpg = Join-Path $FixturesDir $SnapName
    }
    if (-not (Test-Path -LiteralPath $fixJpg)) {
        throw ("Fixture image missing after sync: {0}" -f $fixJpg)
    }
    Copy-LiteralFile -From $fixJpg -To (Join-Path $DestDir "test_pic_v2.jpg")
    Copy-LiteralFile -From $fixJpg -To (Join-Path $DestDir "test_pic.jpg")

    $readme = @(
        "330109202203290201 weighbridge portable probe"
        ""
        "Scenario:"
        "  buildLicenseNo = 330109202203290201"
        "  carNo          = ZheA12345"
        "  goodsWeight    = 1060 (1.06t)"
        "  snapTime       = 2026-10-26 10:02:08 (fixed)"
        "  endpoint       = http://191.12.15.58:8899/sapi/v1/inoutRecord/lantu/saveRecord"
        ""
        "Usage (on VPN / internal host):"
        "  1. Keep these files in the same folder"
        "     - Run-330109Weighbridge.cmd"
        "     - Run-330109Weighbridge.ps1"
        "     - test_pic_v2.jpg"
        "  2. Double-click Run-330109Weighbridge.cmd"
        "  3. Type YES when prompted"
        "  4. Collect output\<timestamp>\ back for review"
        ""
        "Source Graph: pipelines/graphs/govsync/330109202203290201-weighbridge"
        "Source assets: _temp/330109202203290201"
    ) -join "`r`n"
    $readmePath = Join-Path $DestDir "README.txt"
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($readmePath, $readme, $utf8)
    Write-Host ("  + {0}" -f $readmePath)
    Write-Host ""
}

Write-Host "Done."
Write-Host "Next:"
Write-Host "  - Copy package folder to internal host and run Run-330109Weighbridge.cmd, or"
Write-Host "  - powershell -ExecutionPolicy Bypass -File pipelines/graphs/govsync/330109202203290201-weighbridge/scripts/Invoke-330109Weighbridge.ps1"
exit 0
