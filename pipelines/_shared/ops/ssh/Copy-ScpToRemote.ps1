#Requires -Version 5.1
<#
.SYNOPSIS
  Upload local files to a remote directory over scp using the repo-local docker-linux-ed25519 key.
.DESCRIPTION
  Shared Agent helper; same identity / known_hosts handling as Invoke-SshRemote.ps1.
  The remote directory must already exist. experimental.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $HostName,

    [Parameter(Mandatory = $true)]
    [string] $User,

    [Parameter(Mandatory = $true)]
    [string[]] $LocalPath,

    [Parameter(Mandatory = $true)]
    [string] $RemoteDir,

    [int] $Port = 22,
    [string] $RepoRoot = "",
    [string] $IdentityFileName = "docker-linux-ed25519",
    [string] $EvidenceDir = "",
    [int] $ConnectTimeoutSeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ResolveScript = Join-Path $PSScriptRoot "Resolve-SshIdentity.ps1"
$resolveArgs = @{ IdentityFileName = $IdentityFileName; PassThru = $true; HardenAcl = $true }
if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) { $resolveArgs.RepoRoot = $RepoRoot }
$identityInfo = & $ResolveScript @resolveArgs
$identity = [string]$identityInfo.identityFile
$knownHosts = [string]$identityInfo.knownHostsFile

$scpExe = Get-Command scp -ErrorAction SilentlyContinue
if (-not $scpExe) { throw "scp not found on PATH. Install Windows OpenSSH Client." }
foreach ($p in $LocalPath) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "Local file not found: $p" }
}

$scpArgs = @(
    "-i", $identity, "-P", "$Port", "-q",
    "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes",
    "-o", "StrictHostKeyChecking=accept-new", "-o", "UserKnownHostsFile=$knownHosts",
    "-o", "ConnectTimeout=$ConnectTimeoutSeconds", "-o", "LogLevel=ERROR"
) + $LocalPath + @("${User}@${HostName}:$($RemoteDir.TrimEnd('/'))/")

Write-Host "[ops-scp] target=${User}@${HostName}:$Port dir=$RemoteDir files=$($LocalPath.Count)"
$started = Get-Date
& $scpExe.Source @scpArgs
$code = $LASTEXITCODE
$durationMs = [int]((Get-Date) - $started).TotalMilliseconds

if (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
    $files = @($LocalPath | ForEach-Object {
            $item = Get-Item -LiteralPath $_
            [ordered]@{ name = $item.Name; bytes = $item.Length; sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() }
        })
    $meta = [ordered]@{
        host = $HostName; user = $User; port = $Port; remoteDir = $RemoteDir
        exitCode = $code; durationMs = $durationMs; startedAt = $started.ToString("o"); files = $files
    }
    [System.IO.File]::WriteAllText((Join-Path $EvidenceDir "meta.json"), ($meta | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
}

Write-Host "[ops-scp] exitCode=$code durationMs=$durationMs"
if ($code -ne 0) { throw "scp exited $code" }
