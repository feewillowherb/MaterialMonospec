<#
.SYNOPSIS
  Build MaterialClient (main WinExe) into repos/MaterialClient/.build-verify

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.ps1
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Build-MaterialClient.ps1 -Configuration Release
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug'
)

. (Join-Path $PSScriptRoot '_common.ps1')

Invoke-MaterialClientBuild `
    -ProjectRelativePath 'src\MaterialClient\MaterialClient.csproj' `
    -ExpectedExeName 'MaterialClient.exe' `
    -Configuration $Configuration | Out-Null
