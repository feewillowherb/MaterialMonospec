#Requires -Version 5.1
<#
.SYNOPSIS
  Build and start MaterialClient.Urban for urban-license-probe.
.DESCRIPTION
  Builds MaterialClient.Urban, seeds license via upsert-license-info (Invoke-UrbanLicenseSeed Local),
  writes .last-seed.json for the probe invoke, then starts with MinimalWebHost__EnableOnStartup=true.
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

function Write-UrbanUtf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

if (-not $SkipBuild) {
    Write-Host "[urban-license-probe] building MaterialClient.Urban ($Configuration)..."
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

$lastSeedPath = Join-Path $PSScriptRoot ".last-seed.json"
$seedResult = $null

if (-not $SkipSeed) {
    . $LicenseScript
    $seedResult = Invoke-UrbanLicenseSeed -Mode Local -UrbanAppDir $urbanDir -SeedRelPath $SeedRelPath -SkipConfirm
    Write-UrbanUtf8NoBom -Path $lastSeedPath -Content ([ordered]@{
            graph           = "urban/urban-license-probe"
            mode            = "local"
            seedSkipped     = $false
            seedRelPath     = $SeedRelPath
            urbanAppDir     = $urbanDir
            databasePath    = [string]$seedResult.DatabasePath
            licenseFile     = [string]$seedResult.LicenseFile
            projectId       = [string]$seedResult.ProjectId
            accessCode      = [string]$seedResult.AccessCode
            machineCode     = [string]$seedResult.MachineCode
            seedMachineCode = [string]$seedResult.SeedMachineCode
            finishedAt      = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 6)
    Write-Host ("[urban-license-probe] seed complete. licenseFile={0}" -f $seedResult.LicenseFile)
}
else {
    Write-Host "[urban-license-probe] skipping license seed (-SkipSeed)."
    Write-UrbanUtf8NoBom -Path $lastSeedPath -Content ([ordered]@{
            graph       = "urban/urban-license-probe"
            mode        = "local"
            seedSkipped = $true
            seedRelPath = $SeedRelPath
            urbanAppDir = $urbanDir
            finishedAt  = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 6)
}

if ($NoLaunch) {
    Write-Host "[urban-license-probe] prepare complete; -NoLaunch set."
    return
}

$existing = Get-Process -Name "MaterialClient.Urban" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Warning "MaterialClient.Urban already running (PID $($existing.Id -join ',')); not starting another instance."
    return
}

$env:MinimalWebHost__EnableOnStartup = "true"

Write-Host "[urban-license-probe] launching $urbanExe ($Configuration; seed=$SeedRelPath)"
$p = Start-Process -FilePath $urbanExe -WorkingDirectory $urbanDir -PassThru
Write-Host "[urban-license-probe] started PID=$($p.Id). Wait for http://localhost:9961/ then run Invoke-UrbanLicenseProbe.ps1 -SkipConfirm"
