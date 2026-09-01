#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental probe: prove Urban Debug authorization bypass via diagnostic HTTP.
.DESCRIPTION
  Optionally starts Urban Debug with malformed license (no seed), then GET / and GET /api/settings.
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
$StartScript = Join-Path $PSScriptRoot "Start-UrbanDebugForBypassProbe.ps1"

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

Write-Host "[urban-debug-license-bypass] experimental Invoke starting..."

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
        "Will plant malformed license.urban, start Urban Debug (no seed), then GET {0}/ and {0}/api/settings. Type YES to continue" -f $baseUrl)
    if ($ans -ne "YES") { throw "Aborted at human gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$HttpDir = Join-Path $RunDir "http"
$PrepareDir = Join-Path $RunDir "prepare"
$LogsDir = Join-Path $RunDir "logs"
New-Item -ItemType Directory -Force -Path $HttpDir, $PrepareDir, $LogsDir | Out-Null

$startedByProbe = $false
if (-not $SkipStart) {
    & $StartScript
    $startedByProbe = $true
}

$lastPrepare = Join-Path $PSScriptRoot ".last-prepare.json"
if (Test-Path -LiteralPath $lastPrepare) {
    Copy-Item -LiteralPath $lastPrepare -Destination (Join-Path $PrepareDir "invalid-license.json") -Force
}
else {
    Write-Utf8NoBom (Join-Path $PrepareDir "invalid-license.json") (@{
        source = "missing"
        note   = "Start script did not write .last-prepare.json"
    } | ConvertTo-Json)
}

Write-Host "[urban-debug-license-bypass] waiting for diagnostic host..."
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
$rootBody = $null
$settingsBody = $null

try {
    $rootResp = Invoke-WebRequest -Uri "$baseUrl/" -Method Get -TimeoutSec 15 -UseBasicParsing
    $l0 = ($rootResp.StatusCode -eq 200)
    $rootBody = $rootResp.Content
    Write-Utf8NoBom (Join-Path $HttpDir "01-root.json") (@{
        url        = "$baseUrl/"
        statusCode = $rootResp.StatusCode
        body       = ($rootResp.Content | ConvertFrom-Json -ErrorAction SilentlyContinue)
        raw        = $rootResp.Content
    } | ConvertTo-Json -Depth 8)
}
catch {
    Write-Utf8NoBom (Join-Path $HttpDir "01-root.json") (@{
        url     = "$baseUrl/"
        success = $false
        error   = $_.Exception.Message
        ready   = $ready
        lastError = $lastError
    } | ConvertTo-Json -Depth 6)
}

try {
    $settingsResp = Invoke-WebRequest -Uri "$baseUrl/api/settings" -Method Get -TimeoutSec 30 -UseBasicParsing
    $l1 = ($settingsResp.StatusCode -eq 200)
    $settingsBody = $settingsResp.Content
    Write-Utf8NoBom (Join-Path $HttpDir "02-settings-get.json") (@{
        url        = "$baseUrl/api/settings"
        statusCode = $settingsResp.StatusCode
        bodyPreviewLength = $settingsResp.Content.Length
        # Full settings can be large; keep raw for evidence
        raw        = $settingsResp.Content
    } | ConvertTo-Json -Depth 4)
}
catch {
    Write-Utf8NoBom (Join-Path $HttpDir "02-settings-get.json") (@{
        url     = "$baseUrl/api/settings"
        success = $false
        error   = $_.Exception.Message
    } | ConvertTo-Json -Depth 6)
}

$prepareMeta = $null
$preparePath = Join-Path $PrepareDir "invalid-license.json"
if (Test-Path -LiteralPath $preparePath) {
    try { $prepareMeta = Get-Content -LiteralPath $preparePath -Raw | ConvertFrom-Json } catch { }
}
$seedSkipped = $true
if ($null -ne $prepareMeta -and $prepareMeta.PSObject.Properties.Name -contains "seedSkipped") {
    $seedSkipped = [bool]$prepareMeta.seedSkipped
}

$l2 = $l0 -and $l1 -and $seedSkipped

$logMarker = "DEBUG Urban authorization bypass active"
$logScan = [ordered]@{
    source = "missing"
    count  = 0
    marker = $logMarker
}
# Best-effort: Serilog under Urban output Logs/ if present
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../../../..")).Path
$urbanLogs = Join-Path $RepoRoot "repos/MaterialClient/src/MaterialClient.Urban/bin/Debug/net10.0/win-x64/Logs"
if (Test-Path -LiteralPath $urbanLogs) {
    $hits = Select-String -Path (Join-Path $urbanLogs "*") -Pattern $logMarker -ErrorAction SilentlyContinue | Select-Object -First 5
    if ($hits) {
        $logScan.source = $urbanLogs
        $logScan.count = @($hits).Count
        $logScan.samples = @($hits | ForEach-Object { $_.Line.Trim() })
        Write-Utf8NoBom (Join-Path $LogsDir "bypass-marker.json") ($logScan | ConvertTo-Json -Depth 6)
    }
    else {
        Write-Utf8NoBom (Join-Path $LogsDir "bypass-marker.json") ($logScan | ConvertTo-Json -Depth 6)
    }
}
else {
    Write-Utf8NoBom (Join-Path $LogsDir "bypass-marker.json") ($logScan | ConvertTo-Json -Depth 6)
}

$summary = [ordered]@{
    graph           = "urban/urban-debug-license-bypass"
    runDir          = $RunDir
    baseUrl         = $baseUrl
    startedByProbe  = $startedByProbe
    seedSkipped     = $seedSkipped
    levels          = [ordered]@{
        L0 = $l0
        L1 = $l1
        L2 = $l2
        L3 = "pending-user"
    }
    message         = "等待用户验收，尚未通过。"
}
Write-Utf8NoBom (Join-Path $RunDir "summary.json") ($summary | ConvertTo-Json -Depth 8)

$report = @"
# urban-debug-license-bypass report

- baseUrl: $baseUrl
- L0 GET /: $l0
- L1 GET /api/settings: $l1
- L2 started without valid JWT seed: $l2
- L3: pending（仅用户）

等待用户验收，尚未通过。
请验收：pass / fail + 对象与原因。
"@
Write-Utf8NoBom (Join-Path $RunDir "report.md") $report

Write-Host "[urban-debug-license-bypass] done. L0=$l0 L1=$l1 L2=$l2 runDir=$RunDir"
if (-not $l2) {
    exit 1
}
