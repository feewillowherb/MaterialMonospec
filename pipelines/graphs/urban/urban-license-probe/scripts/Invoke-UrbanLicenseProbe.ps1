#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental probe: verify MaterialClient.Urban starts with pipeline license seed.
.DESCRIPTION
  Optionally starts Urban with Invoke-UrbanLicenseSeed (Local), then GET / and GET /api/settings.
  Writes evidence under runs/<ts>/. Marked experimental.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [switch] $SkipStart,
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$StartScript = Join-Path $PSScriptRoot "Start-UrbanForLicenseProbe.ps1"

function Write-Utf8NoBom {
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

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing config: $ConfigPath"
}
if (-not (Test-Path -LiteralPath $StartScript)) {
    throw "Missing start script: $StartScript"
}

Write-Host "[urban-license-probe] experimental Invoke starting..."

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$baseUrl = "http://localhost:9961"
$fromConfig = Get-YamlScalarLocal -Text $configText -Key "baseUrl"
if (-not [string]::IsNullOrWhiteSpace($fromConfig)) {
    $baseUrl = $fromConfig.Trim().TrimEnd('/')
}
$secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
if (Test-Path -LiteralPath $secretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
    $fromSecrets = Get-YamlScalarLocal -Text $secretsText -Key "baseUrl"
    if (-not [string]::IsNullOrWhiteSpace($fromSecrets)) {
        $baseUrl = $fromSecrets.Trim().TrimEnd('/')
    }
}

if (-not $SkipConfirm) {
    $ans = Read-Host (
        "Will seed license (Local), start Urban, then GET {0}/ and {0}/api/settings. Type YES to continue" -f $baseUrl)
    if ($ans -ne "YES") { throw "Aborted at human gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$HttpDir = Join-Path $RunDir "http"
$PrepareDir = Join-Path $RunDir "prepare"
New-Item -ItemType Directory -Force -Path $HttpDir, $PrepareDir | Out-Null

$startedByProbe = $false
if (-not $SkipStart) {
    & $StartScript
    $startedByProbe = $true
}

$lastSeed = Join-Path $PSScriptRoot ".last-seed.json"
$seedMeta = $null
if (Test-Path -LiteralPath $lastSeed) {
    Copy-Item -LiteralPath $lastSeed -Destination (Join-Path $PrepareDir "license-seed.json") -Force
    try {
        $seedMeta = Get-Content -LiteralPath $lastSeed -Raw | ConvertFrom-Json
    }
    catch {
        $seedMeta = $null
    }
}
else {
    Write-Utf8NoBom (Join-Path $PrepareDir "license-seed.json") (@{
        source = "missing"
        note   = "Start script did not write .last-seed.json"
    } | ConvertTo-Json)
}

Write-Host "[urban-license-probe] waiting for diagnostic host..."
$ready = $false
$lastError = $null
for ($i = 0; $i -lt 30; $i++) {
    try {
        $null = Invoke-WebRequest -Uri "$baseUrl/" -Method Get -TimeoutSec 3 -UseBasicParsing
        $ready = $true
        break
    }
    catch {
        $lastError = $_.Exception.Message
        Start-Sleep -Seconds 2
    }
}

$l0 = $false
$l1 = $false

try {
    $rootResp = Invoke-WebRequest -Uri "$baseUrl/" -Method Get -TimeoutSec 15 -UseBasicParsing
    $l0 = ($rootResp.StatusCode -eq 200)
    Write-Utf8NoBom (Join-Path $HttpDir "01-root.json") (@{
        url        = "$baseUrl/"
        statusCode = $rootResp.StatusCode
        body       = ($rootResp.Content | ConvertFrom-Json -ErrorAction SilentlyContinue)
        raw        = $rootResp.Content
    } | ConvertTo-Json -Depth 8)
}
catch {
    Write-Utf8NoBom (Join-Path $HttpDir "01-root.json") (@{
        url       = "$baseUrl/"
        success   = $false
        error     = $_.Exception.Message
        ready     = $ready
        lastError = $lastError
    } | ConvertTo-Json -Depth 6)
}

try {
    $settingsResp = Invoke-WebRequest -Uri "$baseUrl/api/settings" -Method Get -TimeoutSec 30 -UseBasicParsing
    $l1 = ($settingsResp.StatusCode -eq 200)
    Write-Utf8NoBom (Join-Path $HttpDir "02-settings-get.json") (@{
        url               = "$baseUrl/api/settings"
        statusCode        = $settingsResp.StatusCode
        bodyPreviewLength = $settingsResp.Content.Length
        raw               = $settingsResp.Content
    } | ConvertTo-Json -Depth 4)
}
catch {
    Write-Utf8NoBom (Join-Path $HttpDir "02-settings-get.json") (@{
        url     = "$baseUrl/api/settings"
        success = $false
        error   = $_.Exception.Message
    } | ConvertTo-Json -Depth 6)
}

$seedSkipped = $true
$licenseFileExists = $false
$licenseFilePath = $null
if ($null -ne $seedMeta) {
    if ($seedMeta.PSObject.Properties.Name -contains "seedSkipped") {
        $seedSkipped = [bool]$seedMeta.seedSkipped
    }
    if ($seedMeta.PSObject.Properties.Name -contains "licenseFile") {
        $licenseFilePath = [string]$seedMeta.licenseFile
        if (-not [string]::IsNullOrWhiteSpace($licenseFilePath)) {
            $licenseFileExists = Test-Path -LiteralPath $licenseFilePath
        }
    }
}

$l2 = $l0 -and $l1 -and (-not $seedSkipped) -and $licenseFileExists

$summary = @{
    graph             = "urban/urban-license-probe"
    runDir            = $RunDir
    baseUrl           = $baseUrl
    startedByProbe    = $startedByProbe
    seedSkipped       = $seedSkipped
    licenseFile       = $licenseFilePath
    licenseFileExists = $licenseFileExists
    projectId         = if ($null -ne $seedMeta) { [string]$seedMeta.projectId } else { $null }
    accessCode        = if ($null -ne $seedMeta) { [string]$seedMeta.accessCode } else { $null }
    levels            = @{
        L0 = $l0
        L1 = $l1
        L2 = $l2
        L3 = "pending-user"
    }
    message           = "Waiting for user acceptance; not passed yet."
}
Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 8)

$reportLines = @(
    "# urban-license-probe report"
    ""
    "- baseUrl: $baseUrl"
    "- L0 GET /: $l0"
    "- L1 GET /api/settings: $l1"
    "- L2 seed applied (not skipped, license.urban exists): $l2"
    "- licenseFile: $licenseFilePath"
    "- seedSkipped: $seedSkipped"
    "- L3: pending (user only)"
    ""
    "Waiting for user acceptance; not passed yet."
    "Please accept: pass / fail + object + reason."
)
Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content ($reportLines -join "`n")

Write-Host "[urban-license-probe] done. L0=$l0 L1=$l1 L2=$l2 runDir=$RunDir"
if (-not $l2) {
    exit 1
}
