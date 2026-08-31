#Requires -Version 5.1
<#
.SYNOPSIS
  urban-passage-probe: run shared seed-settings (replace all LPR configs).
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$SharedScript = Join-Path $GraphRoot "../../../_shared/materialclient/Invoke-UrbanLprSeedSettings.ps1"
$SharedScript = [System.IO.Path]::GetFullPath($SharedScript)

if (-not (Test-Path -LiteralPath $SharedScript)) {
    throw "Missing shared script: $SharedScript"
}

. $SharedScript

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") ("seed-" + $stamp)
}

$result = Invoke-UrbanPassageLprSeedSettings -GraphRoot $GraphRoot -RunDir $RunDir -SkipConfirm:$SkipConfirm
Write-Host ("[seed-settings] runDir={0}" -f $RunDir)
if (-not $result.SettingsSaveOk) {
    exit 1
}
