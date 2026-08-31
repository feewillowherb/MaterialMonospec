#Requires -Version 5.1
<#
.SYNOPSIS
  Seed demo license for MaterialClient.Urban (local file + SQLite).
.PARAMETER UrbanAppDir
  MaterialClient.Urban build/output directory containing MaterialClient.db.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $UrbanAppDir,

    [string] $DatabasePath = "",
    [string] $RunDir = "",
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SharedScript = Join-Path $PSScriptRoot "../../../_shared/urban/Invoke-UrbanLicenseSeed.ps1"
$SharedScript = [System.IO.Path]::GetFullPath($SharedScript)
if (-not (Test-Path -LiteralPath $SharedScript)) {
    throw "Missing shared script: $SharedScript"
}

. $SharedScript

Invoke-UrbanLicenseSeed -Mode Local -UrbanAppDir $UrbanAppDir -DatabasePath $DatabasePath `
    -RunDir $RunDir -SkipConfirm:$SkipConfirm
