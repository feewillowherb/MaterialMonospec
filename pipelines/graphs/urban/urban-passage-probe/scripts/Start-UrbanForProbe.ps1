#Requires -Version 5.1
<#
.SYNOPSIS
  Build and start MaterialClient.Urban for urban-passage-probe.
.DESCRIPTION
  Builds MaterialClient.Urban, seeds license via upsert-license-info (shared Invoke-UrbanLicenseSeed),
  then starts the app with MinimalWebHost__EnableOnStartup=true.
#>
[CmdletBinding()]
param(
    [string] $UrbanProject = "",
    [string] $Configuration = "Debug",
    [string] $SeedRelPath = "seeds/demo-license.json",
    [switch] $SkipBuild,
    [switch] $SkipSeed,
    [switch] $NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../../../..")).Path
if ([string]::IsNullOrWhiteSpace($UrbanProject)) {
    $UrbanProject = Join-Path $RepoRoot "repos/MaterialClient/src/MaterialClient.Urban/MaterialClient.Urban.csproj"
}

$LicenseScript = Join-Path $RepoRoot "pipelines/_shared/urban/Invoke-UrbanLicenseSeed.ps1"
if (-not (Test-Path -LiteralPath $LicenseScript)) {
    throw "Missing shared license script: $LicenseScript"
}

if (-not $SkipBuild) {
    Write-Host "[start-urban-probe] building MaterialClient.Urban ($Configuration)..."
    dotnet build $UrbanProject -c $Configuration | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed."
    }
}

$urbanDir = Join-Path (Split-Path -Parent $UrbanProject) "bin/$Configuration/net10.0/win-x64"
if (-not (Test-Path -LiteralPath $urbanDir)) {
    throw "Urban output not found: $urbanDir (build first)."
}
$urbanDir = (Resolve-Path -LiteralPath $urbanDir).Path
$urbanExe = Join-Path $urbanDir "MaterialClient.Urban.exe"
if (-not (Test-Path -LiteralPath $urbanExe)) {
    throw "Urban executable not found: $urbanExe"
}

if (-not $SkipSeed) {
    . $LicenseScript
    Invoke-UrbanLicenseSeed -Mode Local -UrbanAppDir $urbanDir -SeedRelPath $SeedRelPath -SkipConfirm | Out-Host
}
else {
    Write-Host "[start-urban-probe] skipping license seed (-SkipSeed)."
}

if ($NoLaunch) {
    Write-Host "[start-urban-probe] prepare complete; -NoLaunch set."
    return
}

$existing = Get-Process -Name "MaterialClient.Urban" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Warning "MaterialClient.Urban already running (PID $($existing.Id -join ',')); not starting another instance."
    return
}

$env:MinimalWebHost__EnableOnStartup = "true"

Write-Host "[start-urban-probe] launching $urbanExe ($Configuration; license seed=$SeedRelPath)"
Write-Host "  MinimalWebHost__EnableOnStartup=$($env:MinimalWebHost__EnableOnStartup)"

$p = Start-Process -FilePath $urbanExe -WorkingDirectory $urbanDir -PassThru
Write-Host "[start-urban-probe] started PID=$($p.Id). Wait for http://localhost:9961/ then run Invoke-UrbanPassageProbe.ps1 -SkipConfirm"
