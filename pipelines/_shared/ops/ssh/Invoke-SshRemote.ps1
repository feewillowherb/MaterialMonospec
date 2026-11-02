#Requires -Version 5.1
<#
.SYNOPSIS
  Run a remote command over SSH using the repo-local docker-linux-ed25519 key.
.DESCRIPTION
  Shared Agent helper. Host/user MUST come from the caller (secrets or explicit args).
  experimental — used by graphs/ops/ssh-agent and ad-hoc Agent ops.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $HostName,

    [Parameter(Mandatory = $true)]
    [string] $User,

    [Parameter(Mandatory = $true)]
    [string] $RemoteCommand,

    [int] $Port = 22,
    [string] $RepoRoot = "",
    [string] $IdentityFileName = "docker-linux-ed25519",
    [string] $EvidenceDir = "",
    [int] $ConnectTimeoutSeconds = 15,
    [switch] $SkipHardenAcl,
    [switch] $AllowDestructive,
    [switch] $SkipDestructiveCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ResolveScript = Join-Path $PSScriptRoot "Resolve-SshIdentity.ps1"
if (-not (Test-Path -LiteralPath $ResolveScript)) {
    throw "Missing Resolve-SshIdentity.ps1: $ResolveScript"
}

# Note: do NOT treat `>/dev/null` / `2>/dev/null` as destructive (redirects only).
$isDestructive = $false
if (-not $SkipDestructiveCheck) {
    $destructiveHints = @(
        '\brm\b', '\bmkfs\b', '\bdd\b', '\bshutdown\b', '\breboot\b',
        '\bpoweroff\b', '\buserdel\b', '\bpasswd\b', '\bchmod\s+777\b',
        '>\s*/(?!dev/null\b)'
    )
    foreach ($hint in $destructiveHints) {
        if ($RemoteCommand -match $hint) {
            $isDestructive = $true
            break
        }
    }
    if ($isDestructive -and -not $AllowDestructive) {
        throw @"
Remote command looks destructive and -AllowDestructive was not set:
  $RemoteCommand
Refuse to run. Pass -AllowDestructive only after an explicit human gate.
"@
    }
}

$resolveArgs = @{
    IdentityFileName = $IdentityFileName
    PassThru         = $true
}
if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    $resolveArgs.RepoRoot = $RepoRoot
}
if (-not $SkipHardenAcl) {
    $resolveArgs.HardenAcl = $true
}

$identityInfo = & $ResolveScript @resolveArgs
$identity = [string]$identityInfo.identityFile
$knownHosts = [string]$identityInfo.knownHostsFile
$sshDir = [string]$identityInfo.sshDir

if (-not (Test-Path -LiteralPath $sshDir)) {
    New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
}
if (-not (Test-Path -LiteralPath $knownHosts)) {
    New-Item -ItemType File -Force -Path $knownHosts | Out-Null
}

$sshExe = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $sshExe) {
    throw "ssh client not found on PATH. Install Windows OpenSSH Client or ensure ssh.exe is available."
}

$sshArgs = @(
    "-i", $identity,
    "-p", "$Port",
    "-o", "IdentitiesOnly=yes",
    "-o", "BatchMode=yes",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "UserKnownHostsFile=$knownHosts",
    "-o", "ConnectTimeout=$ConnectTimeoutSeconds",
    "-o", "LogLevel=ERROR",
    "${User}@${HostName}",
    $RemoteCommand
)

Write-Host "[ops-ssh] target=${User}@${HostName}:$Port"
Write-Host "[ops-ssh] command=$RemoteCommand"

$stdoutPath = $null
$stderrPath = $null
$metaPath = $null
if (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
    $stdoutPath = Join-Path $EvidenceDir "stdout.txt"
    $stderrPath = Join-Path $EvidenceDir "stderr.txt"
    $metaPath = Join-Path $EvidenceDir "meta.json"
}

$started = Get-Date
$tmpOut = [System.IO.Path]::GetTempFileName()
$tmpErr = [System.IO.Path]::GetTempFileName()
$code = 1
$stdout = ""
$stderr = ""

try {
    $p = Start-Process -FilePath $sshExe.Source `
        -ArgumentList $sshArgs `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $tmpOut `
        -RedirectStandardError $tmpErr
    $code = $p.ExitCode
    $stdout = [System.IO.File]::ReadAllText($tmpOut)
    $stderr = [System.IO.File]::ReadAllText($tmpErr)
}
finally {
    Remove-Item -LiteralPath $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue
}

$ended = Get-Date
$durationMs = [int](($ended - $started).TotalMilliseconds)

if ($stdoutPath) {
    [System.IO.File]::WriteAllText($stdoutPath, $stdout, [System.Text.UTF8Encoding]::new($false))
}
if ($stderrPath) {
    [System.IO.File]::WriteAllText($stderrPath, $stderr, [System.Text.UTF8Encoding]::new($false))
}
if ($metaPath) {
    $meta = [ordered]@{
        host             = $HostName
        user             = $User
        port             = $Port
        identityFile     = $identity
        knownHostsFile   = $knownHosts
        remoteCommand    = $RemoteCommand
        exitCode         = $code
        durationMs       = $durationMs
        startedAt        = $started.ToString("o")
        endedAt          = $ended.ToString("o")
        destructiveHint  = $isDestructive
        allowDestructive = [bool]$AllowDestructive
    }
    $json = ($meta | ConvertTo-Json -Depth 5)
    [System.IO.File]::WriteAllText($metaPath, $json, [System.Text.UTF8Encoding]::new($false))
}

if (-not [string]::IsNullOrWhiteSpace($stdout)) {
    Write-Host $stdout.TrimEnd()
}
if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    Write-Host $stderr.TrimEnd() -ForegroundColor DarkYellow
}

Write-Host "[ops-ssh] exitCode=$code durationMs=$durationMs"
if ($code -ne 0) {
    throw "ssh exited $code"
}

[pscustomobject]@{
    exitCode    = $code
    stdout      = $stdout
    stderr      = $stderr
    durationMs  = $durationMs
    evidenceDir = $EvidenceDir
}
