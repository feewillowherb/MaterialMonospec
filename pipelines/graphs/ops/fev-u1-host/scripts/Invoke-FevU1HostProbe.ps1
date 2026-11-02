#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: FEV U1 host OS/virt probe via pipelines/_shared/ops SSH.
#>
[CmdletBinding()]
param(
    [string] $HostName = "",
    [string] $User = "",
    [int] $Port = 0,
    [string] $RemoteCommand = "",
    [string] $RunDir = "",
    [string] $IdentityPassphrase = "",
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

Write-Host "[fev-u1-host] starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
foreach ($p in @($SharedResolve, $SharedUnlock, $SharedInvoke)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Missing shared script: $p" }
}

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$defaultPortText = Get-YamlScalar -Text $configText -Key "defaultPort" -Indent 2
$probeScriptRel = Get-YamlScalar -Text $configText -Key "probeScriptRel" -Indent 2
$timeoutText = Get-YamlScalar -Text $configText -Key "connectTimeoutSeconds" -Indent 2
$identityName = Get-YamlScalar -Text $configText -Key "identityFileName" -Indent 2
if ([string]::IsNullOrWhiteSpace($identityName)) { $identityName = "docker-linux-ed25519" }
if ([string]::IsNullOrWhiteSpace($probeScriptRel)) { $probeScriptRel = "scripts/remote-u1-probe.sh" }

$hostVal = $HostName
$userVal = $User
$portVal = $Port
$cmdVal = $RemoteCommand
$passVal = $IdentityPassphrase
$timeoutSec = 20

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
    if ([string]::IsNullOrWhiteSpace($passVal)) {
        $passVal = Get-YamlScalar -Text $secretsText -Key "identityPassphrase" -Indent 0
    }
    $t = Get-YamlScalar -Text $secretsText -Key "connectTimeoutSeconds" -Indent 0
    if ($t) { [void][int]::TryParse($t, [ref]$timeoutSec) }
}

if ($portVal -le 0 -and $defaultPortText) { [void][int]::TryParse($defaultPortText, [ref]$portVal) }
if ($portVal -le 0) { $portVal = 2222 }
if ($timeoutText) { [void][int]::TryParse($timeoutText, [ref]$timeoutSec) }

if ([string]::IsNullOrWhiteSpace($cmdVal)) {
    $probeScriptPath = Join-Path $GraphRoot ($probeScriptRel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $probeScriptPath)) {
        throw "Missing probe script: $probeScriptPath"
    }
    $scriptBody = [System.IO.File]::ReadAllText($probeScriptPath, [System.Text.Encoding]::UTF8)
    # Normalize to LF and run via bash -s (stdin)
    $scriptBody = $scriptBody -replace "`r`n", "`n" -replace "`r", "`n"
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($scriptBody))
    $cmdVal = "echo $b64 | base64 -d | bash -s"
}

if ([string]::IsNullOrWhiteSpace($hostVal) -or [string]::IsNullOrWhiteSpace($userVal)) {
    throw "Missing SSH target. Set secrets.local.yaml host/user."
}

