#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: export wenyixilu MaterialClient.db weighing + attachments to CSV
  with photo path resolution under 2026/.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [string] $SourceDb = "",
    [string] $PhotoRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsPath = Join-Path $GraphRoot "secrets.local.yaml"
$ToolPath = Join-Path $GraphRoot "scripts\export-csv.mjs"

function Get-YamlScalar {
    param([string] $Text, [string] $Key, [int] $Indent = 0)
    if ($Indent -gt 0) {
        $pad = " " * $Indent
        $pattern = '(?m)^' + [regex]::Escape($pad) + [regex]::Escape($Key) + ':\s*(.+)$'
    }
    else {
        $pattern = '(?m)^' + [regex]::Escape($Key) + ':\s*(.+)$'
    }
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        if ($v.StartsWith("'") -and $v.EndsWith("'")) {
            return $v.Substring(1, $v.Length - 2)
        }
        if ($v.StartsWith('"') -and $v.EndsWith('"')) {
            $v = $v.Substring(1, $v.Length - 2)
            $v = $v.Replace('\\', '\')
            return $v
        }
        return $v
    }
    return $null
}

Write-Host "[recycle-wenyixilu-export] starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing tool: $ToolPath" }

$secretsText = ""
if (Test-Path -LiteralPath $SecretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($SecretsPath, [System.Text.Encoding]::UTF8)
}

if ([string]::IsNullOrWhiteSpace($SourceDb)) {
    $SourceDb = Get-YamlScalar -Text $secretsText -Key "sourceDb"
}
if ([string]::IsNullOrWhiteSpace($PhotoRoot)) {
    $PhotoRoot = Get-YamlScalar -Text $secretsText -Key "photoRoot"
}

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
if ([string]::IsNullOrWhiteSpace($SourceDb)) {
    $SourceDb = Get-YamlScalar -Text $configText -Key "sourceDb" -Indent 2
}
if ([string]::IsNullOrWhiteSpace($PhotoRoot)) {
    $PhotoRoot = Get-YamlScalar -Text $configText -Key "photoRoot" -Indent 2
}

if ([string]::IsNullOrWhiteSpace($SourceDb)) {
    throw "Missing sourceDb. Set secrets.local.yaml or pass -SourceDb."
}
if ([string]::IsNullOrWhiteSpace($PhotoRoot)) {
    throw "Missing photoRoot. Set secrets.local.yaml or pass -PhotoRoot."
}
if (-not (Test-Path -LiteralPath $SourceDb)) {
    throw "sourceDb not found: $SourceDb"
}
if (-not (Test-Path -LiteralPath $PhotoRoot)) {
    throw "photoRoot not found: $PhotoRoot"
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path $GraphRoot "runs\$stamp"
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$prepareDir = Join-Path $RunDir "prepare"
New-Item -ItemType Directory -Force -Path $prepareDir | Out-Null

$workDb = Join-Path $prepareDir "MaterialClient.db"
Copy-Item -LiteralPath $SourceDb -Destination $workDb -Force
Write-Host "[bind] copied DB -> $workDb"
Write-Host "[bind] photoRoot = $PhotoRoot"

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw "Node.js not found on PATH (need 22.5+)." }

& node $ToolPath --db $workDb --photoRoot $PhotoRoot --outDir $RunDir
if ($LASTEXITCODE -ne 0) {
    throw "export-csv.mjs failed with exit $LASTEXITCODE"
}

$outLatest = Join-Path $GraphRoot "out\latest"
if (Test-Path -LiteralPath $outLatest) {
    Remove-Item -LiteralPath $outLatest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outLatest | Out-Null
Copy-Item -LiteralPath (Join-Path $RunDir "csv") -Destination (Join-Path $outLatest "csv") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RunDir "photo-resolve-report.json") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "summary.json") -Destination $outLatest -Force
Copy-Item -LiteralPath (Join-Path $RunDir "report.md") -Destination $outLatest -Force

Write-Host "[done] runDir=$RunDir"
Write-Host "[done] mirrored -> $outLatest"
Write-Host "Gate: reply pass / fail + object + reason."