#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: pre-fix FEV for same-callback dual enqueue against a live MaterialClient process.

.DESCRIPTION
  Drives /api/lpr/test-plate and /api/scale/weight on the diagnostic host.
  Does NOT modify MaterialClient.db, appsettings, ScaleType, or DataDirectory.
  User prepares the DB (TestMode etc.) and the weighing UI.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.ps1 -EnableDiagnosticHost -StopRunning
  # login + open attended weighing
  powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-stable-dual-enqueue-repro/scripts/Invoke-FevStableDualEnqueueRepro.ps1
#>
[CmdletBinding()]
param(
    [switch] $StartHost,
    [switch] $NoBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsLocal = Join-Path $GraphRoot "secrets.local.yaml"
$ToolPath = Join-Path $GraphRoot "scripts\probe-fev-dual-enqueue.ts"
$FixturePath = Join-Path $GraphRoot "fixtures\scenario.json"
$StartScript = Join-Path $RepoRoot "scripts\MaterialClient\Start-MaterialClient.ps1"

function Get-YamlScalar {
    param([string] $Text, [string] $Key)
    $pattern = '(?m)^(?:  )?' + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $value = $Matches[1].Trim()
        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        return $value
    }
    return $null
}

function Get-Override {
    param([string] $Text, [string] $Key, [string] $Fallback)
    if ($Text) {
        $value = Get-YamlScalar -Text $Text -Key $Key
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
    }
    return $Fallback
}

Write-Host "[fev-stable-dual-enqueue-repro] starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing tool: $ToolPath" }
if (-not (Test-Path -LiteralPath $FixturePath)) { throw "Missing fixture: $FixturePath" }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$secretsText = ""
if (Test-Path -LiteralPath $SecretsLocal) {
    $secretsText = [System.IO.File]::ReadAllText($SecretsLocal, [System.Text.Encoding]::UTF8)
}

$baseUrl = Get-Override $secretsText "baseUrl" (Get-YamlScalar $configText "baseUrl")
$databaseRel = Get-Override $secretsText "databaseRel" (Get-YamlScalar $configText "databaseRel")
$logRel = Get-Override $secretsText "logRel" (Get-YamlScalar $configText "logRel")
$database = Join-Path $RepoRoot ($databaseRel -replace '/', '\')
$logRoot = Join-Path $RepoRoot ($logRel -replace '/', '\')

$stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
$runDir = Join-Path $GraphRoot "runs\$stamp"
if (Test-Path -LiteralPath $runDir) { throw "Run directory already exists: $stamp" }
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

if ($StartHost) {
    if (-not (Test-Path -LiteralPath $StartScript)) { throw "Missing start script: $StartScript" }
    Write-Host "[fev-stable-dual-enqueue-repro] starting MaterialClient (no DB/appsettings changes)"
    $startArgs = @("-ExecutionPolicy", "Bypass", "-File", $StartScript, "-EnableDiagnosticHost", "-StopRunning")
    if ($NoBuild) { $startArgs += "-NoBuild" }
    & powershell @startArgs
    if ($LASTEXITCODE -ne 0) { throw "Start-MaterialClient.ps1 failed: $LASTEXITCODE" }
}

Write-Host "[fev-stable-dual-enqueue-repro] waiting for diagnostic $baseUrl (fail-fast if MaterialClient exits)"
$ready = $false
for ($i = 1; $i -le 60; $i++) {
    $alive = @(Get-Process -Name "MaterialClient" -ErrorAction SilentlyContinue)
    if ($alive.Count -eq 0 -and $StartHost) {
        throw "MaterialClient.exe exited before diagnostic host was ready at $baseUrl"
    }
    try {
        $resp = Invoke-WebRequest -Uri ($baseUrl.TrimEnd('/') + '/') -UseBasicParsing -TimeoutSec 2
        if ($resp.StatusCode -eq 200) { $ready = $true; break }
    } catch {
        if (($i % 5) -eq 0) {
            Write-Host "[fev-stable-dual-enqueue-repro] still waiting ($i/60) processCount=$($alive.Count)"
        }
        Start-Sleep -Seconds 2
    }
}
if (-not $ready) {
    throw "Diagnostic host not ready at $baseUrl. Start with -EnableDiagnosticHost, login, open attended weighing; ensure TestMode yourself."
}

if (-not (Test-Path -LiteralPath $database)) {
    throw "Local MaterialClient database was not found at $databaseRel."
}

$code = 1
Push-Location $PipelinesRoot
try {
    $tsxOk = $false
    $null = & pnpm exec tsx --version 2>$null
    if ($LASTEXITCODE -eq 0) { $tsxOk = $true }
    if (-not $tsxOk) {
        Write-Host "[fev-stable-dual-enqueue-repro] pnpm install (tsx)..."
        & pnpm install
        if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }
    }
    Write-Host "[fev-stable-dual-enqueue-repro] baseUrl=$baseUrl"
    Write-Host "[fev-stable-dual-enqueue-repro] runDir=$runDir"
    & pnpm exec tsx $ToolPath `
        --run $runDir `
        --baseUrl $baseUrl `
        --database $database `
        --log $logRoot `
        --fixture $FixturePath `
        --repo $RepoRoot
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($code -ne 0) {
    throw "probe-fev-dual-enqueue.ts exited $code (2 means diagnostic host / test mode / weighing not ready)"
}

Write-Host "[fev-stable-dual-enqueue-repro] done. Evidence: $runDir"
Write-Host "等待用户验收，尚未通过。请回复 pass / fail + 对象与原因。"
Write-Output $runDir
