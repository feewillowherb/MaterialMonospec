<#
.SYNOPSIS
  Build MaterialClient.Recycle into repos/MaterialClient/.build-verify/Recycle

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.Recycle.ps1
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
    -ProjectRelativePath 'src\MaterialClient.Recycle\MaterialClient.Recycle.csproj' `
    -App 'Recycle' `
    -ExpectedExeName 'MaterialClient.Recycle.exe' `
    -Configuration $Configuration `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit | Out-Null

