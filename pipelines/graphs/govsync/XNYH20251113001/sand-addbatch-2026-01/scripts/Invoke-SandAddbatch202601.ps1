#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: expand 2026-01 sand totals to pending-POST JSON (NO HTTP).
  Graph: pipelines/graphs/govsync/XNYH20251113001/sand-addbatch-2026-01/

  Default: preserve posted|smoke-posted from submit state; regenerate remaining
  tonnage under current Q5 (net~50 / tare~20 / gross~70). Month Σnet conserved.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [string] $PreserveState = "",
    [string] $ExistingJsonDir = "",
    [switch] $NoPreserve,
    [switch] $SyncSubmitSeeds
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$SiteRoot = Split-Path -Parent $GraphRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..\..")).Path
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsPath = Join-Path $GraphRoot "secrets.local.yaml"
$ToolRel = "scripts/expand-january.ts"
$ToolPath = Join-Path $GraphRoot $ToolRel
$SeedsPath = Join-Path $GraphRoot "seeds\monthly-totals.yaml"
$AddressesPath = Join-Path $GraphRoot "seeds\consignee-addresses.yaml"
$DefaultPreserveState = Join-Path $SiteRoot "sand-addbatch-submit\state\2026-01\submit-state.jsonl"
$DefaultExistingJsonDir = Join-Path $SiteRoot "sand-addbatch-submit\seeds\2026-01\source-run\2026-09-09T152356\json"
$SubmitSeedsMonthDir = Join-Path $SiteRoot "sand-addbatch-submit\seeds\2026-01"

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

Write-Host "[sand-addbatch-2026-01] starting (submitEnabled=false, pending-POST JSON only)..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing tool: $ToolPath" }
if (-not (Test-Path -LiteralPath $SeedsPath)) { throw "Missing seeds: $SeedsPath" }
if (-not (Test-Path -LiteralPath $AddressesPath)) { throw "Missing addresses: $AddressesPath" }

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

$usePreserve = -not $NoPreserve.IsPresent
if ($usePreserve) {
    if ([string]::IsNullOrWhiteSpace($PreserveState)) { $PreserveState = $DefaultPreserveState }
    if ([string]::IsNullOrWhiteSpace($ExistingJsonDir)) { $ExistingJsonDir = $DefaultExistingJsonDir }
    if (-not (Test-Path -LiteralPath $PreserveState)) {
        throw "Preserve state missing: $PreserveState (pass -NoPreserve for full regenerate)"
    }
    if (-not (Test-Path -LiteralPath $ExistingJsonDir)) {
        throw "Existing JSON dir missing: $ExistingJsonDir"
    }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path $GraphRoot "runs\$stamp"
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpm) { throw "pnpm not found on PATH (pipelines workspace)." }

$tsxPkg = Join-Path $PipelinesRoot "node_modules\tsx\package.json"
if (-not (Test-Path -LiteralPath $tsxPkg)) {
    Write-Host "[bind] tsx missing — running pnpm install in pipelines/"
    Push-Location $PipelinesRoot
    try {
        & pnpm install
        if ($LASTEXITCODE -ne 0) { throw "pnpm install failed with exit $LASTEXITCODE" }
    }
    finally { Pop-Location }
}

Write-Host "[bind] pointNumber=$pointNumber"
Write-Host "[bind] submitEnabled=false (no HTTP)"
if ($usePreserve) {
    Write-Host "[bind] preserveState=$PreserveState"
    Write-Host "[bind] existingJsonDir=$ExistingJsonDir"
}
else {
    Write-Host "[bind] preserve=OFF (full month regenerate)"
}

$tsxArgs = @(
    $ToolPath,
    "--outDir", $RunDir,
    "--seeds", $SeedsPath,
    "--csvDir", $csvDir,
    "--addresses", $AddressesPath,
    "--pointNumber", $pointNumber
)
if ($usePreserve) {
    $tsxArgs += @("--preserveState", $PreserveState, "--existingJsonDir", $ExistingJsonDir)
}

