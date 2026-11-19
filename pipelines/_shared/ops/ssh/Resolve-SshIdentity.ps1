#Requires -Version 5.1
<#
.SYNOPSIS
  Resolve MaterialMonospec local SSH identity for Agent ops.
.DESCRIPTION
  Default private key: <repo>/.local/.ssh/docker-linux-ed25519 (gitignored; user-supplied).
  experimental shared helper — used by graphs/ops and other Agent SSH cooks.
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = "",
    [string] $IdentityFileName = "docker-linux-ed25519",
    [switch] $HardenAcl,
    [switch] $PassThru,
    [switch] $AllowMissingIdentity
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-MonospecRepoRoot {
    param([string] $Start)
    $dir = if ([string]::IsNullOrWhiteSpace($Start)) { $PSScriptRoot } else { $Start }
    $dir = (Resolve-Path -LiteralPath $dir).Path
    while ($true) {
        $marker = Join-Path $dir ".hagicode"
        $pipelines = Join-Path $dir "pipelines"
        if ((Test-Path -LiteralPath $marker) -and (Test-Path -LiteralPath $pipelines)) {
            return $dir
        }
        $parent = Split-Path -Parent $dir
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) {
            throw "Cannot resolve MaterialMonospec repo root from: $Start"
        }
        $dir = $parent
    }
}

$root = if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    Resolve-MonospecRepoRoot -Start $PSScriptRoot
} else {
    (Resolve-Path -LiteralPath $RepoRoot).Path
}

$sshDir = Join-Path $root ".local\.ssh"
$identity = Join-Path $sshDir $IdentityFileName
$pub = "$identity.pub"
$knownHosts = Join-Path $sshDir "known_hosts"

if (-not (Test-Path -LiteralPath $sshDir)) {
    if ($AllowMissingIdentity) {
        New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
    }
    else {
        throw @"
Missing SSH dir: $sshDir
Create it and place private key as: $IdentityFileName
(.local/ is gitignored; replace the key yourself — do not commit it.)
"@
    }
}

$identityPresent = Test-Path -LiteralPath $identity
if (-not $identityPresent) {
    if (-not $AllowMissingIdentity) {
        throw @"
Missing SSH private key: $identity
Copy/replace your docker-linux-ed25519 key into .local/.ssh/ (gitignored).
"@
    }
    $identity = $null
}

if (-not (Test-Path -LiteralPath $knownHosts)) {
    New-Item -ItemType File -Force -Path $knownHosts | Out-Null
}

$onWindows = ($env:OS -match "Windows") -or ($PSVersionTable.Platform -eq "Win32NT") -or (-not $PSVersionTable.Platform)
if ($HardenAcl -and $onWindows -and $identityPresent) {
    # OpenSSH on Windows rejects keys with overly broad ACLs.
    try {
        & icacls.exe $identity /inheritance:r | Out-Null
        & icacls.exe $identity /grant:r "${env:USERNAME}:(R)" | Out-Null
    }
    catch {
        Write-Warning "Failed to harden ACL on identity (continuing): $($_.Exception.Message)"
    }
}

$result = [ordered]@{
    repoRoot       = $root
    sshDir         = $sshDir
    identityFile   = $identity
    publicKeyFile  = $(if (Test-Path -LiteralPath $pub) { $pub } else { $null })
    knownHostsFile = $knownHosts
    identityExists = [bool]$identityPresent
    publicKeyExists = [bool](Test-Path -LiteralPath $pub)
}

if ($identityPresent) {
    Write-Host "[ops-ssh] identity=$identity"
}
else {
    Write-Host "[ops-ssh] identity=missing"
}
Write-Host "[ops-ssh] known_hosts=$knownHosts"

if ($PassThru) {
    return [pscustomobject]$result
}
