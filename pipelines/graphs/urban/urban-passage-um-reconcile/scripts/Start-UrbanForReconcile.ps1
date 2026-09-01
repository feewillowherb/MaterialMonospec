#Requires -Version 5.1
<#
.SYNOPSIS
  Build and start MaterialClient.Urban for urban-passage-um-reconcile ClientUpload.
.DESCRIPTION
  Seeds license, sets UrbanManagement__BaseUrl to UM reconcile target, enables diagnostic host,
  optionally shortens upload polling interval, then launches MaterialClient.Urban.
#>
[CmdletBinding()]
param(
    [string] $UmBaseUrl = "http://localhost:44300",
    [string] $UrbanProject = "",
    [string] $Configuration = "Debug",
    [string] $SeedRelPath = "seeds/demo-license.json",
    [int] $UploadPollingPeriodMs = 5000,
    [switch] $SkipBuild,
    [switch] $SkipSeed,
    [switch] $SkipConfirm,
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
    Write-Host "[start-urban-reconcile] building MaterialClient.Urban ($Configuration)..."
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

$MigrationScript = Join-Path $RepoRoot "pipelines/_shared/urban/tools/apply-urban-migration-once.mjs"
$DatabasePath = Join-Path $urbanDir "MaterialClient.db"
if ((Test-Path -LiteralPath $MigrationScript) -and (Test-Path -LiteralPath $DatabasePath)) {
    Write-Host "[start-urban-reconcile] ensuring UrbanPassageRecords sync columns..."
    & node $MigrationScript $DatabasePath | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Urban SQLite migration helper failed (exit $LASTEXITCODE)."
    }
}

if (-not $SkipSeed) {
    . $LicenseScript
    Invoke-UrbanLicenseSeed -Mode Local -UrbanAppDir $urbanDir -SeedRelPath $SeedRelPath -SkipConfirm:$SkipConfirm | Out-Host
}
else {
    Write-Host "[start-urban-reconcile] skipping license seed (-SkipSeed)."
}

$env:UrbanManagement__BaseUrl = $UmBaseUrl.Trim().TrimEnd('/')
$env:MinimalWebHost__EnableOnStartup = "true"
$env:Urban__UploadPollingPeriodMs = [string]$UploadPollingPeriodMs

Write-Host "[start-urban-reconcile] client env:"
Write-Host "  UrbanManagement__BaseUrl=$($env:UrbanManagement__BaseUrl)"
Write-Host "  MinimalWebHost__EnableOnStartup=$($env:MinimalWebHost__EnableOnStartup)"
Write-Host "  Urban__UploadPollingPeriodMs=$($env:Urban__UploadPollingPeriodMs)"

if ($NoLaunch) {
    Write-Host "[start-urban-reconcile] prepare complete; -NoLaunch set."
    return
}

$existing = Get-Process -Name "MaterialClient.Urban" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Warning "MaterialClient.Urban already running (PID $($existing.Id -join ',')); env vars apply only to new process."
    Write-Warning "Restart Urban manually if BaseUrl changed."
    return
}

$p = Start-Process -FilePath $urbanExe -WorkingDirectory $urbanDir -PassThru
Write-Host "[start-urban-reconcile] started PID=$($p.Id). Wait for http://localhost:9961/ then run Invoke-UrbanPassageUmReconcile.ps1 -Mode ClientUpload -SkipConfirm"
