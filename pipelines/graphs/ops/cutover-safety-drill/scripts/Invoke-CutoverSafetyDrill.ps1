#Requires -Version 5.1
<#
.SYNOPSIS
  Probe cook: rollback export against the deployed UrbanManagement Phase 2 stack.
.DESCRIPTION
  Over SSH: `export-sqlite` of all SQL Server rows into a copy of the newest pre-cutover SQLite import source
  inside a throwaway container. The live database is only read; only the export JSON report is kept under import/.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SharedDir = Join-Path $RepoRoot "pipelines\_shared\ops\ssh"
$SharedResolve = Join-Path $SharedDir "Resolve-SshIdentity.ps1"
$SharedUnlock = Join-Path $SharedDir "Unlock-SshIdentity.ps1"
$SharedInvoke = Join-Path $SharedDir "Invoke-SshRemote.ps1"
$RemoteScript = Join-Path $PSScriptRoot "remote-urban-drill.sh"

function Get-YamlScalar {
    param([string] $Text, [string] $Key, [int] $Indent = 0)
    $pattern = '(?m)^' + [regex]::Escape(" " * $Indent) + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        return $v.Trim('"').Trim("'")
    }
    return $null
}
function Write-Utf8NoBom([string] $Path, [string] $Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}
function Get-Marks([string] $Text) {
    $m = [ordered]@{}
    foreach ($line in ($Text -split "\r?\n")) { if ($line -match '^@@ ([A-Z0-9_]+)=(.*)$') { $m[$Matches[1]] = $Matches[2].Trim() } }
    return $m
}

