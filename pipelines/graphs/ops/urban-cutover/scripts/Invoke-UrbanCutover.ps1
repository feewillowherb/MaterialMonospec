#Requires -Version 5.1
<#
.SYNOPSIS
  Cook for ops/urban-cutover: readiness check or VM-side cutover (import + enable worker sync).
.DESCRIPTION
  Host-side IIS stop and 5233 entry switch remain human steps (see pipeline.md).
  Modes:
    check   (default) read-only readiness
    cutover requires -Apply and -SourceDb; refuses if productionPort still answers
#>
[CmdletBinding()]
param(
    [ValidateSet("check", "cutover")]
    [string] $Mode = "check",
    [switch] $Apply,
    [string] $SourceDb = "",
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
$SharedScp = Join-Path $SharedDir "Copy-ScpToRemote.ps1"
$RemoteScript = Join-Path $PSScriptRoot "remote-urban-cutover.sh"

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
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^@@ ([A-Z0-9_]+)=(.*)$') { $m[$Matches[1]] = $Matches[2].Trim() }
    }
    return $m
}
function Test-TcpPort([string] $HostName, [int] $Port) {
    try {
        return [bool](Test-NetConnection -ComputerName $HostName -Port $Port -WarningAction SilentlyContinue).TcpTestSucceeded
    }
    catch { return $false }
}

