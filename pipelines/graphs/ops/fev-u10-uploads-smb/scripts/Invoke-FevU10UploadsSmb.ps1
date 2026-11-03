#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: FEV U10 — can the Docker VM use the IIS host's Uploads directory over SMB.
.DESCRIPTION
  Modes:
    reach       read-only: VM -> host TCP 445 on the Default Switch gateway and the stable host address,
                with a control port to detect "everything accepts" middleboxes; cifs client readiness.
    setup       mutating (requires -Apply): passwordless sudo drop-in, cifs-utils, root-only SMB credentials file.
                Passwords come from env UM_VM_SUDO_PASSWORD / UM_SMB_PASSWORD and are sent only on SSH stdin.
    mount-test  read-only mount + read a historical file + stat latency; with -ProductionWrite also
                write/read back/delete one file under Uploads/_probe/ (human gate production-write-approval).
#>
[CmdletBinding()]
param(
    [ValidateSet("reach", "setup", "mount-test")]
    [string] $Mode = "reach",
    [switch] $Apply,
    [switch] $ProductionWrite,
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

function Get-RemoteScriptBase64 {
    param([string] $RelativePath)
    $path = Join-Path $GraphRoot ($RelativePath -replace '/', '\')
    $body = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n" -replace "`r", "`n"
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($body))
}

Write-Host "[fev-u10-uploads-smb] starting mode=$Mode"

if ($Mode -eq "setup" -and -not $Apply) {
    throw "Mode 'setup' changes the VM (sudoers drop-in, package, credentials file). Re-run with -Apply after an explicit human gate."
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
$stableHost = Get-OrDefault (Get-YamlScalar $configText "stableHostAddress" 2) "191.12.234.212"
$controlPort = Get-OrDefault (Get-YamlScalar $configText "controlPort" 2) "47123"
$probeTimeout = Get-OrDefault (Get-YamlScalar $configText "probeTimeoutSeconds" 2) "3"
$shareName = Get-OrDefault (Get-YamlScalar $configText "shareName" 2) "um-uploads"
$smbUser = Get-OrDefault (Get-YamlScalar $configText "smbUser" 2) "um-uploads"
$smbDomain = Get-OrDefault (Get-YamlScalar $configText "smbDomain" 2) "WORKGROUP"
$credPath = Get-OrDefault (Get-YamlScalar $configText "credentialsPath" 2) "/etc/um-uploads.cred"
$mountPoint = Get-OrDefault (Get-YamlScalar $configText "probeMountPoint" 2) "/mnt/um-uploads-probe"
$unc = "//$stableHost/$shareName"

$hostVal = Get-YamlScalar $secretsText "host" 0
$userVal = Get-YamlScalar $secretsText "user" 0
$portVal = 0
[void][int]::TryParse((Get-OrDefault (Get-YamlScalar $secretsText "port" 0) (Get-OrDefault (Get-YamlScalar $configText "defaultPort" 2) "2222")), [ref]$portVal)
$passVal = Get-YamlScalar $secretsText "identityPassphrase" 0
if ([string]::IsNullOrWhiteSpace($hostVal) -or [string]::IsNullOrWhiteSpace($userVal)) {
    throw "Missing SSH target. Set secrets.local.yaml host/user."
}

$stdinText = ""
switch ($Mode) {
    "reach" {
        $b64 = Get-RemoteScriptBase64 (Get-OrDefault (Get-YamlScalar $configText "remoteReachScriptRel" 2) "scripts/remote-u10-reach.sh")
        $remoteCommand = "echo $b64 | base64 -d | bash -s -- $stableHost $controlPort $probeTimeout"
    }
    "setup" {
        $sudoPw = [string]$env:UM_VM_SUDO_PASSWORD
        $smbPw = [string]$env:UM_SMB_PASSWORD
        if ($sudoPw -match "[`r`n]" -or $smbPw -match "[`r`n]") { throw "Passwords must be single-line." }
        $stdinText = "$sudoPw`n$smbPw`n"
        $b64 = Get-RemoteScriptBase64 (Get-OrDefault (Get-YamlScalar $configText "remoteSetupScriptRel" 2) "scripts/remote-u10-setup.sh")
        $remoteCommand = "bash <(echo $b64 | base64 -d) $smbUser $smbDomain $credPath"
    }
    "mount-test" {
        $write = $(if ($ProductionWrite) { "yes" } else { "no" })
        $b64 = Get-RemoteScriptBase64 (Get-OrDefault (Get-YamlScalar $configText "remoteMountScriptRel" 2) "scripts/remote-u10-mount.sh")
        $remoteCommand = "bash <(echo $b64 | base64 -d) $unc $credPath $mountPoint $write"
    }
}

if (-not $SkipConfirm) {
    Write-Host "[fev-u10-uploads-smb] target=${userVal}@${hostVal}:$portVal mode=$Mode apply=$Apply productionWrite=$ProductionWrite"
    $ans = Read-Host "Continue? [y/N]"
    if ($ans -notmatch '^(y|yes)$') { throw "Aborted by user." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $RunDir = Join-Path $GraphRoot ("runs\" + (Get-Date -Format "yyyy-MM-ddTHHmmss"))
}
if (Test-Path -LiteralPath $RunDir) { throw "Run dir already exists (runs/ are append-only): $RunDir" }
$prepareDir = Join-Path $RunDir "prepare"
$sshDir = Join-Path $RunDir "ssh"
New-Item -ItemType Directory -Force -Path $prepareDir, $sshDir | Out-Null
Write-Host "[fev-u10-uploads-smb] runDir=$RunDir"

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
            -EvidenceDir $sshDir -ConnectTimeoutSeconds 20 -SkipDestructiveCheck -StdinText $stdinText
    }
    catch { $probeError = $_.Exception.Message }
    finally { $stdinText = $null }

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

    $verdict = "INCONCLUSIVE"
    $resultText = "fail"
    $gate = $null
    $recommendedHost = $null
    $rationale = @()
    $sshFailed = ($exitCode -ne 0 -and -not $marks.Count) -or ($probeError -and -not $marks.Count)

    if ($sshFailed) {
        $resultText = "blocked"
        $rationale += "SSH execution failed (exitCode=$exitCode): $probeError"
    }
    elseif ($Mode -eq "reach") {
        $stableValid = (M "STABLE_445") -eq "open" -and (M "STABLE_CONTROL") -ne "open"
        $gwValid = (M "GW_445") -eq "open" -and (M "GW_CONTROL") -ne "open"
        $anyAmbiguous = ((M "STABLE_445") -eq "open" -and (M "STABLE_CONTROL") -eq "open") -or
            ((M "GW_445") -eq "open" -and (M "GW_CONTROL") -eq "open")
        if ($stableValid) {
            $verdict = "FEASIBLE"; $resultText = "pass"; $recommendedHost = $stableHost
            $rationale += "VM reaches host 445 via the stable address $stableHost ($(M 'STABLE_445_MS') ms); control port $controlPort is $(M 'STABLE_CONTROL'), so 445 is a real listener."
            if ($gwValid) { $rationale += "Default Switch gateway $(M 'GATEWAY') also reaches 445 ($(M 'GW_445_MS') ms) but is not stable across host reboots (N3)." }
        }
        elseif ($gwValid) {
            $verdict = "FEASIBLE"; $resultText = "pass"; $recommendedHost = M "GATEWAY"
            $rationale += "VM reaches host 445 only via the Default Switch gateway $(M 'GATEWAY') ($(M 'GW_445_MS') ms); STABLE_445=$(M 'STABLE_445')."
            $rationale += "Gateway address changes across host reboots (N3): the mount needs a fixed internal switch address before production use."
        }
        elseif ($anyAmbiguous) {
            $rationale += "445 and control port $controlPort both accept connections; a middlebox may be answering. Mount-test is needed to confirm."
        }
        else {
            $verdict = "INFEASIBLE"; $resultText = "pass"
            $rationale += "VM cannot reach host 445 (GW_445=$(M 'GW_445'), STABLE_445=$(M 'STABLE_445')): host firewall or routing must change before the SMB mount option."
        }
        $rationale += "cifs client: kernel $(M 'KERNEL'), module=$(M 'CIFS_MODULE'), cifs-utils installed=$(M 'CIFS_UTILS') candidate=$(M 'CIFS_UTILS_CANDIDATE'), passwordless sudo=$(M 'SUDO_NOPASSWD')."
        $rationale += "Reach covers only the network leg of U10; the U10 verdict for the share itself needs mount-test."
    }
    elseif ($Mode -eq "setup") {
        $verdict = "INCONCLUSIVE"
        $ok = (M "SUDO_NOPASSWD") -eq "yes" -and (M "SUDOERS_VALID") -eq "yes" -and
            (M "CIFS_UTILS") -in @("already", "installed") -and (M "CRED") -in @("written", "skipped") -and
            (M "CRED_STAT") -eq "600 root:root"
        if ($ok) { $resultText = "pass" }
        elseif ((M "SUDO_SETUP") -in @("bad-password", "no-password-given")) { $resultText = "blocked"; $gate = "sudo-nopasswd-required" }
        $rationale += "sudo before=$(M 'SUDO_BEFORE') setup=$(M 'SUDO_SETUP') nopasswd=$(M 'SUDO_NOPASSWD') sudoers valid=$(M 'SUDOERS_VALID')."
        $rationale += "cifs-utils=$(M 'CIFS_UTILS') $(M 'CIFS_UTILS_VERSION'); credentials=$(M 'CRED') stat=$(M 'CRED_STAT')."
        $rationale += "Setup prepares mount-test; it does not produce a U10 Verdict."
    }
    else {
        $readOk = (M "MOUNT") -eq "ok" -and (M "READ") -eq "ok"
        $writeOk = (M "WRITE") -eq "ok" -and (M "READBACK") -eq "ok" -and (M "DELETE") -eq "ok"
        if ((M "MOUNT") -eq "failed") {
            $verdict = "INFEASIBLE"; $resultText = "pass"
            $rationale += "Mount of $unc failed: $(M 'MOUNT_ERROR'). Check the host share, share permissions and the credentials file."
        }
        elseif (-not $marks.Contains("MOUNT")) {
            $resultText = "blocked"
            $gate = $(if ((M "SUDO_NOPASSWD") -ne "yes") { "sudo-nopasswd-required" } else { "host-share-required" })
            $rationale += "Preconditions not met: sudo=$(M 'SUDO_NOPASSWD') cifs-utils=$(M 'CIFS_UTILS') credentials=$(M 'CRED')."
        }
        elseif ($readOk -and $ProductionWrite -and $writeOk) {
            $verdict = "FEASIBLE"; $resultText = "pass"
            $rationale += "Mounted $unc (SMB $(M 'SMB_VERS')); read historical $(M 'SAMPLE') ($(M 'SAMPLE_BYTES') bytes) in $(M 'READ_MS') ms; wrote/read back/deleted 200 KB under _probe in $(M 'WRITE_MS')/$(M 'READBACK_MS') ms."
        }
        elseif ($readOk) {
            $resultText = "pass"
            $rationale += "Read-only mount of $unc works (SMB $(M 'SMB_VERS')): $(M 'TOP_DIRS') top dirs, historical $(M 'SAMPLE') read in $(M 'READ_MS') ms, $(M 'STAT_COUNT') stats in $(M 'STAT_TOTAL_MS') ms."
            if ($ProductionWrite) { $rationale += "Write probe failed: WRITE=$(M 'WRITE') READBACK=$(M 'READBACK') DELETE=$(M 'DELETE')." ; $verdict = "INFEASIBLE" }
            else { $rationale += "Write not tested (needs -ProductionWrite after production-write-approval); U10 Verdict stays INCONCLUSIVE." }
        }
        else {
            $rationale += "Mounted but reading failed: READ=$(M 'READ') SAMPLE=$(M 'SAMPLE')."
        }
        $rationale += "Unmount=$(M 'UNMOUNT'); _tus on share=$(M 'TUS_DIR')."
    }

    $parse = [ordered]@{
        fevId = "U10"; stage = $Mode; analyzedBy = "agent"; verdict = $verdict; gate = $gate
        recommendedHost = $recommendedHost; productionWrite = [bool]$ProductionWrite; markers = $marks; rationale = $rationale
    }
    Write-Utf8NoBom -Path (Join-Path $prepareDir "u10-$Mode-parse.json") -Content ($parse | ConvertTo-Json -Depth 6)

    $p0 = [bool](Get-Command ssh -ErrorAction SilentlyContinue)
    $p1 = $exitCode -eq 0
    $p2 = $p1 -and $verdict -in @("FEASIBLE", "INFEASIBLE")
    $summary = [ordered]@{
        graphId = "fev-u10-uploads-smb"; graphPath = "pipelines/graphs/ops/fev-u10-uploads-smb"
        runId = Split-Path -Leaf $RunDir; result = $resultText; fevId = "U10"; mode = $Mode
        host = $hostVal; user = $userVal; port = $portVal; exitCode = $exitCode
        levels = [ordered]@{ P0 = $p0; P1 = $p1; P2 = $p2; P3 = "user-only" }
        verdict = $verdict; gate = $gate; recommendedHost = $recommendedHost; productionWrite = [bool]$ProductionWrite; error = $probeError
    }
    Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 6)

    $markMd = ($marks.Keys | ForEach-Object { "| $_ | $($marks[$_]) |" }) -join "`n"
    $ratMd = ($rationale | ForEach-Object { "- $_" }) -join "`n"
    Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content @"
# fev-u10-uploads-smb report (FEV U10 $Mode) — Agent analysis

- run: ``$($summary.runId)`` · mode: ``$Mode`` · result: ``$resultText``
- target: ``${userVal}@${hostVal}:$portVal``
- **Verdict (Agent): ``$verdict``**$(if ($gate) { " · gate: ``$gate``" })$(if ($recommendedHost) { " · host: ``$recommendedHost``" })
- P0/P1/P2: $p0 / $p1 / $p2

## Rationale (Agent)

$ratMd

## Markers

| key | value |
|-----|-------|
$markMd

证据：``ssh/`` ``prepare/u10-$Mode-parse.json``。FEV Verdict 只回答可行性，不是产品 APPROVED / OpenSpec。
"@
    Write-Utf8NoBom -Path (Join-Path $RunDir "acceptance.md") -Content @"
# Acceptance — fev-u10-uploads-smb (run $($summary.runId), mode $Mode)

| 项 | 值 |
|----|----|
| P0 | $(if ($p0) { "pass" } else { "fail" }) |
| P1 | $(if ($p1) { "pass" } else { "fail" }) |
| P2 | $(if ($p2) { "pass" } else { "fail" }) |
| FEV U10 Verdict (Agent) | $verdict |
| P3（用户采纳） | pending |
"@

    Write-Host "[fev-u10-uploads-smb] result=$resultText verdict=$verdict$(if ($gate) { " gate=$gate" })$(if ($recommendedHost) { " host=$recommendedHost" })"
    if ($resultText -eq "pass") { exit 0 } else { exit 1 }
}
finally {
    if ($batchPath -and (Test-Path -LiteralPath $batchPath)) {
        & icacls.exe $batchPath /grant:r "${env:USERNAME}:(F)" | Out-Null
        Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
        Write-Host "[fev-u10-uploads-smb] removed temp batch identity"
    }
}
