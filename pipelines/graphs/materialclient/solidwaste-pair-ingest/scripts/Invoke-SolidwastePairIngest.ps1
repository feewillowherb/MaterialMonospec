#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: solidwaste missing-join pair ingest (Node/TS + node:sqlite).
#>
[CmdletBinding()]
param(
    [switch] $Write,
    [switch] $SkipConfirm,
    [string] $RunDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$ToolRel = "scripts/ingest-pair.ts"
$ToolPath = Join-Path $GraphRoot $ToolRel
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..")).Path

function Get-YamlScalar {
    param([string] $Text, [string] $Key, [int] $Indent = 2)
    $pad = " " * $Indent
    $pattern = '(?m)^' + [regex]::Escape($pad) + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        if ($v.StartsWith('"') -and $v.EndsWith('"')) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        if ($v.StartsWith("'") -and $v.EndsWith("'")) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        return $v
    }
    return $null
}

function Resolve-RepoPath {
    param([string] $RelOrAbs)
    if ([string]::IsNullOrWhiteSpace($RelOrAbs)) { return $null }
    if ([System.IO.Path]::IsPathRooted($RelOrAbs)) { return $RelOrAbs }
    $fromGraph = Join-Path $GraphRoot $RelOrAbs
    if (Test-Path -LiteralPath $fromGraph) { return (Resolve-Path -LiteralPath $fromGraph).Path }
    $fromRepo = Join-Path $RepoRoot $RelOrAbs
    return $fromRepo
}

Write-Host "[solidwaste-pair-ingest] starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing tool: $ToolPath" }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$dbRel = Get-YamlScalar -Text $configText -Key "databaseRel"
$sourceRel = Get-YamlScalar -Text $configText -Key "sourceDirRel"
$photoRel = Get-YamlScalar -Text $configText -Key "photoRootRel"
$dryRunYaml = Get-YamlScalar -Text $configText -Key "dryRun"
$plate = Get-YamlScalar -Text $configText -Key "plateNumber"
$joinWeight = Get-YamlScalar -Text $configText -Key "joinWeightTon"
$outWeight = Get-YamlScalar -Text $configText -Key "outWeightTon"
$netWeight = Get-YamlScalar -Text $configText -Key "netWeightTon"
$joinTime = Get-YamlScalar -Text $configText -Key "joinTime"
$outRecordId = Get-YamlScalar -Text $configText -Key "outRecordId"
$deliveryType = Get-YamlScalar -Text $configText -Key "deliveryType"
$weighingMode = Get-YamlScalar -Text $configText -Key "weighingMode"
$orderSource = Get-YamlScalar -Text $configText -Key "orderSource"
$orderType = Get-YamlScalar -Text $configText -Key "orderType"
$isPendingSync = Get-YamlScalar -Text $configText -Key "isPendingSync"

$databasePath = Resolve-RepoPath $dbRel
$sourceDir = Resolve-RepoPath $sourceRel
$photoRoot = Resolve-RepoPath $photoRel

if (-not (Test-Path -LiteralPath $databasePath)) {
    throw "Missing database: $databasePath (copy into seeds/; see seeds/README.md)"
}
if (-not (Test-Path -LiteralPath $sourceDir)) {
    throw "Missing sourceDir: $sourceDir"
}

$willWrite = $Write.IsPresent -or ($dryRunYaml -eq "false")
if ($willWrite -and -not $SkipConfirm) {
    Write-Host "WARNING: Will WRITE into $databasePath and copy photos under $photoRoot\PhotoJianKong" -ForegroundColor Yellow
    $ans = Read-Host "Type YES to continue"
    if ($ans -ne "YES") { throw "Aborted at write gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$manifestPath = Join-Path $sourceDir "image-manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing image-manifest.json in seeds (GUID file list)."
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$imageFiles = @($manifest | ForEach-Object {
    ("PhotoJianKong/2026/09/01/" + $_.FileName)
})

$scenario = [ordered]@{
    plateNumber    = $plate
    joinWeightTon  = $joinWeight
    outWeightTon   = $outWeight
    netWeightTon   = $netWeight
    joinTime       = $joinTime
    outRecordId    = [int]$outRecordId
    deliveryType   = [int]$deliveryType
    weighingMode   = [int]$weighingMode
    orderSource    = [int]$orderSource
    orderType      = [int]$orderType
    isPendingSync  = ($isPendingSync -eq "true")
    photoRelDir    = "PhotoJianKong\2026\09\01"
    imageFiles     = $imageFiles
    dryRun         = (-not $willWrite)
}
$scenarioPath = Join-Path $RunDir "scenario.json"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($scenarioPath, ($scenario | ConvertTo-Json -Depth 5), $utf8)

Push-Location $PipelinesRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $PipelinesRoot "node_modules\tsx"))) {
        Write-Host "pnpm install in pipelines/..."
        pnpm install
    }
    $nodeArgs = @(
        "exec", "tsx", $ToolPath,
        "--database", $databasePath,
        "--sourceDir", $sourceDir,
        "--photoRoot", $photoRoot,
        "--runDir", $RunDir,
        "--scenarioJson", $scenarioPath
    )
    if ($willWrite) { $nodeArgs += "--write" }
    & pnpm @nodeArgs
    $rc = $LASTEXITCODE
}
finally {
    Pop-Location
}

Write-Host "[solidwaste-pair-ingest] done. runDir=$RunDir exit=$rc"
Write-Host "Please accept: pass / fail + object + reason."
exit $rc
