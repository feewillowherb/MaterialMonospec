#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: expand 2026-01 sand totals to review JSON (NO POST).
  Graph: pipelines/graphs/govsync/XNYH20251113001/sand-addbatch-2026-01/
#>
[CmdletBinding()]
param(
    [string] $RunDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsPath = Join-Path $GraphRoot "secrets.local.yaml"
$ToolPath = Join-Path $GraphRoot "scripts\expand-january.mjs"
$SeedsPath = Join-Path $GraphRoot "seeds\monthly-totals.yaml"

function Get-YamlScalar {
    param([string] $Text, [string] $Key)
    $pattern = '(?m)^(?:\s*)' + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        if ($v.StartsWith("'") -and $v.EndsWith("'")) { return $v.Substring(1, $v.Length - 2) }
        if ($v.StartsWith('"') -and $v.EndsWith('"')) { return $v.Substring(1, $v.Length - 2) }
        return $v
    }
    return $null
}

Write-Host "[sand-addbatch-2026-01] starting (submitEnabled=false, JSON review only)..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing tool: $ToolPath" }
if (-not (Test-Path -LiteralPath $SeedsPath)) { throw "Missing seeds: $SeedsPath" }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$submitFlag = Get-YamlScalar -Text $configText -Key "submitEnabled"
if ($submitFlag -eq "true") {
    throw "Refusing to run: config.submitEnabled=true. This Graph must stay submitEnabled=false."
}

$pointNumber = Get-YamlScalar -Text $configText -Key "pointNumber"
if ([string]::IsNullOrWhiteSpace($pointNumber)) { $pointNumber = "XNYH20251113001" }

if (Test-Path -LiteralPath $SecretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($SecretsPath, [System.Text.Encoding]::UTF8)
    $pnOverride = Get-YamlScalar -Text $secretsText -Key "pointNumber"
    if (-not [string]::IsNullOrWhiteSpace($pnOverride)) { $pointNumber = $pnOverride }
}

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

Write-Host "[bind] pointNumber=$pointNumber"
Write-Host "[bind] submitEnabled=false (no HTTP)"

& node $ToolPath --outDir $RunDir --seeds $SeedsPath --csvDir $csvDir --pointNumber $pointNumber
if ($LASTEXITCODE -ne 0) {
    throw "expand-january.mjs failed with exit $LASTEXITCODE"
}

$outLatest = Join-Path $GraphRoot "out\latest"
if (Test-Path -LiteralPath $outLatest) {
    Remove-Item -LiteralPath $outLatest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outLatest | Out-Null
Copy-Item -LiteralPath (Join-Path $RunDir "json") -Destination (Join-Path $outLatest "json") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RunDir "submit-meta.json") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "photo-manifest.jsonl") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "summary.json") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "report.md") -Destination $outLatest -Force

Write-Host "[done] runDir=$RunDir"
Write-Host "[done] mirrored -> $outLatest"
Write-Host "Gate: review JSON params, reply pass / fail + object + reason."
Write-Host "NOTE: this Graph never POSTs."