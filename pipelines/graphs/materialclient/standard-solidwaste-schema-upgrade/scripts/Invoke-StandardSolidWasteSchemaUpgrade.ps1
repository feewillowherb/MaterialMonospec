#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental probe: copy _tmp/1110/MaterialClient.db and verify the Standard/SolidWaste schema upgrade with the Node cook.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [string] $SourceDb = "",
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$ToolPath = Join-Path $PSScriptRoot "upgrade-verify.ts"

function Get-YamlScalar {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*{0}\s*:\s*(.+)\s*$" -f [regex]::Escape($Key)
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }
    return ($match.Groups[1].Value.Trim().Trim('"').Trim("'"))
}

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing cook: $ToolPath" }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$sourceRel = Get-YamlScalar -Text $configText -Key "sourceDb"
if ([string]::IsNullOrWhiteSpace($sourceRel)) { throw "config.yaml is missing sourceDb" }

$secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
if (Test-Path -LiteralPath $secretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
    $fromSecrets = Get-YamlScalar -Text $secretsText -Key "sourceDb"
    if (-not [string]::IsNullOrWhiteSpace($fromSecrets)) { $sourceRel = $fromSecrets }
    if ((Get-YamlScalar -Text $secretsText -Key "skipConfirm") -eq "true") { $SkipConfirm = $true }
}
if (-not [string]::IsNullOrWhiteSpace($SourceDb)) { $sourceRel = $SourceDb }

$sourcePath = if ([System.IO.Path]::IsPathRooted($sourceRel)) { $sourceRel } else { Join-Path $RepoRoot $sourceRel }
if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Missing source DB (human gate missing-source-db): $sourcePath"
}

if (-not $SkipConfirm) {
    $answer = Read-Host "Will COPY the sample to runs/<ts>/working only and verify there. Type YES to continue"
    if ($answer -ne "YES") { throw "Aborted at human gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

Push-Location $PipelinesRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $PipelinesRoot "node_modules\tsx"))) {
        Write-Host "pnpm install in pipelines/..."
        pnpm install
    }
    & pnpm exec tsx $ToolPath --repoRoot $RepoRoot --runDir $RunDir --config $ConfigPath
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

$runId = Split-Path -Leaf $RunDir
$manifest = @"
graphId: standard-solidwaste-schema-upgrade
graphPath: pipelines/graphs/materialclient/standard-solidwaste-schema-upgrade
runId: $runId
result: unknown
contractPath: pipelines/graphs/materialclient/standard-solidwaste-schema-upgrade/contract.yaml
artifacts:
  - prepare/pre-schema.json
  - schema/post-schema.json
  - summary.json
  - report.md
"@
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $RunDir "manifest.yaml"), $manifest, $utf8)

if (Test-Path -LiteralPath (Join-Path $RunDir "summary.json")) {
    $summary = Get-Content -LiteralPath (Join-Path $RunDir "summary.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest = $manifest.Replace("result: unknown", "result: $($summary.result)")
    [System.IO.File]::WriteAllText((Join-Path $RunDir "manifest.yaml"), $manifest, $utf8)
}

Write-Host "[standard-solidwaste-schema-upgrade] runId=$runId exit=$exitCode"
exit $exitCode
