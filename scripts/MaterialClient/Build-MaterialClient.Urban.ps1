<#
.SYNOPSIS
  Build MaterialClient.Urban into repos/MaterialClient/.build-verify/Urban

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.Urban.ps1
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
    -ProjectRelativePath 'src\MaterialClient.Urban\MaterialClient.Urban.csproj' `
    -App 'Urban' `
    -ExpectedExeName 'MaterialClient.Urban.exe' `
    -Configuration $Configuration `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit | Out-Null

