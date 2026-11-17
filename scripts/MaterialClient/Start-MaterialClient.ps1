<#
.SYNOPSIS
  Compatibility shim → Start-MaterialClient.Standard.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',

    [switch] $NoBuild,

    [switch] $StopRunning,

    [switch] $ShowNuGetAudit,

    [switch] $Wait,

    [switch] $EnableDiagnosticHost
)

& (Join-Path $PSScriptRoot 'Start-MaterialClient.Standard.ps1') `
    -Configuration $Configuration `
    -NoBuild:$NoBuild `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit `
    -Wait:$Wait `
    -EnableDiagnosticHost:$EnableDiagnosticHost
