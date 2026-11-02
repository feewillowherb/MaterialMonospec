#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: waybill soft-delete join gap probe (read-only Node/TS + node:sqlite).
  Does NOT modify business code or write to the database.
#>
[CmdletBinding()]
param(
    [string] $DatabasePath = "",
    [string] $RunDir = "",
    [int] $SampleLimit = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsLocal = Join-Path $GraphRoot "secrets.local.yaml"
$ToolRel = "scripts/probe-softdelete-join.ts"
$ToolPath = Join-Path $GraphRoot $ToolRel
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..")).Path

function Get-YamlScalar {
    param([string] $Text, [string] $Key, [int] $Indent = 0)
    $pad = " " * $Indent
    $pattern = '(?m)^' + [regex]::Escape($pad) + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        if ($v.StartsWith('"') -and $v.EndsWith('"')) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        if ($v.StartsWith("'") -and $v.EndsWith("'")) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        return $v
    }
    return $null
}

Write-Host "[waybill-softdelete-join-probe] starting (read-only)..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing tool: $ToolPath" }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$sampleLimitYaml = Get-YamlScalar -Text $configText -Key "sampleLimit" -Indent 2
$dbHint = Get-YamlScalar -Text $configText -Key "databaseAbsHint" -Indent 2

$db = $DatabasePath
if ([string]::IsNullOrWhiteSpace($db) -and (Test-Path -LiteralPath $SecretsLocal)) {
    $secretsText = [System.IO.File]::ReadAllText($SecretsLocal, [System.Text.Encoding]::UTF8)
    $db = Get-YamlScalar -Text $secretsText -Key "databaseAbs" -Indent 0
}
if ([string]::IsNullOrWhiteSpace($db)) { $db = $dbHint }
if ([string]::IsNullOrWhiteSpace($db)) {
    throw "Missing database path. Set secrets.local.yaml databaseAbs or pass -DatabasePath."
}

if (-not (Test-Path -LiteralPath $db)) {
    throw "Database not found: $db"
}

$limit = $SampleLimit
if ($limit -le 0) {
    if ($sampleLimitYaml) { [void][int]::TryParse($sampleLimitYaml, [ref]$limit) }
}
if ($limit -le 0) { $limit = 20 }

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path $GraphRoot "runs\$stamp"
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

# Ensure tsx via pipelines workspace
$tsxOk = $false
Push-Location $PipelinesRoot
try {
    $null = & pnpm exec tsx --version 2>$null
    if ($LASTEXITCODE -eq 0) { $tsxOk = $true }
    if (-not $tsxOk) {
        Write-Host "[waybill-softdelete-join-probe] pnpm install (tsx)..."
        & pnpm install
        if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }
    }
    Write-Host "[waybill-softdelete-join-probe] database=$db"
    Write-Host "[waybill-softdelete-join-probe] runDir=$RunDir"
    & pnpm exec tsx $ToolPath --database $db --runDir $RunDir --sampleLimit $limit
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($code -ne 0) {
    throw "probe-softdelete-join.ts exited $code"
}

Write-Host "[waybill-softdelete-join-probe] done. Evidence: $RunDir"
Write-Host "等待用户验收，尚未通过。请回复 pass / fail + 对象与原因。"
