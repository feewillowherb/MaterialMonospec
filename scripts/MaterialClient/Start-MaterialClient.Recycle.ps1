<#
.SYNOPSIS
  Build (unless -NoBuild) and start MaterialClient.Recycle.exe from .build-verify/Recycle

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Recycle.ps1
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
    -ProjectRelativePath 'src\MaterialClient.Recycle\MaterialClient.Recycle.csproj' `
    -App 'Recycle' `
    -ExeName 'MaterialClient.Recycle.exe' `
    -Configuration $Configuration `
    -NoBuild:$NoBuild `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit `
    -Wait:$Wait | Out-Null