Write-Host "[urban-cutover] starting mode=$Mode"
$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
function C([string] $Key, [string] $Default) {
    $v = Get-YamlScalar $configText $Key 2
    if ([string]::IsNullOrWhiteSpace($v)) { $Default } else { $v }
}
$identityName = C "identityFileName" "docker-linux-ed25519"
$secretsLocal = Join-Path $GraphRoot ((C "secretsRel" "../deploy-urban-acceptance/secrets.local.yaml") -replace '/', '\')
if (-not (Test-Path -LiteralPath $secretsLocal)) { throw "Missing $secretsLocal" }
$secretsText = [System.IO.File]::ReadAllText($secretsLocal, [System.Text.Encoding]::UTF8)
$hostVal = Get-YamlScalar $secretsText "host" 0
$userVal = Get-YamlScalar $secretsText "user" 0
$portVal = 2222; [void][int]::TryParse((Get-YamlScalar $secretsText "port" 0), [ref]$portVal)
$passVal = Get-YamlScalar $secretsText "identityPassphrase" 0
$publicPort = [int](C "publicPort" "5333")
$prodPort = [int](C "productionPort" "5233")
$legacyRoot = C "legacyStorageRoot" "C:/wwwroot/UrbanManagement/Uploads"

if ($Mode -eq "cutover") {
    if (-not $Apply) { throw "cutover requires -Apply (destructive: drop DB, import, enable sync)." }
    if ([string]::IsNullOrWhiteSpace($SourceDb) -or -not (Test-Path -LiteralPath $SourceDb)) {
        throw "cutover requires -SourceDb path to the production UrbanManagement.db (include -wal/-shm siblings if present)."
    }
}

if (-not $SkipConfirm) {
    Write-Host "[urban-cutover] ssh=${userVal}@${hostVal}:$portVal mode=$Mode apply=$Apply"
    if ((Read-Host "Continue? [y/N]") -notmatch '^(y|yes)$') { throw "Aborted by user." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $RunDir = Join-Path $GraphRoot ("runs\" + (Get-Date -Format "yyyy-MM-ddTHHmmss"))
}
if (Test-Path -LiteralPath $RunDir) { throw "Run dir already exists: $RunDir" }
$runId = Split-Path -Leaf $RunDir
$prepareDir = Join-Path $RunDir "prepare"
New-Item -ItemType Directory -Force -Path $prepareDir | Out-Null

$iisUp = Test-TcpPort $hostVal $prodPort
$acceptanceReady = $false
try {
    $acceptanceReady = (Invoke-WebRequest "http://${hostVal}:$publicPort/health/ready" -UseBasicParsing -TimeoutSec 10).StatusCode -eq 200
}
catch { }

$remoteB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(
        ([System.IO.File]::ReadAllText($RemoteScript, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n")))
$batchPath = $null
$marks = [ordered]@{}
$probeError = $null
$gate = $null
try {
    $identityForSsh = $identityName
    if (-not [string]::IsNullOrWhiteSpace($passVal)) {
        $unlocked = & $SharedUnlock -Passphrase $passVal -RepoRoot $RepoRoot -IdentityFileName $identityName -PassThru
        $identityForSsh = [string]$unlocked.identityFileName
        $batchPath = [string]$unlocked.identityFile
    }
    else { [void](& $SharedResolve -RepoRoot $RepoRoot -IdentityFileName $identityName -HardenAcl -PassThru) }
    $s = @{ HostName = $hostVal; User = $userVal; Port = $portVal; RepoRoot = $RepoRoot; IdentityFileName = $identityForSsh }

    if ($Mode -eq "cutover") {
        if ($iisUp) {
            $gate = "iis-still-up"
            throw "Production port $prodPort on $hostVal is still open. Stop IIS first (K7), then re-run."
        }
        $stage = "/tmp/um-cutover/$runId"
        $localStage = Join-Path $prepareDir "db"
        New-Item -ItemType Directory -Force -Path $localStage | Out-Null
        Copy-Item -LiteralPath $SourceDb -Destination (Join-Path $localStage "source.db")
        foreach ($ext in @("-wal", "-shm")) {
            $sib = $SourceDb + $ext
            if (Test-Path -LiteralPath $sib) {
                Copy-Item -LiteralPath $sib -Destination (Join-Path $localStage "source.db$ext")
            }
        }
        [void](& $SharedInvoke @s -RemoteCommand "mkdir -p $stage" -EvidenceDir (Join-Path $RunDir "ssh-stage") -SkipDestructiveCheck)
        & $SharedScp -LocalPath @(Get-ChildItem -LiteralPath $localStage -File | ForEach-Object { $_.FullName }) `
            -RemoteDir $stage @s -EvidenceDir (Join-Path $RunDir "scp") | Out-Null
        $cmd = "LEGACY_ROOT='$legacyRoot' bash <(echo $remoteB64 | base64 -d) cutover $runId"
        $r = & $SharedInvoke @s -RemoteCommand $cmd -EvidenceDir (Join-Path $RunDir "ssh-cutover") `
            -ConnectTimeoutSeconds 20 -SkipDestructiveCheck
        $marks = Get-Marks ([string]$r.stdout)
    }
    else {
        $r = & $SharedInvoke @s -RemoteCommand "bash <(echo $remoteB64 | base64 -d) check" `
            -EvidenceDir (Join-Path $RunDir "ssh-check") -ConnectTimeoutSeconds 20 -SkipDestructiveCheck
        $marks = Get-Marks ([string]$r.stdout)
    }
}
catch {
    $probeError = $_.Exception.Message
    if (-not $gate -and $probeError -match 'iis-still-up|Stop IIS') { $gate = "iis-still-up" }
}
finally {
    if ($batchPath -and (Test-Path -LiteralPath $batchPath)) {
        & icacls.exe $batchPath /grant:r "${env:USERNAME}:(F)" | Out-Null
        Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
        Write-Host "[urban-cutover] removed temp batch identity"
    }
}

function M([string] $k) { if ($marks.Contains($k)) { [string]$marks[$k] } else { "" } }
function N([string] $k) { $v = 0; [void][int]::TryParse((M $k), [ref]$v); return $v }

$roleKeys = @("INGEST", "INGEST_2", "ATTACHMENT", "REALTIME", "ADMIN", "WORKER", "GATEWAY")
$rolesOk = @($roleKeys | Where-Object { (M "ROLE_$($_)_READY") -ne "200" -and $_ -ne "GATEWAY" }).Count -eq 0
# gateway ready is probed via READY_HTTP / external in cutover; in check via ROLE if present
$syncOff = ((M "ENV_SYNC") -in @("", "false", "False")) -and ((M "ENV_POLL") -in @("", "false", "False"))
$mountOk = (M "MOUNT") -in @("smb2", "cifs")
$addrOk = (M "ADDR") -like "192.168.250.10/*"

if ($Mode -eq "check") {
    $checks = [ordered]@{
        "ssh-done"          = (M "DONE") -eq "yes"
        "fixed-ip"          = $addrOk
        "smb-mounted"       = $mountOk
        "roles-ready"       = $rolesOk
        "sync-still-off"    = $syncOff -and (N "LOG_WORKER_GOVSYNC") -eq 0
        "acceptance-ready"  = $acceptanceReady
        "iis-still-serving" = $iisUp   # expected true before cutover day
    }
}
else {
    $checks = [ordered]@{
        "ssh-done"       = (M "DONE") -eq "yes"
        "iis-was-down"   = -not $iisUp
        "import-ok"      = (M "IMPORT_EXIT") -eq "0"
        "worker-govsync" = (N "LOG_WORKER_GOVSYNC") -ge 1
        "sync-on"        = (M "ENV_SYNC_AFTER") -in @("true", "True")
        "ready"          = (M "READY_HTTP") -eq "200" -or $acceptanceReady
    }
}

$failed = @($checks.Keys | Where-Object {
        if ($_ -eq "iis-still-serving") { return $false } # informational in check mode
        -not $checks[$_]
    })
$resultText = if ($gate) { "blocked" } elseif (-not $marks.Count -and $probeError) { "blocked" } elseif ($failed.Count -eq 0) { "pass" } else { "fail" }

Write-Utf8NoBom (Join-Path $prepareDir "parse.json") (([ordered]@{
            analyzedBy = "agent"; mode = $Mode; result = $resultText; gate = $gate
            failedChecks = $failed; checks = $checks; markers = $marks
            iisUp = $iisUp; acceptanceReady = $acceptanceReady; error = $probeError
        }) | ConvertTo-Json -Depth 6)
Write-Utf8NoBom (Join-Path $RunDir "summary.json") (([ordered]@{
            graphId = "urban-cutover"; graphPath = "pipelines/graphs/ops/urban-cutover"; runId = $runId
            mode = $Mode; result = $resultText; gate = $gate; failedChecks = $failed; error = $probeError
            levels = [ordered]@{
                P0 = [bool]$marks.Count
                P1 = $resultText -eq "pass"
                P2 = ($Mode -eq "check") -or ((M "IMPORT_EXIT") -eq "0")
                P3 = "user-only (5233 entry + live clients)"
            }
        }) | ConvertTo-Json -Depth 5)
$checkMd = ($checks.Keys | ForEach-Object { "| $_ | $(if ($checks[$_]) { 'pass' } else { 'FAIL' }) |" }) -join "`n"
$markMd = ($marks.Keys | ForEach-Object { "| $_ | $($marks[$_]) |" }) -join "`n"
Write-Utf8NoBom (Join-Path $RunDir "report.md") @"
# urban-cutover report — Agent analysis

- run: ``$runId`` · mode: ``$Mode`` · result: ``$resultText`` · gate: ``$gate``
- IIS ${prodPort} up: ``$iisUp`` · acceptance ${publicPort} ready: ``$acceptanceReady``

## Checks
| check | result |
|-------|--------|
$checkMd

## Markers
| key | value |
|-----|-------|
$markMd

## Next (human)
$(if ($Mode -eq "check") {
  "1. Schedule cutover window.`n2. Stop IIS.`n3. Copy production db (+wal/shm) and run ``-Mode cutover -Apply -SourceDb ...``.`n4. After pass: switch 5233 entry to 192.168.250.10:5333."
} else {
  "1. Switch 5233 entry (D2-A portproxy or D2-B UM-Proxy).`n2. Observe live clients 30–60 min.`n3. Optional: real-client log pull via admin → realtime."
})

Agent does not claim product APPROVED.
"@

Write-Host "[urban-cutover] result=$resultText gate=$gate failed=$($failed -join ',')"
if ($resultText -eq "blocked") { exit 2 }
if ($resultText -ne "pass") { exit 1 }
