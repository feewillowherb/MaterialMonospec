<#
.SYNOPSIS
  Build (unless -NoBuild) and start MaterialClient.Urban.exe from .build-verify/Urban

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Urban.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',

    [switch] $NoBuild,

    [switch] $StopRunning,

    [switch] $ShowNuGetAudit,

    [switch] $Wait
)

. (Join-Path $PSScriptRoot '_common.ps1')

Start-MaterialClientApp `
    -ProjectRelativePath 'src\MaterialClient.Urban\MaterialClient.Urban.csproj' `
    -App 'Urban' `
    -ExeName 'MaterialClient.Urban.exe' `
    -Configuration $Configuration `
    -NoBuild:$NoBuild `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit `
    -Wait:$Wait | Out-Null

