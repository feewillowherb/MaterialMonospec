<#
.SYNOPSIS
  Compatibility shim → Build-MaterialClient.Standard.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',

    [switch] $StopRunning,

    [switch] $ShowNuGetAudit
)

& (Join-Path $PSScriptRoot 'Build-MaterialClient.Standard.ps1') `
    -Configuration $Configuration `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit
