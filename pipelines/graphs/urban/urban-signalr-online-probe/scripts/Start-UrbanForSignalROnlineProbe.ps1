#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental: build/seed/start MaterialClient.Urban for SignalR online probe.
.DESCRIPTION
  Local license seed (no BasePlatform). Sets SignalR__ServerUrl to UM DeviceStatusHub
  and enables MinimalWebHost diagnostic port.
#>
[CmdletBinding()]
param(
    [string] $UmBaseUrl = "",
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
$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"

function Write-UrbanUtf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-YamlScalarLocal {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*{0}\s*:\s*(.+)\s*$" -f [regex]::Escape($Key)
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { return $null }
    return ($m.Groups[1].Value.Trim().Trim('"').Trim("'"))
}

$configText = ""
if (Test-Path -LiteralPath $ConfigPath) {
    $configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
}

if ([string]::IsNullOrWhiteSpace($UmBaseUrl)) {
    $UmBaseUrl = Get-YamlScalarLocal -Text $configText -Key "umBaseUrl"
    if ([string]::IsNullOrWhiteSpace($UmBaseUrl)) { $UmBaseUrl = "http://127.0.0.1:44371" }
}
$UmBaseUrl = $UmBaseUrl.Trim().TrimEnd('/')

$secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
if (Test-Path -LiteralPath $secretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
    $fromSecrets = Get-YamlScalarLocal -Text $secretsText -Key "umBaseUrl"
    if (-not [string]::IsNullOrWhiteSpace($fromSecrets)) {
        $UmBaseUrl = $fromSecrets.Trim().TrimEnd('/')
    }
}

$hubPath = Get-YamlScalarLocal -Text $configText -Key "hubPath"
if ([string]::IsNullOrWhiteSpace($hubPath)) { $hubPath = "/hubs/devicestatus" }
if (-not $hubPath.StartsWith("/")) { $hubPath = "/" + $hubPath }
$signalRUrl = "$UmBaseUrl$hubPath"

if ([string]::IsNullOrWhiteSpace($UrbanProject)) {
    $UrbanProject = Join-Path $RepoRoot "repos/MaterialClient/src/MaterialClient.Urban/MaterialClient.Urban.csproj"
}

$LicenseScript = Join-Path $RepoRoot "pipelines/_shared/urban/Invoke-UrbanLicenseSeed.ps1"
if (-not (Test-Path -LiteralPath $LicenseScript)) {
    throw "Missing shared license script: $LicenseScript"
}

if (-not $SkipBuild) {
    Write-Host "[urban-signalr-online-probe] building MaterialClient.Urban ($Configuration)..."
    & dotnet build $UrbanProject -c $Configuration | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build MaterialClient.Urban failed."
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
            graph           = "urban/urban-signalr-online-probe"
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
            signalRUrl      = $signalRUrl
            finishedAt      = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 6)
    Write-Host ("[urban-signalr-online-probe] seed complete. licenseFile={0}" -f $seedResult.LicenseFile)
}
else {
    Write-Host "[urban-signalr-online-probe] skipping license seed (-SkipSeed)."
    Write-UrbanUtf8NoBom -Path $lastSeedPath -Content ([ordered]@{
            graph       = "urban/urban-signalr-online-probe"
            mode        = "local"
            seedSkipped = $true
            seedRelPath = $SeedRelPath
            urbanAppDir = $urbanDir
            signalRUrl  = $signalRUrl
            finishedAt  = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 6)
}

$env:MinimalWebHost__EnableOnStartup = "true"
$env:SignalR__ServerUrl = $signalRUrl

Write-Host "[urban-signalr-online-probe] client env:"
Write-Host "  MinimalWebHost__EnableOnStartup=$($env:MinimalWebHost__EnableOnStartup)"
Write-Host "  SignalR__ServerUrl=$($env:SignalR__ServerUrl)"

if ($NoLaunch) {
    Write-Host "[urban-signalr-online-probe] Urban prepare complete; -NoLaunch set."
    return
}

$existing = Get-Process -Name "MaterialClient.Urban" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Warning "MaterialClient.Urban already running (PID $($existing.Id -join ',')); not starting another instance."
    Write-Warning "Restart Urban manually if SignalR__ServerUrl changed."
    return
}

$p = Start-Process -FilePath $urbanExe -WorkingDirectory $urbanDir -PassThru
Write-Host "[urban-signalr-online-probe] Urban started PID=$($p.Id)."
