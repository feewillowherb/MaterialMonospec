#Requires -Version 5.1
<#
.SYNOPSIS
  Sync XNXS20240725003 assets into graph fixtures and build a portable probe package.

.DESCRIPTION
  1) Copy snap PNG (+ note txt) from assets/XNXS20240725003数据推送测试 → fixtures/
  2) Assemble portable folder (cmd + ps1 + image) for offline / VPN internal host.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File pipelines/graphs/govsync/xnxs20240725003-weighbridge/scripts/Copy-XnxsWeighbridgePackage.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .../Copy-XnxsWeighbridgePackage.ps1 -DestDir "D:\USB\xnxs-weighbridge"
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

# Asset folder name contains CJK; resolve via wildcard under assets/
$assetsParent = Join-Path $RepoRoot "assets"
$assetDirs = @(Get-ChildItem -LiteralPath $assetsParent -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "XNXS20240725003*" })
if ($assetDirs.Count -eq 0) {
    throw ("Asset folder not found under {0} matching XNXS20240725003*" -f $assetsParent)
}
$AssetsDir = $assetDirs[0].FullName

$FixturesDir = Join-Path $GraphRoot "fixtures"
$InternalDir = Join-Path $PSScriptRoot "internal"
$SnapName = "b94c5e7e31e77b9eb42ec009e8deeb49.png"

if ([string]::IsNullOrWhiteSpace($DestDir)) {
    $DestDir = Join-Path $RepoRoot "_tmp\xnxs20240725003-weighbridge-package"
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
            "Run-XnxsWeighbridge.cmd",
            "Run-XnxsWeighbridge.ps1",
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

    $cmdSrc = Join-Path $InternalDir "Run-XnxsWeighbridge.cmd"
    $ps1Src = Join-Path $InternalDir "Run-XnxsWeighbridge.ps1"
    if (-not (Test-Path -LiteralPath $cmdSrc)) { throw "Missing: $cmdSrc" }
    if (-not (Test-Path -LiteralPath $ps1Src)) { throw "Missing: $ps1Src" }

    Copy-LiteralFile -From $cmdSrc -To (Join-Path $DestDir "Run-XnxsWeighbridge.cmd")
    Copy-LiteralFile -From $ps1Src -To (Join-Path $DestDir "Run-XnxsWeighbridge.ps1")

    $fixPng = Join-Path $FixturesDir $SnapName
    if (-not (Test-Path -LiteralPath $fixPng)) {
        throw ("Fixture PNG missing after sync: {0}" -f $fixPng)
    }
    Copy-LiteralFile -From $fixPng -To (Join-Path $DestDir $SnapName)
    Copy-LiteralFile -From $fixPng -To (Join-Path $DestDir "test_pic.png")

    $readme = @(
        "XNXS20240725003 weighbridge portable probe"
        ""
        "Scenario:"
        "  buildLicenseNo = XNXS20240725003"
        "  carNo          = ZheA12345"
        "  goodsWeight    = 1385"
        "  endpoint       = http://191.12.15.58:8899/sapi/v1/inoutRecord/lantu/saveRecord"
        ""
        "Usage (on VPN / internal host):"
        "  1. Keep these three files in the same folder"
        "  2. Double-click Run-XnxsWeighbridge.cmd"
        "  3. Type YES when prompted"
        "  4. Collect output\<timestamp>\ back for review"
        ""
        "Source Graph: pipelines/graphs/govsync/xnxs20240725003-weighbridge"
        "Assets: assets/XNXS20240725003..."
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
Write-Host "  - powershell -ExecutionPolicy Bypass -File pipelines/graphs/govsync/xnxs20240725003-weighbridge/scripts/Invoke-XnxsWeighbridge.ps1"
exit 0
