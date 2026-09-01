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
$logScan = @{
    source     = "missing"
    count      = 0
    marker     = $logMarker
    logFiles   = @()
    samples    = @()
    copied     = @()
}
# Serilog uses Logs/yyyy/MM/dd/MaterialClient.Urban-*.log (see SerilogFileLogConfigurator).
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../../../..")).Path
$urbanLogs = Join-Path $RepoRoot "repos/MaterialClient/src/MaterialClient.Urban/bin/Debug/net10.0/win-x64/Logs"
$logSinkDir = Join-Path $LogsDir "serilog"
New-Item -ItemType Directory -Force -Path $logSinkDir | Out-Null

if (Test-Path -LiteralPath $urbanLogs) {
    $logFiles = @(Get-ChildItem -LiteralPath $urbanLogs -Recurse -File -Filter "MaterialClient.Urban-*.log" |
        Sort-Object LastWriteTime -Descending)
    $logScan.logRoot = $urbanLogs
    $logScan.logFiles = @($logFiles | Select-Object -First 5 | ForEach-Object { $_.FullName })

    if ($logFiles.Count -gt 0) {
        $logScan.source = $logFiles[0].FullName
        $searchTargets = @($logFiles | Select-Object -First 3)
        $hitLines = @()
        foreach ($lf in $searchTargets) {
            try {
                $partial = Select-String -LiteralPath $lf.FullName -Pattern $logMarker -ErrorAction Stop |
                    Select-Object -First 5
                if ($partial) {
                    $hitLines += @($partial | ForEach-Object {
                            "{0}:{1}: {2}" -f $_.Filename, $_.LineNumber, $_.Line.Trim()
                        })
                }
            }
            catch {
                $logScan.selectError = $_.Exception.Message
            }

            # Copy evidence with FileShare.ReadWrite so an active Serilog writer does not block.
            $destName = $lf.Name
            $destPath = Join-Path $logSinkDir $destName
            try {
                $srcStream = [System.IO.File]::Open(
                    $lf.FullName,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::ReadWrite)
                try {
                    $dstStream = [System.IO.File]::Create($destPath)
                    try {
                        $srcStream.CopyTo($dstStream)
                    }
                    finally {
                        $dstStream.Dispose()
                    }
                }
                finally {
                    $srcStream.Dispose()
                }
                $logScan.copied += @($destName)
            }
            catch {
                $logScan.copyError = $_.Exception.Message
                # Fallback: last 200 lines via Get-Content (often works under share)
                try {
                    $tail = Get-Content -LiteralPath $lf.FullName -Tail 200 -ErrorAction Stop
                    Write-Utf8NoBom -Path (Join-Path $logSinkDir ($lf.BaseName + ".tail.txt")) -Content ($tail -join "`n")
                    $logScan.copied += @($lf.BaseName + ".tail.txt")
                }
                catch {
                    $logScan.tailError = $_.Exception.Message
                }
            }
        }

        $logScan.count = $hitLines.Count
        $logScan.samples = $hitLines
        if ($hitLines.Count -eq 0) {
            $logScan.note = "Log files found and copied, but marker not present in newest files."
        }
    }
    else {
        $logScan.note = "Logs directory exists but no MaterialClient.Urban-*.log under dated folders."
    }
}
else {
    $logScan.note = "Urban Logs directory missing: $urbanLogs"
}

Write-Utf8NoBom -Path (Join-Path $LogsDir "bypass-marker.json") -Content ($logScan | ConvertTo-Json -Depth 6)

$summary = @{
    graph          = "urban/urban-debug-license-bypass"
    runDir         = $RunDir
    baseUrl        = $baseUrl
    startedByProbe = $startedByProbe
    seedSkipped    = $seedSkipped
    levels         = @{
        L0 = $l0
        L1 = $l1
        L2 = $l2
        L3 = "pending-user"
    }
    message        = "Waiting for user acceptance; not passed yet."
}
$summaryJson = $summary | ConvertTo-Json -Depth 8
Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content $summaryJson

$reportLines = @(
    "# urban-debug-license-bypass report"
    ""
    "- baseUrl: $baseUrl"
    "- L0 GET /: $l0"
    "- L1 GET /api/settings: $l1"
    "- L2 started without valid JWT seed: $l2"
    "- L3: pending (user only)"
    ""
    "Waiting for user acceptance; not passed yet."
    "Please accept: pass / fail + object + reason."
)
Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content ($reportLines -join "`n")

Write-Host "[urban-debug-license-bypass] done. L0=$l0 L1=$l1 L2=$l2 runDir=$RunDir"
if (-not $l2) {
    exit 1
}
