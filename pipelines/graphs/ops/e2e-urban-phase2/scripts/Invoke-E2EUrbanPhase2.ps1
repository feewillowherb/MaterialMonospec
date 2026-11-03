#Requires -Version 5.1
<#
.SYNOPSIS
  Probe cook: end-to-end client flow against the UrbanManagement Phase 2 stack through the public gateway port.
.DESCRIPTION
  A synthetic MaterialClient.Urban (UrbanE2EClient.cs, run with `dotnet run`) connects from this machine to
  http://<host>:<port>: hub over WebSockets and SSE, UploadStatus, client-list, tus create/PATCH/HEAD/commit,
  receive, approve (console) with WeighingRecordApproved push, pending/ack. Record B is then approved inside
  um-ingest over SSH: only the SignalR Redis backplane can deliver that push to the client on um-console.
  Finally the VM side reports which role logged each push and deletes every probe row, file and Redis key.
  Writes to the acceptance database and the shared Uploads (dedicated E2E-PROBE folder), always cleaned up.
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
$ClientScript = Join-Path $PSScriptRoot "UrbanE2EClient.cs"
$RemoteScript = Join-Path $PSScriptRoot "remote-urban-e2e.sh"

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
function Read-Shared([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    $fs = [System.IO.File]::Open($Path, "Open", "Read", "ReadWrite")
    try { return (New-Object System.IO.StreamReader($fs)).ReadToEnd() } finally { $fs.Dispose() }
}
function Get-Marks([string] $Text) {
    $m = [ordered]@{}
    foreach ($line in ($Text -split "\r?\n")) { if ($line -match '^@@ ([A-Z0-9_]+)=(.*)$') { $m[$Matches[1]] = $Matches[2].Trim() } }
    return $m
}

Write-Host "[e2e-urban-phase2] starting"
$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
function C([string] $Key, [string] $Default) { $v = Get-YamlScalar $configText $Key 2; if ([string]::IsNullOrWhiteSpace($v)) { $Default } else { $v } }
$baseUrl = C "baseUrl" "http://191.12.234.212:5333"
$licenseNo = C "probeLicenseNo" "E2E-PROBE"
$backplaneWait = C "backplaneWaitSeconds" "60"
$identityName = C "identityFileName" "docker-linux-ed25519"
$secretsLocal = Join-Path $GraphRoot ((C "secretsRel" "../deploy-urban-acceptance/secrets.local.yaml") -replace '/', '\')
if (-not $licenseNo.StartsWith("E2E-")) { throw "probeLicenseNo must start with E2E- (cleanup deletes that Uploads folder)." }
if (-not (Test-Path -LiteralPath $secretsLocal)) { throw "Missing $secretsLocal (SSH target for the ingest approval and cleanup)." }
$secretsText = [System.IO.File]::ReadAllText($secretsLocal, [System.Text.Encoding]::UTF8)
$hostVal = Get-YamlScalar $secretsText "host" 0
$userVal = Get-YamlScalar $secretsText "user" 0
$portVal = 2222; [void][int]::TryParse((Get-YamlScalar $secretsText "port" 0), [ref]$portVal)
$passVal = Get-YamlScalar $secretsText "identityPassphrase" 0

if (-not $SkipConfirm) {
    Write-Host "[e2e-urban-phase2] target=$baseUrl ssh=${userVal}@${hostVal}:$portVal (writes probe data, then deletes it)"
    if ((Read-Host "Continue? [y/N]") -notmatch '^(y|yes)$') { throw "Aborted by user." }
}
if ([string]::IsNullOrWhiteSpace($RunDir)) { $RunDir = Join-Path $GraphRoot ("runs\" + (Get-Date -Format "yyyy-MM-ddTHHmmss")) }
if (Test-Path -LiteralPath $RunDir) { throw "Run dir already exists (runs/ are append-only): $RunDir" }
$runId = Split-Path -Leaf $RunDir
$prepareDir = Join-Path $RunDir "prepare"
New-Item -ItemType Directory -Force -Path $prepareDir | Out-Null

$proId = [guid]::NewGuid().ToString()
$clientId = "e2e-" + ($runId -replace '[^0-9]', '')
$remoteB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(
        ([System.IO.File]::ReadAllText($RemoteScript, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n")))
function Remote([string] $ArgsLine, [string] $Name) {
    $s = $script:sshCommon
    $r = & $SharedInvoke @s -RemoteCommand "bash <(echo $remoteB64 | base64 -d) $ArgsLine" `
        -EvidenceDir (Join-Path $RunDir "ssh-$Name") -ConnectTimeoutSeconds 20 -SkipDestructiveCheck
    return Get-Marks ([string]$r.stdout)
}

$batchPath = $null
$script:sshCommon = $null
$marks = [ordered]@{}
$clientProc = $null
try {
    $identityForSsh = $identityName
    if (-not [string]::IsNullOrWhiteSpace($passVal)) {
        $unlocked = & $SharedUnlock -Passphrase $passVal -RepoRoot $RepoRoot -IdentityFileName $identityName -PassThru
        $identityForSsh = [string]$unlocked.identityFileName
        $batchPath = [string]$unlocked.identityFile
    }
    else { [void](& $SharedResolve -RepoRoot $RepoRoot -IdentityFileName $identityName -HardenAcl -PassThru) }
    $script:sshCommon = @{ HostName = $hostVal; User = $userVal; Port = $portVal; RepoRoot = $RepoRoot; IdentityFileName = $identityForSsh }

    Write-Host "[e2e-urban-phase2] building client"
    $ErrorActionPreference = "Continue"
    & dotnet build $ClientScript -v q --nologo *> (Join-Path $prepareDir "client-build.log")
    $buildExit = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($buildExit -ne 0) { throw "Client build failed (see prepare/client-build.log)" }

    $clientOut = Join-Path $prepareDir "client-stdout.txt"
    $clientErr = Join-Path $prepareDir "client-stderr.txt"
    Write-Host "[e2e-urban-phase2] client proId=$proId clientId=$clientId"
    $clientProc = Start-Process dotnet -PassThru -NoNewWindow -RedirectStandardOutput $clientOut -RedirectStandardError $clientErr `
        -ArgumentList @("run", "--no-build", "--file", "`"$ClientScript`"", "--", $baseUrl, $proId, $clientId, $licenseNo, $backplaneWait)

    $recordB = $null
    $deadline = (Get-Date).AddMinutes(3)
    while (-not $clientProc.HasExited -and (Get-Date) -lt $deadline -and -not $recordB) {
        Start-Sleep -Milliseconds 500
        $text = Read-Shared $clientOut
        if ($text -match '(?m)^@@ AWAIT_INGEST_APPROVE=([0-9a-fA-F-]{36})') { $recordB = $Matches[1] }
    }
    if ($recordB) {
        $body = '{"clientRecordId":"' + $recordB + '","plateNumber":"' + [char]0x6D59 + 'A12345","totalWeight":12}'
        $bodyB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($body))
        foreach ($e in (Remote "approve-in-ingest $bodyB64" "approve").GetEnumerator()) { if ($e.Key -ne "DONE") { $marks[$e.Key] = $e.Value } }
    }
    if (-not $clientProc.WaitForExit(([int]$backplaneWait + 60) * 1000)) { $clientProc.Kill(); $marks["CLIENT_KILLED"] = "yes" }
    $clientMarks = Get-Marks (Read-Shared $clientOut)
    foreach ($e in $clientMarks.GetEnumerator()) { $marks[$e.Key] = $e.Value }
}
finally {
    if ($clientProc -and -not $clientProc.HasExited) { $clientProc.Kill() }
    $recA = if ($marks.Contains("RECORD_A")) { $marks["RECORD_A"] } else { "none" }
    $recB = if ($marks.Contains("AWAIT_INGEST_APPROVE")) { $marks["AWAIT_INGEST_APPROVE"] } else { "none" }
    if ($script:sshCommon) {
        try {
            foreach ($e in (Remote "evidence-cleanup $proId $clientId $licenseNo $recA $recB" "cleanup").GetEnumerator()) { $marks[$e.Key] = $e.Value }
        }
        catch { $marks["CLEANUP_ERROR"] = $_.Exception.Message }
    }
    if ($batchPath -and (Test-Path -LiteralPath $batchPath)) {
        & icacls.exe $batchPath /grant:r "${env:USERNAME}:(F)" | Out-Null
        Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
    }
}

function M([string] $k) { if ($marks.Contains($k)) { [string]$marks[$k] } else { "" } }
$checks = [ordered]@{
    "hub-websockets"      = (M "HUB_WS_CONNECTED") -eq "True" -and (M "HUB_WS_HELLO") -eq "True"
    "hub-sse"             = (M "HUB_SSE_HELLO") -eq "True"
    "client-online"       = (M "CLIENT_LIST_ONLINE") -eq "True"
    "tus-r9"              = (M "TUS_CREATE_HTTP") -eq "201" -and (M "TUS_LOCATION_EXTERNAL") -eq "True" -and (M "TUS_HEAD_HTTP") -eq "200" -and (M "TUS_HEAD_OFFSET") -eq "0" -and (M "TUS_PATCH_HTTP") -eq "204" -and (M "TUS_PATCH_OFFSET_OK") -eq "True"
    "tus-r10-commit"      = (M "TUS_COMMIT_HTTP") -eq "200" -and (M "TUS_ATTACHMENT_IDS") -eq "1"
    "receive-r2"          = (M "R2_A_HTTP") -eq "200" -and (M "R2_A_HAS_RECORD_ID") -eq "True" -and (M "R2_B_HTTP") -eq "200"
    "approve-push-console" = (M "APPROVE_A_HTTP") -eq "200" -and (M "PUSH_A_RECEIVED") -eq "True" -and (M "PUSH_LOG_CONSOLE_A") -eq "1"
    "pending-ack-r3-r4"   = (M "R3_CONTAINS_A") -eq "True" -and (M "R4_HTTP") -in @("200", "204") -and (M "R3_AFTER_ACK_CONTAINS_A") -eq "False"
    "backplane-ingest-push" = (M "INGEST_APPROVE_HTTP") -eq "200" -and (M "PUSH_B_RECEIVED") -eq "True" -and (M "PUSH_LOG_INGEST_B") -eq "1" -and (M "PUSH_LOG_CONSOLE_B") -eq "0"
    "cleanup"             = (M "AFTER_ROWS_RECORDS") -eq "0" -and (M "AFTER_ROWS_ATTACHMENTS") -eq "0" -and (M "AFTER_ROWS_ONLINE") -eq "0" -and (M "AFTER_FILES") -eq "0" -and (M "AFTER_REDIS_KEYS") -eq "0"
}
$failed = @($checks.Keys | Where-Object { -not $checks[$_] })
$resultText = if (-not $marks.Count) { "blocked" } elseif ($failed.Count -eq 0 -and -not (M "CLIENT_ERROR")) { "pass" } else { "fail" }
$p0 = (M "HUB_WS_CONNECTED") -eq "True"
$p1 = (M "CLIENT_DONE") -eq "yes" -and (M "DONE") -eq "yes"
$p2 = $resultText -eq "pass"

Write-Utf8NoBom (Join-Path $prepareDir "e2e-parse.json") (([ordered]@{ analyzedBy = "agent"; result = $resultText; failedChecks = $failed; checks = $checks; markers = $marks }) | ConvertTo-Json -Depth 5)
Write-Utf8NoBom (Join-Path $RunDir "summary.json") (([ordered]@{
            graphId = "e2e-urban-phase2"; graphPath = "pipelines/graphs/ops/e2e-urban-phase2"; runId = $runId; result = $resultText
            baseUrl = $baseUrl; proId = $proId; clientId = $clientId; failedChecks = $failed
            levels = [ordered]@{ P0 = $p0; P1 = $p1; P2 = $p2; P3 = "user-only" }
        }) | ConvertTo-Json -Depth 4)
$checkMd = ($checks.Keys | ForEach-Object { "| $_ | $(if ($checks[$_]) { 'pass' } else { 'FAIL' }) |" }) -join "`n"
$markMd = ($marks.Keys | ForEach-Object { "| $_ | $($marks[$_]) |" }) -join "`n"
Write-Utf8NoBom (Join-Path $RunDir "report.md") @"
# e2e-urban-phase2 report — Agent analysis

- run: ``$runId`` · result: ``$resultText`` · target: ``$baseUrl``
- probe ProId ``$proId`` · ClientId ``$clientId`` (synthetic; deleted at the end)
- P0/P1/P2: $p0 / $p1 / $p2

## Checks

| check | result |
|-------|--------|
$checkMd

## Markers

| key | value |
|-----|-------|
$markMd

证据：``prepare/`` ``ssh-*/``。Pipeline 结果不是产品 APPROVED；P3 由用户确认。
"@
Write-Utf8NoBom (Join-Path $RunDir "acceptance.md") @"
# Acceptance — e2e-urban-phase2 (run $runId)

| 项 | 值 |
|----|----|
| P0 | $(if ($p0) { "pass" } else { "fail" }) |
| P1 | $(if ($p1) { "pass" } else { "fail" }) |
| P2 | $(if ($p2) { "pass" } else { "fail" }) |
| P3（用户采纳） | pending |
"@
Write-Host "[e2e-urban-phase2] result=$resultText failed=$($failed -join ',')"
if ($resultText -eq "pass") { exit 0 } else { exit 1 }
