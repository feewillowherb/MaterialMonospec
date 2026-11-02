#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: SolidWaste October xlsx export including soft-deleted masters.
  Read-only DB. Does NOT modify business code.
#>
[CmdletBinding()]
param(
    [string] $DatabasePath = "",
    [string] $RunDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsLocal = Join-Path $GraphRoot "secrets.local.yaml"
$ToolPath = Join-Path $GraphRoot "scripts\export-solidwaste-october.ts"
$PipelinesRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..")).Path
$OutLatest = Join-Path $GraphRoot "out\latest"

function Get-YamlScalar {
    param([string] $Text, [string] $Key, [int] $Indent = 0)
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

Write-Host "[solidwaste-oct-export-include-softdelete] starting (read-only)..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
if (-not (Test-Path -LiteralPath $ToolPath)) { throw "Missing tool: $ToolPath" }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$dbHint = Get-YamlScalar -Text $configText -Key "databaseAbsHint" -Indent 2
$startDate = Get-YamlScalar -Text $configText -Key "startDate" -Indent 2
$endInclusive = Get-YamlScalar -Text $configText -Key "endDateInclusive" -Indent 2
$weighingMode = Get-YamlScalar -Text $configText -Key "weighingMode" -Indent 2
$orderType = Get-YamlScalar -Text $configText -Key "orderTypeCompleted" -Indent 2
$defaultShipper = Get-YamlScalar -Text $configText -Key "defaultShipper" -Indent 2
$outputFileName = Get-YamlScalar -Text $configText -Key "outputFileName" -Indent 2
$sheetName = Get-YamlScalar -Text $configText -Key "sheetName" -Indent 2

$db = $DatabasePath
if ([string]::IsNullOrWhiteSpace($db) -and (Test-Path -LiteralPath $SecretsLocal)) {
    $secretsText = [System.IO.File]::ReadAllText($SecretsLocal, [System.Text.Encoding]::UTF8)
    $db = Get-YamlScalar -Text $secretsText -Key "databaseAbs" -Indent 0
}
if ([string]::IsNullOrWhiteSpace($db)) { $db = $dbHint }
if ([string]::IsNullOrWhiteSpace($db)) {
    throw "Missing database path. Set secrets.local.yaml databaseAbs or pass -DatabasePath."
}
if (-not (Test-Path -LiteralPath $db)) { throw "Database not found: $db" }

# EndDate inclusive → exclusive upper bound (+1 day), same as GetEffectiveEndDate
if ([string]::IsNullOrWhiteSpace($startDate)) { $startDate = "2026-10-01" }
if ([string]::IsNullOrWhiteSpace($endInclusive)) { $endInclusive = "2026-10-31" }
$endExclusive = ([datetime]::ParseExact($endInclusive, "yyyy-MM-dd", $null)).AddDays(1).ToString("yyyy-MM-dd")

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path $GraphRoot "runs\$stamp"
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutLatest | Out-Null

Push-Location $PipelinesRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $PipelinesRoot "node_modules\tsx"))) {
        Write-Host "[solidwaste-oct-export-include-softdelete] pnpm install..."
        pnpm install
        if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $PipelinesRoot "node_modules\exceljs\package.json"))) {
        Write-Host "[solidwaste-oct-export-include-softdelete] pnpm install (exceljs)..."
        pnpm install
        if ($LASTEXITCODE -ne 0) { throw "pnpm install failed (exceljs)" }
    }

    Write-Host "[solidwaste-oct-export-include-softdelete] database=$db"
    Write-Host "[solidwaste-oct-export-include-softdelete] range=[$startDate, $endExclusive)"
    Write-Host "[solidwaste-oct-export-include-softdelete] runDir=$RunDir"

    $nodeArgs = @(
        "exec", "tsx", $ToolPath,
        "--database", $db,
        "--runDir", $RunDir,
        "--outLatest", $OutLatest,
        "--startDate", $startDate,
        "--endExclusive", $endExclusive,
        "--weighingMode", $(if ($weighingMode) { $weighingMode } else { "1" }),
        "--orderType", $(if ($orderType) { $orderType } else { "1" }),
        "--defaultShipper", $(if ($defaultShipper) { $defaultShipper } else { "东部资源化处置点" }),
        "--outputFileName", $(if ($outputFileName) { $outputFileName } else { "solidwaste-export-2026-10-include-softdelete.xlsx" }),
        "--sheetName", $(if ($sheetName) { $sheetName } else { "Sheet1" })
    )
    & pnpm @nodeArgs
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($code -ne 0) { throw "export-solidwaste-october.ts exited $code" }

Write-Host "[solidwaste-oct-export-include-softdelete] done. Evidence: $RunDir"
Write-Host "便捷副本: $OutLatest"
Write-Host "等待用户验收，尚未通过。请回复 pass / fail + 对象与原因。"
exit $code
