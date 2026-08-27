<#
.SYNOPSIS
  Build MaterialClient.Recycle into repos/MaterialClient/.build-verify

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.Recycle.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug'
)

. (Join-Path $PSScriptRoot '_common.ps1')

Invoke-MaterialClientBuild `
    -ProjectRelativePath 'src\MaterialClient.Recycle\MaterialClient.Recycle.csproj' `
    -ExpectedExeName 'MaterialClient.Recycle.exe' `
    -Configuration $Configuration | Out-Null
