<#
.SYNOPSIS
  Build MaterialClient.SolidWaste (SolidWaste host) into
  repos/MaterialClient/.build-verify/MaterialClient.SolidWaste

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.SolidWaste.ps1
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.SolidWaste.ps1 -StopRunning
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
    -ProjectRelativePath 'src\MaterialClient.SolidWaste\MaterialClient.SolidWaste.csproj' `
    -App 'SolidWaste' `
    -ExpectedExeName 'MaterialClient.SolidWaste.exe' `
    -Configuration $Configuration `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit | Out-Null
