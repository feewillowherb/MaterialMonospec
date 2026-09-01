#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental: prepare invalid license and start MaterialClient.Urban Debug for bypass probe.
.DESCRIPTION
  Writes a malformed license.urban into the Urban Debug output directory, then launches
  Start-UrbanForProbe.ps1 with Configuration=Debug (default skips license seed).
  Marked experimental — do not treat as product code.
#>
[CmdletBinding()]
param(
    [string] $UrbanProject = "",
    [string] $Configuration = "Debug",
    [switch] $SkipBuild,
    [switch] $NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Configuration -ne "Debug") {
    throw "This Graph only supports Configuration=Debug (Release remains strict)."
}

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../../../..")).Path
$StartScript = Join-Path $GraphRoot "../urban-passage-probe/scripts/Start-UrbanForProbe.ps1"
$StartScript = [System.IO.Path]::GetFullPath($StartScript)
if (-not (Test-Path -LiteralPath $StartScript)) {
    throw "Missing start script: $StartScript"
}

if ([string]::IsNullOrWhiteSpace($UrbanProject)) {
    $UrbanProject = Join-Path $RepoRoot "repos/MaterialClient/src/MaterialClient.Urban/MaterialClient.Urban.csproj"
}
if (-not (Test-Path -LiteralPath $UrbanProject)) {
    throw "Urban project not found: $UrbanProject"
}

$urbanDir = Join-Path (Split-Path -Parent $UrbanProject) "bin/$Configuration/net10.0/win-x64"

Write-Host "[urban-debug-license-bypass] experimental Start preparing invalid license..."

if (-not $SkipBuild) {
    Write-Host "[urban-debug-license-bypass] building Urban Debug..."
    dotnet build $UrbanProject -c Debug | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed."
    }
}

if (-not (Test-Path -LiteralPath $urbanDir)) {
    throw "Urban output not found: $urbanDir"
}
$urbanDir = (Resolve-Path -LiteralPath $urbanDir).Path

$licensePath = Join-Path $urbanDir "license.urban"
$malformed = "NOT_A_VALID_JWT.invalid.signature"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($licensePath, $malformed, $utf8)
Write-Host "[urban-debug-license-bypass] wrote malformed license.urban at $licensePath"

$prepareNote = [ordered]@{
    graph            = "urban/urban-debug-license-bypass"
    configuration    = "Debug"
    seedSkipped      = $true
    licenseUrbanPath = $licensePath
    licenseContent   = "malformed-placeholder"
    plantedAtUtc     = (Get-Date).ToUniversalTime().ToString("o")
}
$prepareJson = $prepareNote | ConvertTo-Json -Depth 6
$prepareOut = Join-Path $GraphRoot "scripts/.last-prepare.json"
[System.IO.File]::WriteAllText($prepareOut, $prepareJson, $utf8)

$startArgs = @{
    UrbanProject  = $UrbanProject
    Configuration = "Debug"
    SkipSeed      = $true
    # Already built above (or caller asked to skip); avoid a second build.
    SkipBuild     = $true
}
if ($NoLaunch) { $startArgs.NoLaunch = $true }

& $StartScript @startArgs