Push-Location $PipelinesRoot
try {
    & pnpm exec tsx @tsxArgs
    if ($LASTEXITCODE -ne 0) {
        throw "expand-january.ts failed with exit $LASTEXITCODE"
    }
}
finally { Pop-Location }

$outLatest = Join-Path $GraphRoot "out\latest"
if (Test-Path -LiteralPath $outLatest) {
    Remove-Item -LiteralPath $outLatest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outLatest | Out-Null
Copy-Item -LiteralPath (Join-Path $RunDir "json") -Destination (Join-Path $outLatest "json") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RunDir "ledgers") -Destination (Join-Path $outLatest "ledgers") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RunDir "submit-meta.json") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "photo-manifest.jsonl") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "summary.json") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "report.md") -Destination $outLatest -Force

$runId = Split-Path -Leaf $RunDir
if ($SyncSubmitSeeds.IsPresent -or $usePreserve) {
    $destRun = Join-Path $SubmitSeedsMonthDir "source-run\$runId"
    if (Test-Path -LiteralPath $destRun) {
        Remove-Item -LiteralPath $destRun -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $destRun | Out-Null
    Copy-Item -LiteralPath (Join-Path $RunDir "json") -Destination (Join-Path $destRun "json") -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $RunDir "ledgers") -Destination (Join-Path $destRun "ledgers") -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $RunDir "submit-meta.json") -Destination $destRun -Force
    Copy-Item -LiteralPath (Join-Path $RunDir "photo-manifest.jsonl") -Destination $destRun -Force
    Copy-Item -LiteralPath (Join-Path $RunDir "summary.json") -Destination $destRun -Force
    Copy-Item -LiteralPath (Join-Path $RunDir "report.md") -Destination $destRun -Force

    $sourceMd = @"
# Frozen pointer — 2026-01
month: "2026-01"
sourceRunId: "$runId"
copiedFrom: graphs/govsync/XNYH20251113001/sand-addbatch-2026-01/runs/$runId
copiedAt: "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
note: "Preserve posted (old Q5) + regenerate pending under Q5 net~50/tare~20/gross~70. Month tonnage conserved. Do not mix with other months."
"@
    [System.IO.File]::WriteAllText((Join-Path $SubmitSeedsMonthDir "SOURCE.md"), $sourceMd + "`n", [System.Text.UTF8Encoding]::new($false))

    $indexMd = Join-Path (Split-Path -Parent $SubmitSeedsMonthDir) "SOURCE.md"
    if (Test-Path -LiteralPath $indexMd) {
        $indexText = [System.IO.File]::ReadAllText($indexMd, [System.Text.Encoding]::UTF8)
        $indexReplacement = '${1}**active** — run `' + $runId + '` |'
        $indexText = [regex]::Replace(
            $indexText,
            '(?m)(\|\s*2026-01\s*\|\s*`seeds/2026-01/`\s*\|\s*).*$',
            $indexReplacement
        )
        [System.IO.File]::WriteAllText($indexMd, $indexText, [System.Text.UTF8Encoding]::new($false))
    }

    # Point submit config at new freeze (runDirRel only; leave month/state alone).
    $submitConfig = Join-Path $SiteRoot "sand-addbatch-submit\config.yaml"
    if (Test-Path -LiteralPath $submitConfig) {
        $cfg = [System.IO.File]::ReadAllText($submitConfig, [System.Text.Encoding]::UTF8)
        $newRel = "seeds/2026-01/source-run/$runId"
        $cfgReplacement = '${1}' + $newRel
        $cfg2 = [regex]::Replace($cfg, '(?m)^(  runDirRel:\s*).+$', $cfgReplacement)
        if ($cfg2 -ne $cfg) {
            [System.IO.File]::WriteAllText($submitConfig, $cfg2, [System.Text.UTF8Encoding]::new($false))
            Write-Host "[sync] submit config runDirRel -> $newRel"
        }
    }

    Write-Host "[sync] submit seeds -> $destRun"
}

Write-Host "[done] runDir=$RunDir"
Write-Host "[done] mirrored -> $outLatest"
Write-Host "Gate: review pending-POST JSON params, reply pass / fail + object + reason."
Write-Host "NOTE: this Graph never POSTs."
