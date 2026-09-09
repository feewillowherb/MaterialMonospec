#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental: sand-addbatch-submit bind/validate (NO auto POST).

  Default: submitEnabled=false → verify source run only, exit 0, zero HTTP.
  Real POST is not implemented in this scaffold; flipping submitEnabled alone
  still refuses until a future cook is added AND -AllowPost is passed.
#>
[CmdletBinding()]
param(
    [switch] $AllowPost,
    [string] $RunDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsPath = Join-Path $GraphRoot "secrets.local.yaml"
$SourceRunRelDefault = "seeds\source-run\2026-09-09T145649"

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

Write-Host "[sand-addbatch-submit] starting (default: NO HTTP)..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$submitEnabled = Get-YamlScalar -Text $configText -Key "submitEnabled"
$runId = Get-YamlScalar -Text $configText -Key "runId"
if ([string]::IsNullOrWhiteSpace($runId)) { $runId = "2026-09-09T145649" }
$sourceRel = Get-YamlScalar -Text $configText -Key "runDirRel"
if ([string]::IsNullOrWhiteSpace($sourceRel)) { $sourceRel = $SourceRunRelDefault.Replace("\", "/") }

$sourceDir = Join-Path $GraphRoot (($sourceRel -replace "/", "\"))
if (-not (Test-Path -LiteralPath $sourceDir)) {
    throw "Missing frozen source run: $sourceDir"
}

$jsonDir = Join-Path $sourceDir "json"
$ledger = Join-Path $sourceDir "ledgers\dataNo-ledger.jsonl"
$submitMeta = Join-Path $sourceDir "submit-meta.json"
if (-not (Test-Path -LiteralPath $jsonDir)) { throw "Missing json/: $jsonDir" }
if (-not (Test-Path -LiteralPath $ledger)) { throw "Missing ledger: $ledger" }
if (-not (Test-Path -LiteralPath $submitMeta)) { throw "Missing submit-meta: $submitMeta" }

$partCount = @(Get-ChildItem -LiteralPath $jsonDir -Filter "*.json" -File).Count
$ledgerLines = @(Get-Content -LiteralPath $ledger | Where-Object { $_.Trim().Length -gt 0 }).Count
Write-Host "[bind] sourceRunId=$runId"
Write-Host "[bind] parts=$partCount ledgerRows=$ledgerLines"
Write-Host "[bind] submitEnabled=$submitEnabled AllowPost=$($AllowPost.IsPresent)"

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path $GraphRoot "runs\$stamp"
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$summary = [ordered]@{
    graph           = "sand-addbatch-submit"
    goal            = "gov-sand-product-addbatch-submit"
    site            = "XNYH20251113001"
    submitEnabled   = ($submitEnabled -eq "true")
    allowPost       = [bool]$AllowPost
    httpAttempted   = $false
    sourceRunId     = $runId
    sourceDir       = $sourceDir
    partCount       = $partCount
    ledgerRows      = $ledgerLines
    secretsPresent  = (Test-Path -LiteralPath $SecretsPath)
    mode            = "validate-only"
    levels          = @{
        L0 = "pass"
        L1 = "pass"
        L2 = "n/a"
        L3 = "pending-user"
    }
    message         = "Source run bound. submitEnabled=false — no HTTP. Flip config + implement cook before real POST."
}
$summaryPath = Join-Path $RunDir "summary.json"
($summary | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$report = @(
    "# sand-addbatch-submit report",
    "",
    "- submitEnabled: **$submitEnabled**",
    "- AllowPost: **$($AllowPost.IsPresent)**",
    "- httpAttempted: **false**",
    "- sourceRunId: $runId",
    "- parts: $partCount",
    "- ledgerRows: $ledgerLines",
    "- secrets.local.yaml present: $((Test-Path -LiteralPath $SecretsPath))",
    "",
    "## Levels",
    "",
    "- L0: pass (source readable)",
    "- L1: pass (no HTTP)",
    "- L2: n/a",
    "- L3: pending-user",
    "",
    "Default scaffold: **do not POST**. Prefer ``recycle-hmac-auth`` for empty-array auth probe.",
    ""
) -join "`n"
Set-Content -LiteralPath (Join-Path $RunDir "report.md") -Value $report -Encoding UTF8

if ($submitEnabled -eq "true" -or $AllowPost) {
    Write-Host "[gate] POST requested but cook not implemented in this scaffold — refusing HTTP." -ForegroundColor Yellow
    throw "Refusing POST: scaffold is validate-only. Implement cook + explicit ops runbook before enabling."
}

Write-Host "[done] validate-only runDir=$RunDir (no HTTP)"
Write-Host "NOTE: this Graph does not auto-POST."
