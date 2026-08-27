<#
.SYNOPSIS
  Build MaterialClient.Urban into repos/MaterialClient/.build-verify

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.Urban.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug'
)

. (Join-Path $PSScriptRoot '_common.ps1')

Invoke-MaterialClientBuild `
    -ProjectRelativePath 'src\MaterialClient.Urban\MaterialClient.Urban.csproj' `
    -ExpectedExeName 'MaterialClient.Urban.exe' `
    -Configuration $Configuration | Out-Null