Write-Host "[cutover-safety-drill] starting"
$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
function C([string] $Key, [string] $Default) { $v = Get-YamlScalar $configText $Key 2; if ([string]::IsNullOrWhiteSpace($v)) { $Default } else { $v } }
$identityName = C "identityFileName" "docker-linux-ed25519"
$secretsLocal = Join-Path $GraphRoot ((C "secretsRel" "../deploy-urban-acceptance/secrets.local.yaml") -replace '/', '\')
if (-not (Test-Path -LiteralPath $secretsLocal)) { throw "Missing $secretsLocal (SSH target)." }
$secretsText = [System.IO.File]::ReadAllText($secretsLocal, [System.Text.Encoding]::UTF8)
$hostVal = Get-YamlScalar $secretsText "host" 0
$userVal = Get-YamlScalar $secretsText "user" 0
$portVal = 2222; [void][int]::TryParse((Get-YamlScalar $secretsText "port" 0), [ref]$portVal)
$passVal = Get-YamlScalar $secretsText "identityPassphrase" 0

if (-not $SkipConfirm) {
    Write-Host "[cutover-safety-drill] ssh=${userVal}@${hostVal}:$portVal (rollback export; live DB read-only)"
    if ((Read-Host "Continue? [y/N]") -notmatch '^(y|yes)$') { throw "Aborted by user." }
}
if ([string]::IsNullOrWhiteSpace($RunDir)) { $RunDir = Join-Path $GraphRoot ("runs\" + (Get-Date -Format "yyyy-MM-ddTHHmmss")) }
if (Test-Path -LiteralPath $RunDir) { throw "Run dir already exists (runs/ are append-only): $RunDir" }
$runId = Split-Path -Leaf $RunDir
$prepareDir = Join-Path $RunDir "prepare"
New-Item -ItemType Directory -Force -Path $prepareDir | Out-Null

$remoteB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(
        ([System.IO.File]::ReadAllText($RemoteScript, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n")))
$batchPath = $null
$marks = [ordered]@{}
$probeError = $null
try {
    $identityForSsh = $identityName
    if (-not [string]::IsNullOrWhiteSpace($passVal)) {
        $unlocked = & $SharedUnlock -Passphrase $passVal -RepoRoot $RepoRoot -IdentityFileName $identityName -PassThru
        $identityForSsh = [string]$unlocked.identityFileName
        $batchPath = [string]$unlocked.identityFile
    }
    else { [void](& $SharedResolve -RepoRoot $RepoRoot -IdentityFileName $identityName -HardenAcl -PassThru) }
    $s = @{ HostName = $hostVal; User = $userVal; Port = $portVal; RepoRoot = $RepoRoot; IdentityFileName = $identityForSsh }
    $safeRun = $runId -replace '[^0-9A-Za-z-]', ''
    $r = & $SharedInvoke @s -RemoteCommand "bash <(echo $remoteB64 | base64 -d) $safeRun" `
        -EvidenceDir (Join-Path $RunDir "ssh-drill") -ConnectTimeoutSeconds 20 -SkipDestructiveCheck
    $marks = Get-Marks ([string]$r.stdout)
}
catch { $probeError = $_.Exception.Message }
finally {
    if ($batchPath -and (Test-Path -LiteralPath $batchPath)) {
        & icacls.exe $batchPath /grant:r "${env:USERNAME}:(F)" | Out-Null
        Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
    }
}

function M([string] $k) { if ($marks.Contains($k)) { [string]$marks[$k] } else { "" } }
$checks = [ordered]@{
    "rollback-export"  = (M "EXPORT_EXIT") -eq "0" -and (M "EXPORT_RESULT") -eq "passed" -and (M "EXPORT_CHECKS_FAILED") -eq "0" -and (M "EXPORT_BLOCKING") -eq "0"
    "export-formats"   = [int]("0" + (M "EXPORT_FORMAT_CHECKS")) -ge 1
}
$failed = @($checks.Keys | Where-Object { -not $checks[$_] })
$resultText = if (-not $marks.Count) { "blocked" } elseif ($failed.Count -eq 0) { "pass" } else { "fail" }
$p0 = (M "SUDO_NOPASSWD") -eq "yes"
$p1 = (M "DONE") -eq "yes"
$p2 = $resultText -eq "pass"

Write-Utf8NoBom (Join-Path $prepareDir "drill-parse.json") (([ordered]@{ analyzedBy = "agent"; result = $resultText; failedChecks = $failed; checks = $checks; markers = $marks; error = $probeError }) | ConvertTo-Json -Depth 5)
Write-Utf8NoBom (Join-Path $RunDir "summary.json") (([ordered]@{
            graphId = "cutover-safety-drill"; graphPath = "pipelines/graphs/ops/cutover-safety-drill"; runId = $runId; result = $resultText
            failedChecks = $failed; error = $probeError
            levels = [ordered]@{ P0 = $p0; P1 = $p1; P2 = $p2; P3 = "user-only" }
        }) | ConvertTo-Json -Depth 4)
$checkMd = ($checks.Keys | ForEach-Object { "| $_ | $(if ($checks[$_]) { 'pass' } else { 'FAIL' }) |" }) -join "`n"
$markMd = ($marks.Keys | ForEach-Object { "| $_ | $($marks[$_]) |" }) -join "`n"
Write-Utf8NoBom (Join-Path $RunDir "report.md") @"
# cutover-safety-drill report — Agent analysis

- run: ``$runId`` · result: ``$resultText``
- P0/P1/P2: $p0 / $p1 / $p2

## Checks

| check | result |
|-------|--------|
$checkMd

## Markers

| key | value |
|-----|-------|
$markMd

证据：``prepare/`` ``ssh-drill/``。Pipeline 结果不是产品 APPROVED；P3 由用户确认。
"@
Write-Utf8NoBom (Join-Path $RunDir "acceptance.md") @"
# Acceptance — cutover-safety-drill (run $runId)

| 项 | 值 |
|----|----|
| P0 | $(if ($p0) { "pass" } else { "fail" }) |
| P1 | $(if ($p1) { "pass" } else { "fail" }) |
| P2 | $(if ($p2) { "pass" } else { "fail" }) |
| P3（用户采纳） | pending |
"@
Write-Host "[cutover-safety-drill] result=$resultText failed=$($failed -join ',')"
if ($resultText -eq "pass") { exit 0 } else { exit 1 }
