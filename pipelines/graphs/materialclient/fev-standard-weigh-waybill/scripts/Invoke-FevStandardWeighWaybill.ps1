#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: Standard FEV for a Waybill from test-plate and two test-scale weights.

.DESCRIPTION
  Drives /api/lpr/test-plate and /api/scale/weight on the Standard diagnostic host.
  Does NOT modify MaterialClient.db, appsettings, ScaleType, or DataDirectory.
  Does NOT accept or store an activation code. The user types that in the window.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Standard.ps1 -EnableDiagnosticHost -StopRunning
  powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-standard-weigh-waybill/scripts/Invoke-FevStandardWeighWaybill.ps1
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
$ToolPath = Join-Path $RepoRoot "pipelines\graphs\materialclient\fev-solidwaste-weigh-lpr\scripts\probe-fev-solidwaste-weigh-lpr.ts"
$FixturePath = Join-Path $GraphRoot "fixtures\scenario.json"
$StartScript = Join-Path $RepoRoot "scripts\MaterialClient\Start-MaterialClient.Standard.ps1"

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

Write-Host "[fev-standard-weigh-waybill] starting..."

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
    Write-Host "[fev-standard-weigh-waybill] starting MaterialClient (no DB/appsettings changes)"
    $startArgs = @("-ExecutionPolicy", "Bypass", "-File", $StartScript, "-EnableDiagnosticHost", "-StopRunning")
    if ($NoBuild) { $startArgs += "-NoBuild" }
    & powershell @startArgs
    if ($LASTEXITCODE -ne 0) { throw "Start-MaterialClient.Standard.ps1 failed: $LASTEXITCODE" }
}

Write-Host "[fev-standard-weigh-waybill] waiting for diagnostic $baseUrl"
$ready = $false
for ($i = 1; $i -le 60; $i++) {
    $alive = @(Get-Process -Name "MaterialClient" -ErrorAction SilentlyContinue)
    if ($alive.Count -eq 0 -and $StartHost) {
        throw "MaterialClient.exe exited before diagnostic host was ready at $baseUrl. If the activation window was closed, ask the user for the code and start again."
    }
    try {
        $resp = Invoke-WebRequest -Uri ($baseUrl.TrimEnd('/') + '/') -UseBasicParsing -TimeoutSec 2
        if ($resp.StatusCode -eq 200) { $ready = $true; break }
    } catch {
        if (($i % 5) -eq 0) {
            Write-Host "[fev-standard-weigh-waybill] still waiting ($i/60) processCount=$($alive.Count)"
        }
        Start-Sleep -Seconds 2
    }
}
if (-not $ready) {
    throw "Diagnostic host not ready at $baseUrl. Start with -EnableDiagnosticHost. User enters the activation code if prompted, then logs in and opens weighing."
}

if (-not (Test-Path -LiteralPath $database)) {
    throw "Local Standard database was not found at $databaseRel."
}

$code = 1
Push-Location $PipelinesRoot
try {
    $tsxOk = $false
    $null = & pnpm exec tsx --version 2>$null
    if ($LASTEXITCODE -eq 0) { $tsxOk = $true }
    if (-not $tsxOk) {
        Write-Host "[fev-standard-weigh-waybill] pnpm install (tsx)..."
        & pnpm install
        if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }
    }
    Write-Host "[fev-standard-weigh-waybill] baseUrl=$baseUrl"
    Write-Host "[fev-standard-weigh-waybill] runDir=$runDir"
    & pnpm exec tsx $ToolPath `
        --run $runDir `
        --baseUrl $baseUrl `
        --database $database `
        --log $logRoot `
        --fixture $FixturePath `
        --repo $RepoRoot `
        --graphId "fev-standard-weigh-waybill" `
        --graphPath "pipelines/graphs/materialclient/fev-standard-weigh-waybill" `
        --hostLabel "Standard"
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($code -ne 0) {
    throw "probe exited $code (2 means diagnostic host, test mode, activation, or weighing window is not ready). Evidence: $runDir"
}

Write-Host "[fev-standard-weigh-waybill] done. Evidence: $runDir"
Write-Host "等待用户验收，尚未通过。请回复 pass / fail + 对象与原因。"
Write-Output $runDir