if (-not $SkipConfirm) {
    Write-Host "[fev-u1-host] target=${userVal}@${hostVal}:$portVal (FEV U1)"
    $ans = Read-Host "Continue U1 probe? [y/N]"
    if ($ans -notmatch '^(y|yes)$') { throw "Aborted by user." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path $GraphRoot "runs\$stamp"
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$prepareDir = Join-Path $RunDir "prepare"
$sshDir = Join-Path $RunDir "ssh"
New-Item -ItemType Directory -Force -Path $prepareDir, $sshDir | Out-Null
Write-Host "[fev-u1-host] runDir=$RunDir"

$batchPath = $null
$identityForSsh = $identityName
try {
    if (-not [string]::IsNullOrWhiteSpace($passVal)) {
        $unlocked = & $SharedUnlock -Passphrase $passVal -RepoRoot $RepoRoot `
            -IdentityFileName $identityName -PassThru
        $identityForSsh = [string]$unlocked.identityFileName
        $batchPath = [string]$unlocked.identityFile
        Write-Utf8NoBom -Path (Join-Path $prepareDir "identity.json") -Content (@{
                mode           = "unlocked-batch"
                identityFile   = $identityForSsh
                sourceIdentity = $identityName
            } | ConvertTo-Json)
    }
    else {
        $identityInfo = & $SharedResolve -RepoRoot $RepoRoot -IdentityFileName $identityName -HardenAcl -PassThru
        Write-Utf8NoBom -Path (Join-Path $prepareDir "identity.json") -Content ($identityInfo | ConvertTo-Json -Depth 5)
    }

    $probeError = $null
    $result = $null
    try {
        # Trusted checked-in probe script may contain redirects / tokens that trip heuristic checks.
        $result = & $SharedInvoke -HostName $hostVal -User $userVal -Port $portVal `
            -RemoteCommand $cmdVal -RepoRoot $RepoRoot -IdentityFileName $identityForSsh `
            -EvidenceDir $sshDir -ConnectTimeoutSeconds $timeoutSec -SkipDestructiveCheck
    }
    catch {
        $probeError = $_.Exception.Message
    }

    $stdout = ""
    $exitCode = 1
    $durationMs = 0
    if ($result) {
        $stdout = [string]$result.stdout
        $exitCode = [int]$result.exitCode
        $durationMs = [int]$result.durationMs
    }
    elseif (Test-Path (Join-Path $sshDir "stdout.txt")) {
        $stdout = [System.IO.File]::ReadAllText((Join-Path $sshDir "stdout.txt"))
    }
    if (Test-Path (Join-Path $sshDir "meta.json")) {
        $meta = Get-Content (Join-Path $sshDir "meta.json") -Raw | ConvertFrom-Json
        $exitCode = [int]$meta.exitCode
        $durationMs = [int]$meta.durationMs
    }

    $hasOs = ($stdout -match '=== os-release ===') -and (
        ($stdout -match '(?m)^ID=') -or ($stdout -match '(?m)^NAME=') -or ($stdout -match '=== uname ===')
    )
    $hasVirt = ($stdout -match '=== virt ===')
    $wslInterop = $stdout -match 'WSLInterop:present'
    $mntC = $stdout -match 'mnt-c-Windows:present'
    $virtLine = $null
    if ($stdout -match '(?ms)=== virt ===\s*(.+?)(?:===|$)') {
        $virtLine = ($Matches[1].Trim() -split '\r?\n')[0]
    }
    $prettyName = $null
    if ($stdout -match '(?m)^PRETTY_NAME=(.+)$') {
        $prettyName = $Matches[1].Trim().Trim('"')
    }

    $chassisVm = $stdout -match '(?i)Chassis:\s*vm'
    $hypervisorMicrosoft = ($virtLine -match '(?i)^microsoft\s*$') -or ($stdout -match '(?i)Hypervisor vendor:\s*Microsoft') -or ($stdout -match '(?i)Virtualization:\s*microsoft')
    $looksWsl = $wslInterop -or $mntC

    # Agent analysis (humans do not interpret OS/virt for this Graph)
    $verdict = "INCONCLUSIVE"
    $d1Path = "unknown"
    $rationale = @()
    if (-not $hasOs -or -not $hasVirt -or $exitCode -ne 0) {
        $verdict = "INCONCLUSIVE"
        $d1Path = "unknown"
        $rationale += "OS/virt evidence incomplete or SSH probe failed; cannot map D1."
    }
    elseif ($looksWsl) {
        $verdict = "FEASIBLE"
        $d1Path = "D1-A-wsl2"
        $rationale += "WSL traces present (WSLInterop and/or /mnt/c/Windows). Blueprint path: WSL2 + Docker Engine."
        $rationale += "Guest OS: $prettyName"
    }
    elseif ($hypervisorMicrosoft -or $chassisVm) {
        $verdict = "FEASIBLE"
        $d1Path = "D1-B-hyperv-linux-vm"
        $rationale += "Linux guest reports Hyper-V/microsoft virtualization (virt=$virtLine; chassis-vm=$chassisVm); WSL traces absent."
        $rationale += "Blueprint path: Hyper-V Linux VM + Docker Engine (not WSL2)."
        $rationale += "Guest OS: $prettyName"
        $rationale += "Residual unknown: Windows host Server SKU (2022/2025 vs 2019) not visible over this SSH channel; path already converges to D1-B so U1 remains FEASIBLE."
    }
    elseif ($virtLine -match '(?i)^(none|)$') {
        $verdict = "INCONCLUSIVE"
        $d1Path = "unknown"
        $rationale += "Virt reported as none/empty; need Windows-host or richer virt evidence before D1 choice."
    }
    else {
        $verdict = "FEASIBLE"
        $d1Path = "D1-other-virt:$virtLine"
        $rationale += "Virtualized Linux guest detected (virt=$virtLine) with usable OS ($prettyName); treat as Linux VM path for Docker Engine, confirm against blueprint D1 options."
    }

    $parse = [ordered]@{
        fevId              = "U1"
        analyzedBy         = "agent"
        prettyName         = $prettyName
        virtDetect         = $virtLine
        wslInterop         = $wslInterop
        mntCWindows        = $mntC
        chassisVm          = $chassisVm
        hypervisorMicrosoft = $hypervisorMicrosoft
        windowsHostSkuSeen = $false
        d1Path             = $d1Path
        verdict            = $verdict
        rationale          = $rationale
    }
    Write-Utf8NoBom -Path (Join-Path $prepareDir "u1-parse.json") -Content ($parse | ConvertTo-Json -Depth 6)

    $l0 = [bool](Get-Command ssh -ErrorAction SilentlyContinue)
    $l1 = ($exitCode -eq 0) -or (Test-Path (Join-Path $sshDir "meta.json"))
    $l2 = ($exitCode -eq 0) -and $hasOs -and $hasVirt -and ($verdict -in @("FEASIBLE", "INFEASIBLE", "INCONCLUSIVE"))

    $summary = [ordered]@{
        graphId    = "fev-u1-host"
        graphPath  = "pipelines/graphs/ops/fev-u1-host"
        runId      = Split-Path -Leaf $RunDir
        result     = $(if ($l2) { "pass" } elseif ($l0) { "fail" } else { "blocked" })
        fevId      = "U1"
        host       = $hostVal
        user       = $userVal
        port       = $portVal
        exitCode   = $exitCode
        durationMs = $durationMs
        levels     = [ordered]@{ L0 = $l0; L1 = $l1; L2 = $l2; L3 = "optional-ack" }
        verdict    = $verdict
        d1Path     = $d1Path
        parse      = $parse
        error      = $probeError
        message    = "Agent completed U1 analysis. Verdict=$verdict d1Path=$d1Path"
    }
    Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 8)

    $rationaleMd = ($rationale | ForEach-Object { "- $_" }) -join "`n"
    $report = @"
# fev-u1-host report (FEV U1) — Agent analysis

- run: ``$($summary.runId)``
- target: ``${userVal}@${hostVal}:$portVal``
- exitCode: $exitCode
- **Verdict (Agent): ``$verdict``**
- **D1 path (Agent): ``$d1Path``**
- prettyName: $prettyName
- virt: $virtLine
- WSLInterop: $wslInterop
- mnt/c/Windows: $mntC
- L0/L1/L2: $l0 / $l1 / $l2

## Rationale (Agent)

$rationaleMd

证据：``ssh/`` ``prepare/u1-parse.json``

人无需再做 OS/virt 分析。产品落地仍须 Human ``APPROVED`` + OpenSpec（FEV ≠ 交付）。
"@
    Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content $report

    Write-Utf8NoBom -Path (Join-Path $RunDir "acceptance.md") -Content @"
# Acceptance — fev-u1-host (run $($summary.runId))

Status: **agent-analyzed**

| 项 | 值 |
|----|----|
| run | $($summary.runId) |
| P0 / L0 | $(if ($l0) { "pass" } else { "fail" }) |
| P1 / L1 | $(if ($l1) { "pass" } else { "fail" }) |
| P2 / L2 | $(if ($l2) { "pass" } else { "fail" }) |
| FEV U1 Verdict (Agent) | $verdict |
| D1 path (Agent) | $d1Path |
| 可选采纳 | pending |
"@

    if ($probeError) {
        Write-Host "[fev-u1-host] FAILED: $probeError" -ForegroundColor Red
        exit 1
    }
    if (-not $l2) {
        Write-Host "[fev-u1-host] L2 not met (exitCode=$exitCode)" -ForegroundColor Red
        exit 1
    }
    Write-Host "[fev-u1-host] Agent Verdict=$verdict d1Path=$d1Path"
    exit 0
}
finally {
    if ($batchPath -and (Test-Path -LiteralPath $batchPath)) {
        & icacls.exe $batchPath /grant:r "${env:USERNAME}:(F)" | Out-Null
        Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
        Write-Host "[fev-u1-host] removed temp batch identity"
    }
}
