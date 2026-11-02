#Requires -Version 5.1
<#
.SYNOPSIS
  Create a temporary BatchMode-compatible identity from a passphrase-protected key.
.DESCRIPTION
  Copies .local/.ssh/<name> → <name>.batch, removes passphrase via ssh-keygen,
  hardens ACL. Caller MUST remove the .batch file when done.
  experimental shared helper — Windows ssh-agent service often Disabled without admin.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Passphrase,

    [string] $RepoRoot = "",
    [string] $IdentityFileName = "docker-linux-ed25519",
    [string] $BatchSuffix = ".batch",
    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ResolveScript = Join-Path $PSScriptRoot "Resolve-SshIdentity.ps1"
$resolveArgs = @{
    IdentityFileName = $IdentityFileName
    PassThru         = $true
}
if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    $resolveArgs.RepoRoot = $RepoRoot
}
$info = & $ResolveScript @resolveArgs
$source = [string]$info.identityFile
$sshDir = [string]$info.sshDir
$batchName = $IdentityFileName + $BatchSuffix
$batchPath = Join-Path $sshDir $batchName

if (Test-Path -LiteralPath $batchPath) {
    & icacls.exe $batchPath /grant:r "${env:USERNAME}:(F)" | Out-Null
    Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
}

Copy-Item -LiteralPath $source -Destination $batchPath -Force
& icacls.exe $batchPath /inheritance:r | Out-Null
& icacls.exe $batchPath /grant:r "${env:USERNAME}:(F)" | Out-Null

# PowerShell quoting of empty -N is unreliable; use cmd.
$cmd = "ssh-keygen -p -f `"$batchPath`" -P `"$Passphrase`" -N `"`""
cmd.exe /c $cmd | Out-Null
if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
    throw "ssh-keygen failed to unlock identity (exit $LASTEXITCODE). Check passphrase."
}

& icacls.exe $batchPath /inheritance:r | Out-Null
& icacls.exe $batchPath /grant:r "${env:USERNAME}:(R)" | Out-Null

# Smoke: must not prompt
$null = & ssh-keygen -y -f $batchPath 2>&1
if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
    throw "Unlocked identity still not usable by ssh-keygen -y"
}

Write-Host "[ops-ssh] unlocked-batch=$batchPath"

$result = [pscustomobject]@{
    identityFileName = $batchName
    identityFile     = $batchPath
    sourceFile       = $source
    sshDir           = $sshDir
}

if ($PassThru) { return $result }
