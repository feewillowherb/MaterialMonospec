<#
.SYNOPSIS
  Build (unless -NoBuild) and start MaterialClient.exe from .build-verify

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.ps1
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.ps1 -NoBuild
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',

    [switch] $NoBuild,

    [switch] $Wait
)

. (Join-Path $PSScriptRoot '_common.ps1')

Start-MaterialClientApp `
    -ProjectRelativePath 'src\MaterialClient\MaterialClient.csproj' `
    -ExeName 'MaterialClient.exe' `
    -Configuration $Configuration `
    -NoBuild:$NoBuild `
    -Wait:$Wait | Out-Null
