#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: Recycle FEV for LPR photo, test plate, ascent, and departure.

.DESCRIPTION
  Drives /api/lpr/test-plate and /api/scale/weight on the Recycle diagnostic host.
  Does NOT modify MaterialClient.db, appsettings, ScaleType, or EnableTriggerLprCapture.
  Does NOT send an image with the test plate.
  Does NOT accept or store an activation code.
  Does NOT stop MaterialClient.Recycle.exe when the cook finishes.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-recycle-weigh-cycle/scripts/Invoke-FevRecycleWeighCycle.ps1
#>
[CmdletBinding()]
param(
    [switch] $NoStart,
    [switch] $NoBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsLocal = Join-Path $GraphRoot "secrets.local.yaml"
$ToolPath = Join-Path $GraphRoot "scripts\probe-fev-recycle-weigh-cycle.ts"
$FixturePath = Join-Path $GraphRoot "fixtures\scenario.json"
$StartScript = Join-Path $RepoRoot "scripts\MaterialClient\Start-MaterialClient.Recycle.ps1"

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

Write-Host "[fev-recycle-weigh-cycle] starting..."

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

if (-not $NoStart) {
    if (-not (Test-Path -LiteralPath $StartScript)) { throw "Missing start script: $StartScript" }
    Write-Host "[fev-recycle-weigh-cycle] starting MaterialClient.Recycle; it stays open after this cook"
    $startArgs = @("-ExecutionPolicy", "Bypass", "-File", $StartScript, "-StopRunning")
    if ($NoBuild) { $startArgs += "-NoBuild" }
    & powershell @startArgs
    if ($LASTEXITCODE -ne 0) { throw "Start-MaterialClient.Recycle.ps1 failed: $LASTEXITCODE" }
}

Write-Host "[fev-recycle-weigh-cycle] waiting for diagnostic $baseUrl"
$ready = $false
for ($i = 1; $i -le 90; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri ($baseUrl.TrimEnd('/') + '/') -UseBasicParsing -TimeoutSec 2
        if ($resp.StatusCode -eq 200) { $ready = $true; break }
    } catch {
        if (($i % 5) -eq 0) {
            $alive = @(Get-Process -Name "MaterialClient.Recycle" -ErrorAction SilentlyContinue)
            Write-Host "[fev-recycle-weigh-cycle] still waiting ($i/90) processCount=$($alive.Count)"
        }
        Start-Sleep -Seconds 2
    }
}
if (-not $ready) {
    throw "Diagnostic host not ready at $baseUrl. The Recycle process is left running. If an activation window is open, the user enters the code."
}

if (-not (Test-Path -LiteralPath $database)) {
    throw "Local Recycle database was not found at $databaseRel. The client is left running."
}

$code = 1
Push-Location $PipelinesRoot
try {
    $tsxOk = $false
    $null = & pnpm exec tsx --version 2>$null
    if ($LASTEXITCODE -eq 0) { $tsxOk = $true }
    if (-not $tsxOk) {
        Write-Host "[fev-recycle-weigh-cycle] pnpm install (tsx)..."
        & pnpm install
        if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }
    }
    Write-Host "[fev-recycle-weigh-cycle] baseUrl=$baseUrl"
    Write-Host "[fev-recycle-weigh-cycle] runDir=$runDir"
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

$aliveAfter = @(Get-Process -Name "MaterialClient.Recycle" -ErrorAction SilentlyContinue)
Write-Host "[fev-recycle-weigh-cycle] client process count after cook: $($aliveAfter.Count)"
Write-Host "[fev-recycle-weigh-cycle] evidence: $runDir"
if ($code -ne 0) {
    throw "probe-fev-recycle-weigh-cycle.ts exited $code. The Recycle client was not closed. Evidence: $runDir"
}

Write-Host "[fev-recycle-weigh-cycle] done. Recycle client left running."
Write-Output $runDir
