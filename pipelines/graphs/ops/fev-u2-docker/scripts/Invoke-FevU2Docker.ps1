#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: FEV U2 — install Docker Engine on the target VM (aliyun docker-ce mirror, non-overlapping
  bridge network) and verify Linux containers + MSSQL 2022 container via pipelines/_shared/ops SSH.
.DESCRIPTION
  Modes:
    preflight  read-only (sudo / docker / mirrors / routes)
    verify     docker + hello-world + MSSQL probe container (creates and removes a probe container)
    install    preflight + install Docker (mutating; requires -Apply)
    all        preflight + install + verify (mutating; requires -Apply)
  Remote sudo MUST be passwordless; the sudo password is never sent over this channel because
  Invoke-SshRemote records the full remote command in console and ssh/meta.json.
#>
[CmdletBinding()]
param(
    [ValidateSet("preflight", "verify", "install", "all")]
    [string] $Mode = "all",
    [switch] $Apply,
    [string] $RunDir = "",
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsLocal = Join-Path $GraphRoot "secrets.local.yaml"
$SharedResolve = Join-Path $RepoRoot "pipelines\_shared\ops\ssh\Resolve-SshIdentity.ps1"
$SharedUnlock = Join-Path $RepoRoot "pipelines\_shared\ops\ssh\Unlock-SshIdentity.ps1"
$SharedInvoke = Join-Path $RepoRoot "pipelines\_shared\ops\ssh\Invoke-SshRemote.ps1"

function Get-YamlScalar {
    param([string] $Text, [string] $Key, [int] $Indent = 0)
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

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-OrDefault {
    param([string] $Value, [string] $Default)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $Default }
    return $Value
}

Write-Host "[fev-u2-docker] starting mode=$Mode"

$mutating = $Mode -in @("install", "all")
if ($mutating -and -not $Apply) {
    throw "Mode '$Mode' installs software on the remote host. Re-run with -Apply after an explicit human gate."
}

foreach ($p in @($ConfigPath, $SharedResolve, $SharedUnlock, $SharedInvoke)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Missing file: $p" }
}
if (-not (Test-Path -LiteralPath $SecretsLocal)) {
    throw "Missing secrets.local.yaml (copy secrets.example.yaml)."
}

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$secretsText = [System.IO.File]::ReadAllText($SecretsLocal, [System.Text.Encoding]::UTF8)

$identityName = Get-OrDefault (Get-YamlScalar $configText "identityFileName" 2) "docker-linux-ed25519"
$remoteScriptRel = Get-OrDefault (Get-YamlScalar $configText "remoteScriptRel" 2) "scripts/remote-u2-docker.sh"
$bip = Get-OrDefault (Get-YamlScalar $configText "bip" 2) "10.233.0.1/24"
$poolBase = Get-OrDefault (Get-YamlScalar $configText "poolBase" 2) "10.234.0.0/16"
$poolSize = Get-OrDefault (Get-YamlScalar $configText "poolSize" 2) "24"
$mirror = Get-OrDefault (Get-YamlScalar $configText "registryMirror" 2) ""
$mssqlMem = Get-OrDefault (Get-YamlScalar $configText "mssqlMemoryLimitMb" 2) "1536"
$keepMssql = Get-OrDefault (Get-YamlScalar $configText "keepMssqlProbe" 2) "false"

$hostVal = Get-YamlScalar $secretsText "host" 0
$userVal = Get-YamlScalar $secretsText "user" 0
$portVal = 0
[void][int]::TryParse((Get-OrDefault (Get-YamlScalar $secretsText "port" 0) (Get-OrDefault (Get-YamlScalar $configText "defaultPort" 2) "2222")), [ref]$portVal)
$passVal = Get-YamlScalar $secretsText "identityPassphrase" 0
$timeoutSec = 20
if ([string]::IsNullOrWhiteSpace($hostVal) -or [string]::IsNullOrWhiteSpace($userVal)) {
    throw "Missing SSH target. Set secrets.local.yaml host/user."
}

if (-not $SkipConfirm) {
    Write-Host "[fev-u2-docker] target=${userVal}@${hostVal}:$portVal mode=$Mode apply=$Apply"
    $ans = Read-Host "Continue? [y/N]"
    if ($ans -notmatch '^(y|yes)$') { throw "Aborted by user." }
}

$scriptPath = Join-Path $GraphRoot ($remoteScriptRel -replace '/', '\')
$scriptBody = [System.IO.File]::ReadAllText($scriptPath, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n" -replace "`r", "`n"
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($scriptBody))
$mirrorArg = if ([string]::IsNullOrWhiteSpace($mirror)) { "''" } else { $mirror }
$remoteCommand = "echo $b64 | base64 -d | bash -s -- $Mode $bip $poolBase $poolSize $mirrorArg $mssqlMem $keepMssql"

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $RunDir = Join-Path $GraphRoot ("runs\" + (Get-Date -Format "yyyy-MM-ddTHHmmss"))
}
if (Test-Path -LiteralPath $RunDir) { throw "Run dir already exists (runs/ are append-only): $RunDir" }
$prepareDir = Join-Path $RunDir "prepare"
$sshDir = Join-Path $RunDir "ssh"
New-Item -ItemType Directory -Force -Path $prepareDir, $sshDir | Out-Null
Write-Host "[fev-u2-docker] runDir=$RunDir"

$batchPath = $null
$identityForSsh = $identityName
try {
    if (-not [string]::IsNullOrWhiteSpace($passVal)) {
        $unlocked = & $SharedUnlock -Passphrase $passVal -RepoRoot $RepoRoot -IdentityFileName $identityName -PassThru
        $identityForSsh = [string]$unlocked.identityFileName
        $batchPath = [string]$unlocked.identityFile
    }
    else {
        [void](& $SharedResolve -RepoRoot $RepoRoot -IdentityFileName $identityName -HardenAcl -PassThru)
    }
    Write-Utf8NoBom -Path (Join-Path $prepareDir "identity.json") -Content (@{
            mode = $(if ($batchPath) { "unlocked-batch" } else { "direct" }); identityFile = $identityForSsh; sourceIdentity = $identityName
        } | ConvertTo-Json)

    $probeError = $null
    $result = $null
    try {
        $result = & $SharedInvoke -HostName $hostVal -User $userVal -Port $portVal `
            -RemoteCommand $remoteCommand -RepoRoot $RepoRoot -IdentityFileName $identityForSsh `
            -EvidenceDir $sshDir -ConnectTimeoutSeconds $timeoutSec -SkipDestructiveCheck
    }
    catch { $probeError = $_.Exception.Message }

    $stdout = ""
    if ($result) { $stdout = [string]$result.stdout }
    elseif (Test-Path (Join-Path $sshDir "stdout.txt")) { $stdout = [System.IO.File]::ReadAllText((Join-Path $sshDir "stdout.txt")) }
    $exitCode = 1
    if (Test-Path (Join-Path $sshDir "meta.json")) {
        $exitCode = [int]((Get-Content (Join-Path $sshDir "meta.json") -Raw | ConvertFrom-Json).exitCode)
    }

    $marks = [ordered]@{}
    foreach ($line in ($stdout -split "\r?\n")) {
        if ($line -match '^@@ ([A-Z0-9_]+)=(.*)$') { $marks[$Matches[1]] = $Matches[2].Trim() }
    }
    function M([string] $k) { if ($marks.Contains($k)) { return [string]$marks[$k] } return "" }

    $sudoOk = (M "SUDO_NOPASSWD") -eq "yes"
    $dockerOk = (M "DOCKER_OK") -eq "yes"
    $mssqlOk = (M "MSSQL_OK") -eq "yes"
    $helloOk = (M "HELLO_OK") -eq "yes"
    $overlap = (M "BRIDGE_OVERLAP") -eq "yes"
    $verifyRan = $marks.Contains("DOCKER_OK")

    $verdict = "INCONCLUSIVE"
    $result = "fail"
    $gate = $null
    $rationale = @()
    if ($exitCode -ne 0 -or $probeError) {
        $result = "blocked"
        $rationale += "SSH execution failed (exitCode=$exitCode): $probeError"
    }
    elseif (-not $sudoOk) {
        $verdict = "BLOCKED"
        $result = "blocked"
        $gate = "sudo-nopasswd-required"
        $rationale += "Remote user '$userVal' needs a password for sudo. The sudo password is not sent over this channel (remote command is logged)."
        $rationale += "Human gate: on the VM run once: echo '$userVal ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/90-$userVal-ops && sudo chmod 0440 /etc/sudoers.d/90-$userVal-ops && sudo visudo -c"
    }
    elseif ($Mode -in @("preflight", "install")) {
        $verdict = "INCONCLUSIVE"
        $result = $(if ((M "INSTALL") -in @("", "ok")) { "pass" } else { "fail" })
        $rationale += "Mode '$Mode' does not run the container verification; U2 Verdict requires verify or all."
        if ((M "INSTALL")) { $rationale += "INSTALL=$(M 'INSTALL')" }
    }
    elseif (-not $verifyRan) {
        $rationale += "Install step did not complete (INSTALL=$(M 'INSTALL')); verification skipped."
    }
    elseif ($dockerOk -and $mssqlOk -and -not $overlap) {
        $verdict = "FEASIBLE"
        $result = "pass"
        $rationale += "Docker Engine $(M 'DOCKER_SERVER') active/enabled; compose $(M 'COMPOSE'); docker0=$(M 'DOCKER0'); no 172.17.0.0/16 overlap with eth0 $(M 'ETH0')."
        $rationale += "MSSQL container ready in $(M 'MSSQL_READY_SECONDS')s; $(M 'MSSQL_VERSION'); collation $(M 'MSSQL_COLLATION'); memory $(M 'MSSQL_MEM_USAGE') with MSSQL_MEMORY_LIMIT_MB=$mssqlMem (D7 mitigation)."
        if (-not $helloOk) { $rationale += "hello-world (Docker Hub via mirror '$mirror') failed: Docker Hub images need mirror fix or docker save/load (K16). Not blocking U2 because MSSQL comes from mcr." }
    }
    else {
        $verdict = $(if ($dockerOk -and -not $mssqlOk) { "INCONCLUSIVE" } else { "INFEASIBLE" })
        $rationale += "DOCKER_OK=$(M 'DOCKER_OK') MSSQL_OK=$(M 'MSSQL_OK') BRIDGE_OVERLAP=$(M 'BRIDGE_OVERLAP') MSSQL_PULL=$(M 'MSSQL_PULL')."
    }

    $parse = [ordered]@{
        fevId = "U2"; analyzedBy = "agent"; mode = $Mode; verdict = $verdict; gate = $gate
        markers = $marks; rationale = $rationale
    }
    Write-Utf8NoBom -Path (Join-Path $prepareDir "u2-parse.json") -Content ($parse | ConvertTo-Json -Depth 6)

    $p0 = [bool](Get-Command ssh -ErrorAction SilentlyContinue)
    $p1 = $exitCode -eq 0
    $p2 = $p1 -and $verdict -in @("FEASIBLE", "INFEASIBLE")
    $summary = [ordered]@{
        graphId = "fev-u2-docker"; graphPath = "pipelines/graphs/ops/fev-u2-docker"
        runId = Split-Path -Leaf $RunDir; result = $result; fevId = "U2"; mode = $Mode
        host = $hostVal; user = $userVal; port = $portVal; exitCode = $exitCode
        levels = [ordered]@{ P0 = $p0; P1 = $p1; P2 = $p2; P3 = "user-only" }
        verdict = $verdict; gate = $gate; error = $probeError
    }
    Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 6)

    $markMd = ($marks.Keys | ForEach-Object { "| $_ | $($marks[$_]) |" }) -join "`n"
    $ratMd = ($rationale | ForEach-Object { "- $_" }) -join "`n"
    Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content @"
# fev-u2-docker report (FEV U2) — Agent analysis

- run: ``$($summary.runId)`` · mode: ``$Mode`` · result: ``$result``
- target: ``${userVal}@${hostVal}:$portVal``
- **Verdict (Agent): ``$verdict``**$(if ($gate) { " · gate: ``$gate``" })
- P0/P1/P2: $p0 / $p1 / $p2

## Rationale (Agent)

$ratMd

## Markers

| key | value |
|-----|-------|
$markMd

证据：``ssh/`` ``prepare/u2-parse.json``。FEV Verdict 只回答宿主可行性，不是产品 APPROVED / OpenSpec。
"@
    Write-Utf8NoBom -Path (Join-Path $RunDir "acceptance.md") -Content @"
# Acceptance — fev-u2-docker (run $($summary.runId))

| 项 | 值 |
|----|----|
| P0 | $(if ($p0) { "pass" } else { "fail" }) |
| P1 | $(if ($p1) { "pass" } else { "fail" }) |
| P2 | $(if ($p2) { "pass" } else { "fail" }) |
| FEV U2 Verdict (Agent) | $verdict |
| P3（用户采纳） | pending |
"@

    Write-Host "[fev-u2-docker] result=$result verdict=$verdict$(if ($gate) { " gate=$gate" })"
    if ($result -eq "pass") { exit 0 } else { exit 1 }
}
finally {
    if ($batchPath -and (Test-Path -LiteralPath $batchPath)) {
        & icacls.exe $batchPath /grant:r "${env:USERNAME}:(F)" | Out-Null
        Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
        Write-Host "[fev-u2-docker] removed temp batch identity"
    }
}
