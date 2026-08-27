<#
.SYNOPSIS
  Build MaterialClient (main WinExe) into repos/MaterialClient/.build-verify/MaterialClient

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.ps1
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.ps1 -StopRunning
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',

    [switch] $StopRunning,

    [switch] $ShowNuGetAudit
)

. (Join-Path $PSScriptRoot '_common.ps1')

Invoke-MaterialClientBuild `
    -ProjectRelativePath 'src\MaterialClient\MaterialClient.csproj' `
    -App 'MaterialClient' `
    -ExpectedExeName 'MaterialClient.exe' `
    -Configuration $Configuration `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit | Out-Null

