#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: expand 2026-01 sand monthly totals to §2.2 addBatch dry-run JSON.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [switch] $EmbedPhotos
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$ToolPath = Join-Path $GraphRoot "scripts\expand-january.mjs"
$SeedsPath = Join-Path $GraphRoot "seeds\monthly-totals.yaml"

Write-Host "[sand-addbatch-2026-01] starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing tool: $ToolPath" }
if (-not (Test-Path -LiteralPath $SeedsPath)) { throw "Missing seeds: $SeedsPath" }

$csvDir = Join-Path $RepoRoot "pipelines\graphs\materialclient\recycle-wenyixilu-export\out\latest\csv"
if (-not (Test-Path -LiteralPath (Join-Path $csvDir "AttachmentFiles.csv"))) {
    throw "Missing Q9 pool CSV under $csvDir — run recycle-wenyixilu-export first."
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path $GraphRoot "runs\$stamp"
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw "Node.js not found on PATH (need 22.5+)." }

$argList = @(
    $ToolPath,
    "--outDir", $RunDir,
    "--seeds", $SeedsPath,
    "--csvDir", $csvDir
)
if ($EmbedPhotos) { $argList += "--embedPhotos" }

& node @argList
if ($LASTEXITCODE -ne 0) {
    throw "expand-january.mjs failed with exit $LASTEXITCODE"
}

$outLatest = Join-Path $GraphRoot "out\latest"
if (Test-Path -LiteralPath $outLatest) {
    Remove-Item -LiteralPath $outLatest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outLatest | Out-Null
Copy-Item -LiteralPath (Join-Path $RunDir "dry-run") -Destination (Join-Path $outLatest "dry-run") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RunDir "photo-manifest.jsonl") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "summary.json") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "report.md") -Destination $outLatest -Force

Write-Host "[done] runDir=$RunDir"
Write-Host "[done] mirrored -> $outLatest"
Write-Host "Gate: reply pass / fail + object + reason."