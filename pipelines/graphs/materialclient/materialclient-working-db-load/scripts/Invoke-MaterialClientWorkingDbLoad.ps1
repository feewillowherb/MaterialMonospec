#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental probe: overwrite the Start-MaterialClient environment database with the working copy, start that host, and scan the new log for errors.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"

function Get-YamlScalar {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*{0}\s*:\s*(.+)\s*$" -f [regex]::Escape($Key)
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }
    $value = $match.Groups[1].Value.Trim()
    if ($value.StartsWith('"') -and $value.EndsWith('"')) { $value = $value.Substring(1, $value.Length - 2) }
    return $value
}

function Read-SharedText {
    param([string] $Path)
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        return $reader.ReadToEnd()
    }
    finally {
        if ($reader) { $reader.Dispose() } else { $stream.Dispose() }
    }
}

function Get-FileSha256 {
    param([string] $Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$workingRel = Get-YamlScalar -Text $configText -Key "workingDb"
$waitSeconds = [int](Get-YamlScalar -Text $configText -Key "waitSeconds")
$completedText = Get-YamlScalar -Text $configText -Key "migrationCompleted"
$failedText = Get-YamlScalar -Text $configText -Key "migrationFailed"
if ([string]::IsNullOrWhiteSpace($workingRel)) { throw "config.yaml is missing workingDb" }
if ($waitSeconds -le 0) { $waitSeconds = 120 }

$secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
if (Test-Path -LiteralPath $secretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
    if ((Get-YamlScalar -Text $secretsText -Key "skipConfirm") -eq "true") { $SkipConfirm = $true }
}

$workingPath = Join-Path $RepoRoot $workingRel
$buildScript = Join-Path $RepoRoot "scripts\MaterialClient\Build-MaterialClient.ps1"
$startScript = Join-Path $RepoRoot "scripts\MaterialClient\Start-MaterialClient.ps1"
$clientRepo = Join-Path $RepoRoot "repos\MaterialClient"
$outDir = Join-Path $clientRepo ".build-verify\MaterialClient"
$environmentDb = Join-Path $outDir "MaterialClient.db"
$formalSample = Join-Path $RepoRoot "_tmp\1110\MaterialClient.db"

if (-not (Test-Path -LiteralPath $workingPath)) {
    throw "Missing working DB (human gate missing-working-db): $workingPath"
}
if (-not $SkipConfirm) {
    $answer = Read-Host "Will OVERWRITE the Start-MaterialClient environment MaterialClient.db with the working copy, then start MaterialClient.exe. Type YES to continue"
    if ($answer -ne "YES") { throw "Aborted at human gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path (Join-Path $RunDir "logs") | Out-Null

$formalBefore = if (Test-Path -LiteralPath $formalSample) { Get-FileSha256 $formalSample } else { "" }
$workingHash = Get-FileSha256 $workingPath

Write-Host "[materialclient-working-db-load] building MaterialClient into .build-verify/MaterialClient"
& powershell -ExecutionPolicy Bypass -File $buildScript -StopRunning
if ($LASTEXITCODE -ne 0) { throw "Build-MaterialClient.ps1 failed: $LASTEXITCODE" }

foreach ($suffix in @("-wal", "-shm")) {
    $sidecar = $environmentDb + $suffix
    if (Test-Path -LiteralPath $sidecar) { Remove-Item -LiteralPath $sidecar -Force }
}
Copy-Item -LiteralPath $workingPath -Destination $environmentDb -Force
$environmentHash = Get-FileSha256 $environmentDb
if ($environmentHash -ne $workingHash) { throw "Environment database hash does not match the working copy." }

Write-Host "[materialclient-working-db-load] starting MaterialClient.exe"
& powershell -ExecutionPolicy Bypass -File $startScript -NoBuild
$started = @(Get-Process -Name "MaterialClient" -ErrorAction SilentlyContinue)
if ($started.Count -eq 0) { throw "MaterialClient.exe did not stay running." }
$processId = $started[0].Id

try {
    $deadline = (Get-Date).AddSeconds($waitSeconds)
    $sawMigration = $false
    do {
        Start-Sleep -Seconds 2
        $latest = Get-ChildItem -LiteralPath (Join-Path $outDir "Logs") -Recurse -Filter "MaterialClient*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($latest) {
            $peek = Read-SharedText -Path $latest.FullName
            if ($peek.Contains($completedText) -or $peek.Contains($failedText)) {
                $sawMigration = $true
                break
            }
        }
    } while ((Get-Date) -lt $deadline)
}
finally {
    Get-Process -Name "MaterialClient" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

$logSource = Get-ChildItem -LiteralPath (Join-Path $outDir "Logs") -Recurse -Filter "MaterialClient*.log" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$logCopy = Join-Path $RunDir "logs\host.log"
if ($logSource) {
    [System.IO.File]::WriteAllText($logCopy, (Read-SharedText -Path $logSource.FullName), (New-Object System.Text.UTF8Encoding $false))
}
else {
    Set-Content -LiteralPath $logCopy -Value "" -Encoding utf8
}

$summaryPath = Join-Path $RunDir "summary.json"
Push-Location $PipelinesRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $PipelinesRoot "node_modules\tsx"))) {
        pnpm install
    }
    & pnpm exec tsx (Join-Path $PSScriptRoot "scan-load-log.ts") --log $logCopy --out $summaryPath --completed $completedText --failed $failedText
    $scanExit = $LASTEXITCODE
}
finally {
    Pop-Location
}

$formalAfter = if (Test-Path -LiteralPath $formalSample) { Get-FileSha256 $formalSample } else { "" }
$loaded = @{
    graphId = "materialclient-working-db-load"
    graphPath = "pipelines/graphs/materialclient/materialclient-working-db-load"
    runId = (Split-Path -Leaf $RunDir)
    processId = $processId
    environmentDbReplaced = ($environmentHash -eq $workingHash)
    formalSampleUnchanged = ($formalBefore -eq $formalAfter)
    sawMigrationLine = $sawMigration
}
$loaded | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $RunDir "load.json") -Encoding utf8

$scan = [System.IO.File]::ReadAllText($summaryPath) | ConvertFrom-Json
$report = @(
    "# materialclient-working-db-load",
    "",
    "result: $($scan.result)",
    "environmentDbReplaced: $($loaded.environmentDbReplaced)",
    "formalSampleUnchanged: $($loaded.formalSampleUnchanged)",
    "migrationCompleted: $($scan.migrationCompleted)",
    "migrationFailed: $($scan.migrationFailed)",
    "errorCount: $($scan.errorCount)",
    "ignoredWebHostCount: $($scan.ignoredWebHostCount)",
    "",
    "P3 is not set by this cook.",
    ""
) -join "`n"
[System.IO.File]::WriteAllText((Join-Path $RunDir "report.md"), $report, (New-Object System.Text.UTF8Encoding $false))

Write-Host "[materialclient-working-db-load] runId=$($loaded.runId) result=$($scan.result) errors=$($scan.errorCount)"
if ($scan.errorCount -gt 0) {
    $scan.errors | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
}
exit $scanExit
