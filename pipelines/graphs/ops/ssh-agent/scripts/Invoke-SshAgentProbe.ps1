#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: ops/ssh-agent probe using shared _shared/ops/ssh helpers.
.DESCRIPTION
  Does NOT invent host/user. Requires secrets.local.yaml and
  .local/.ssh/docker-linux-ed25519 (gitignored; user-supplied).
#>
[CmdletBinding()]
param(
    [string] $HostName = "",
    [string] $User = "",
    [int] $Port = 0,
    [string] $RemoteCommand = "",
    [string] $RunDir = "",
    [switch] $AllowDestructive,
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsLocal = Join-Path $GraphRoot "secrets.local.yaml"
$SharedResolve = Join-Path $RepoRoot "pipelines\_shared\ops\ssh\Resolve-SshIdentity.ps1"
$SharedInvoke = Join-Path $RepoRoot "pipelines\_shared\ops\ssh\Invoke-SshRemote.ps1"

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

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

Write-Host "[ssh-agent] starting probe..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $SharedResolve)) { throw "Missing shared resolve: $SharedResolve" }
if (-not (Test-Path -LiteralPath $SharedInvoke)) { throw "Missing shared invoke: $SharedInvoke" }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$defaultPortText = Get-YamlScalar -Text $configText -Key "defaultPort" -Indent 2
$probeFromConfig = Get-YamlScalar -Text $configText -Key "probeCommand" -Indent 2
$timeoutText = Get-YamlScalar -Text $configText -Key "connectTimeoutSeconds" -Indent 2
$identityName = Get-YamlScalar -Text $configText -Key "identityFileName" -Indent 2
if ([string]::IsNullOrWhiteSpace($identityName)) { $identityName = "docker-linux-ed25519" }

$hostVal = $HostName
$userVal = $User
$portVal = $Port
$cmdVal = $RemoteCommand
$allowDest = [bool]$AllowDestructive
$timeoutSec = 15

if (Test-Path -LiteralPath $SecretsLocal) {
    $secretsText = [System.IO.File]::ReadAllText($SecretsLocal, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($hostVal)) { $hostVal = Get-YamlScalar -Text $secretsText -Key "host" -Indent 0 }
    if ([string]::IsNullOrWhiteSpace($userVal)) { $userVal = Get-YamlScalar -Text $secretsText -Key "user" -Indent 0 }
    if ($portVal -le 0) {
        $p = Get-YamlScalar -Text $secretsText -Key "port" -Indent 0
        if ($p) { [void][int]::TryParse($p, [ref]$portVal) }
    }
    if ([string]::IsNullOrWhiteSpace($cmdVal)) {
        $cmdVal = Get-YamlScalar -Text $secretsText -Key "probeCommand" -Indent 0
    }
    $ad = Get-YamlScalar -Text $secretsText -Key "allowDestructive" -Indent 0
    if ($ad -and $ad -match '^(true|yes|1)$') { $allowDest = $true }
    $t = Get-YamlScalar -Text $secretsText -Key "connectTimeoutSeconds" -Indent 0
    if ($t) { [void][int]::TryParse($t, [ref]$timeoutSec) }
}

if ($portVal -le 0 -and $defaultPortText) { [void][int]::TryParse($defaultPortText, [ref]$portVal) }
if ($portVal -le 0) { $portVal = 22 }
if ($timeoutText) { [void][int]::TryParse($timeoutText, [ref]$timeoutSec) }
if ([string]::IsNullOrWhiteSpace($cmdVal)) { $cmdVal = $probeFromConfig }
if ([string]::IsNullOrWhiteSpace($cmdVal)) { $cmdVal = "uname -a && whoami && pwd" }

if ([string]::IsNullOrWhiteSpace($hostVal) -or [string]::IsNullOrWhiteSpace($userVal)) {
    throw @"
Missing SSH target. Set secrets.local.yaml host/user (copy from secrets.example.yaml),
or pass -HostName / -User. Do not invent hosts.
"@
}

if (-not $SkipConfirm) {
    Write-Host "[ssh-agent] target=${userVal}@${hostVal}:$portVal"
    Write-Host "[ssh-agent] command=$cmdVal"
    $ans = Read-Host "Continue SSH probe? [y/N]"
    if ($ans -notmatch '^(y|yes)$') {
        throw "Aborted by user."
    }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path $GraphRoot "runs\$stamp"
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$prepareDir = Join-Path $RunDir "prepare"
$sshDir = Join-Path $RunDir "ssh"
New-Item -ItemType Directory -Force -Path $prepareDir, $sshDir | Out-Null

Write-Host "[ssh-agent] runDir=$RunDir"

$identityInfo = & $SharedResolve -RepoRoot $RepoRoot -IdentityFileName $identityName -HardenAcl -PassThru
$identityJson = ($identityInfo | ConvertTo-Json -Depth 5)
Write-Utf8NoBom -Path (Join-Path $prepareDir "identity.json") -Content $identityJson

$invokeArgs = @{
    HostName               = $hostVal
    User                   = $userVal
    Port                   = $portVal
    RemoteCommand          = $cmdVal
    RepoRoot               = $RepoRoot
    IdentityFileName       = $identityName
    EvidenceDir            = $sshDir
    ConnectTimeoutSeconds  = $timeoutSec
}
if ($allowDest) { $invokeArgs.AllowDestructive = $true }

$result = $null
$probeError = $null
try {
    $result = & $SharedInvoke @invokeArgs
}
catch {
    $probeError = $_.Exception.Message
}

$exitCode = 1
$stdoutLen = 0
$stderrLen = 0
$durationMs = 0
if ($result) {
    $exitCode = [int]$result.exitCode
    $stdoutLen = ([string]$result.stdout).Length
    $stderrLen = ([string]$result.stderr).Length
    $durationMs = [int]$result.durationMs
}

$l0 = (Test-Path -LiteralPath ([string]$identityInfo.identityFile)) -and [bool](Get-Command ssh -ErrorAction SilentlyContinue)
$l1 = ($null -eq $probeError) -or ($exitCode -eq 0) -or ($stdoutLen -gt 0) -or ($stderrLen -gt 0)
# L1 = command reached ssh layer; treat presence of meta as handshake attempt completed
$metaPath = Join-Path $sshDir "meta.json"
if (Test-Path -LiteralPath $metaPath) { $l1 = $true }
$l2 = ($exitCode -eq 0) -and ($stdoutLen -gt 0)

$summary = [ordered]@{
    graphId     = "ssh-agent"
    graphPath   = "pipelines/graphs/ops/ssh-agent"
    runId       = Split-Path -Leaf $RunDir
    result      = $(if ($l2) { "pass" } elseif ($l0) { "fail" } else { "blocked" })
    host        = $hostVal
    user        = $userVal
    port        = $portVal
    command     = $cmdVal
    exitCode    = $exitCode
    durationMs  = $durationMs
    stdoutBytes = $stdoutLen
    stderrBytes = $stderrLen
    levels      = [ordered]@{
        L0 = $l0
        L1 = $l1
        L2 = $l2
        L3 = "pending-user"
    }
    error       = $probeError
    message     = "等待用户验收，尚未通过。"
}
Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 6)

$report = @"
# ssh-agent report

- run: ``$($summary.runId)``
- target: ``$($userVal)@$($hostVal):$portVal``
- command: ``$cmdVal``
- exitCode: $exitCode
- durationMs: $durationMs
- L0 identity+ssh: $l0
- L1 handshake/evidence: $l1
- L2 probe ok: $l2
- L3: pending（仅用户）

证据：``ssh/`` ``prepare/identity.json``

等待用户验收，尚未通过。
请验收：pass / fail + 对象与原因。
"@
Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content $report

$accept = @"
# Acceptance — ssh-agent (run $($summary.runId))

Status: **pending**

| 项 | 值 |
|----|----|
| run | $($summary.runId) |
| P0 / L0 | $(if ($l0) { "pass" } else { "fail" }) |
| P1 / L1 | $(if ($l1) { "pass" } else { "fail" }) |
| P2 / L2 | $(if ($l2) { "pass" } else { "fail" }) |
| P3 / L3 | pending（仅用户） |
| 对象 | ${userVal}@${hostVal} |
| 原因 | |
"@
Write-Utf8NoBom -Path (Join-Path $RunDir "acceptance.md") -Content $accept

if ($probeError) {
    Write-Host "[ssh-agent] FAILED: $probeError" -ForegroundColor Red
    exit 1
}
if (-not $l2) {
    Write-Host "[ssh-agent] probe did not meet L2 (exitCode=$exitCode stdoutBytes=$stdoutLen)" -ForegroundColor Red
    exit 1
}

Write-Host "[ssh-agent] cook finished; awaiting user acceptance (P3)."
exit 0
