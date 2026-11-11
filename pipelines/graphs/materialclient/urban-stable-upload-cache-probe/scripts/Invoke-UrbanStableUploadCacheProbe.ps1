# experimental
<#
.SYNOPSIS
  Probe a running MaterialClient.Urban for stable-upload cache behavior.

.DESCRIPTION
  Requires the Urban process already started with -EnableDiagnosticHost.
  Reads the local SQLite file and new log lines. Does not delete rows.
  Restores the settings document fetched at the start.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/urban-stable-upload-cache-probe/scripts/Invoke-UrbanStableUploadCacheProbe.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/urban-stable-upload-cache-probe/scripts/Invoke-UrbanStableUploadCacheProbe.ps1 -IncludeFallback
#>
[CmdletBinding()]
param(
    [switch] $IncludeFallback
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsLocal = Join-Path $GraphRoot "secrets.local.yaml"
$ToolPath = Join-Path $GraphRoot "scripts\probe-stable-upload.ts"

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
$fixture = Join-Path $GraphRoot "fixtures\scenarios.json"

if (-not (Test-Path -LiteralPath $database)) {
    throw "Local Urban database was not found at $databaseRel. Start MaterialClient.Urban once so MaterialClient.db exists."
}

$stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
$runDir = Join-Path $GraphRoot "runs\$stamp"
if (Test-Path -LiteralPath $runDir) { throw "Run directory already exists: $stamp" }
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$code = 1
Push-Location $PipelinesRoot
try {
    $tsxOk = $false
    $null = & pnpm exec tsx --version 2>$null
    if ($LASTEXITCODE -eq 0) { $tsxOk = $true }
    if (-not $tsxOk) {
        Write-Host "[urban-stable-upload-cache-probe] pnpm install (tsx)..."
        & pnpm install
        if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }
    }
    $tsxArgs = @(
        $ToolPath,
        "--run", $runDir,
        "--baseUrl", $baseUrl,
        "--database", $database,
        "--log", $logRoot,
        "--fixture", $fixture,
        "--repo", $RepoRoot
    )
    if ($IncludeFallback) { $tsxArgs += "--include-fallback" }
    & pnpm exec tsx @tsxArgs
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

Write-Host "pipelines/graphs/materialclient/urban-stable-upload-cache-probe/runs/$stamp"
if ($code -ne 0) {
    throw "urban-stable-upload-cache-probe exited $code (2 means the diagnostic host or database was not ready)"
}
