<#
.SYNOPSIS
  Build MaterialClient Standard host into repos/MaterialClient/.build-verify/MaterialClient

.DESCRIPTION
  Standard only (HostProduct.Standard). SolidWaste uses Build-MaterialClient.SolidWaste.ps1.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.Standard.ps1
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.Standard.ps1 -StopRunning
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
