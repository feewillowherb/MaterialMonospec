#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: set SolidWasteInfo.UseIndependentDisplayedNet on 3 Waybills (Node/TS + node:sqlite).
#>
[CmdletBinding()]
param(
    [switch] $Write,
    [switch] $SkipConfirm,
    [string] $RunDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsPath = Join-Path $GraphRoot "secrets.local.yaml"
$ToolPath = Join-Path $GraphRoot "scripts/set-independent-net-flag.ts"
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..")).Path

function Get-YamlScalar {
    param([string] $Text, [string] $Key, [int] $Indent = 2)
    $pad = " " * $Indent
    $pattern = '(?m)^' + [regex]::Escape($pad) + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
        if ($v.StartsWith("'") -and $v.EndsWith("'")) { $v = $v.Substring(1, $v.Length - 2) }
        return $v
    }
    return $null
}

function Resolve-RepoPath {
    param([string] $RelOrAbs)
    if ([string]::IsNullOrWhiteSpace($RelOrAbs)) { return $null }
    if ([System.IO.Path]::IsPathRooted($RelOrAbs)) { return $RelOrAbs }
    $fromGraph = Join-Path $GraphRoot $RelOrAbs
    if (Test-Path -LiteralPath $fromGraph) { return (Resolve-Path -LiteralPath $fromGraph).Path }
    $fromRepo = Join-Path $RepoRoot $RelOrAbs
    return $fromRepo
}

Write-Host "[solidwaste-legacy-net-flag-ingest] starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing tool: $ToolPath" }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$dbRel = Get-YamlScalar -Text $configText -Key "databaseRel"
$dryRunYaml = Get-YamlScalar -Text $configText -Key "dryRun"
$flagKey = Get-YamlScalar -Text $configText -Key "flagKey"
$flagValueYaml = Get-YamlScalar -Text $configText -Key "flagValue"

$databasePath = Resolve-RepoPath $dbRel
if (Test-Path -LiteralPath $SecretsPath) {
    $sec = [System.IO.File]::ReadAllText($SecretsPath, [System.Text.Encoding]::UTF8)
    $override = Get-YamlScalar -Text $sec -Key "databasePath" -Indent 0
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        $databasePath = Resolve-RepoPath $override
    }
}

if (-not (Test-Path -LiteralPath $databasePath)) {
    throw "Missing database: $databasePath"
}

$willWrite = $Write.IsPresent -or ($dryRunYaml -eq "false")
if ($willWrite -and -not $SkipConfirm) {
    Write-Host "WARNING: Will WRITE ExtraProperties into $databasePath" -ForegroundColor Yellow
    $ans = Read-Host "Type YES to continue"
    if ($ans -ne "YES") { throw "Aborted at write gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

# Parse targets from config.yaml (simple line-oriented extract)
$targets = @()
$inTargets = $false
$cur = $null
foreach ($line in ($configText -split "`r?`n")) {
    if ($line -match '^\s{2}targets:\s*$') { $inTargets = $true; continue }
    if ($inTargets -and $line -match '^[a-zA-Z]') { break }
    if (-not $inTargets) { continue }
    if ($line -match '^\s{4}-\s+plateNumber:\s*(.+)$') {
        if ($null -ne $cur) { $targets += $cur }
        $p = $Matches[1].Trim().Trim('"').Trim("'")
        $cur = [ordered]@{ plateNumber = $p; joinTime = ""; outTime = "" }
        continue
    }
    if ($null -eq $cur) { continue }
    if ($line -match '^\s{6}joinTime:\s*(.+)$') {
        $cur.joinTime = $Matches[1].Trim().Trim('"').Trim("'")
    }
    elseif ($line -match '^\s{6}outTime:\s*(.+)$') {
        $cur.outTime = $Matches[1].Trim().Trim('"').Trim("'")
    }
}
if ($null -ne $cur) { $targets += $cur }
if ($targets.Count -lt 1) { throw "No scenario.targets parsed from config.yaml" }

$scenario = [ordered]@{
    dryRun    = (-not $willWrite)
    flagKey   = $(if ($flagKey) { $flagKey } else { "SolidWasteInfo.UseIndependentDisplayedNet" })
    flagValue = ($flagValueYaml -ne "false")
    targets   = $targets
}
$scenarioPath = Join-Path $RunDir "scenario.json"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($scenarioPath, ($scenario | ConvertTo-Json -Depth 5), $utf8)

Push-Location $PipelinesRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $PipelinesRoot "node_modules\tsx"))) {
        Write-Host "pnpm install in pipelines/..."
        pnpm install
    }
    $nodeArgs = @(
        "exec", "tsx", $ToolPath,
        "--database", $databasePath,
        "--runDir", $RunDir,
        "--scenarioJson", $scenarioPath
    )
    if ($willWrite) { $nodeArgs += "--write" }
    & pnpm @nodeArgs
    $rc = $LASTEXITCODE
}
finally {
    Pop-Location
}

Write-Host "[solidwaste-legacy-net-flag-ingest] done. runDir=$RunDir exit=$rc"
Write-Host "Please accept: pass / fail + object + reason (P3 user only)."
exit $rc
