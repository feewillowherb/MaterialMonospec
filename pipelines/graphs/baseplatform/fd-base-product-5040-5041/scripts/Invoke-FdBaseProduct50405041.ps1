# experimental
# Emits SQL artifacts only. Does not connect to or write any database.
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$ConfigPath = Join-Path $GraphRoot 'config.yaml'
$SqlSourcePath = Join-Path $GraphRoot 'sql\upsert-jc-product-5040-5041.sql'
$RunId = Get-Date -Format 'yyyy-MM-ddTHHmmss'
$RunDir = Join-Path $GraphRoot (Join-Path 'runs' $RunId)

function Write-Utf8([string] $Path, [string] $Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Read-YamlScalar([string] $Text, [string] $Key) {
    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + ':\s*"?([^"#\r\n]+?)"?\s*$'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim()
}

$summary = [ordered]@{
    graphId       = 'fd-base-product-5040-5041'
    graphPath     = 'pipelines/graphs/baseplatform/fd-base-product-5040-5041'
    runId         = $RunId
    result        = 'unknown'
    connected     = $false
    applied       = $false
    sqlBytes      = 0
    sqlSink       = 'prepare/upsert-jc-product-5040-5041.sql'
    intendedHost  = '129'
    intendedDb    = 'FD_Base'
    message       = $null
}

try {
    if (Test-Path -LiteralPath $RunDir) { throw "Run directory already exists: $RunId" }
    New-Item -ItemType Directory -Path (Join-Path $RunDir 'prepare') | Out-Null

    if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
    if (-not (Test-Path -LiteralPath $SqlSourcePath)) { throw "Missing SQL source: $SqlSourcePath" }

    $configText = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
    $family = Read-YamlScalar $configText 'family'
    if ($family -ne 'transform') { throw 'graph.family must be transform.' }
    $sqlText = Get-Content -LiteralPath $SqlSourcePath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($sqlText)) { throw 'SQL source is empty.' }
    foreach ($needle in @('5040', '5041', '萧山城管管理平台', '萧山资源化利用网页端')) {
        if ($sqlText -notlike "*$needle*") {
            throw "SQL source is missing required token: $needle"
        }
    }
    if ($sqlText -match "(?m)ProductCode\s*=\s*N'5020'") {
        throw 'SQL source must not query ProductCode 5020 at runtime.'
    }
    if ($sqlText -notmatch '(?i)INSERT\s+INTO\s+dbo\.JC_Product') {
        throw 'SQL source does not contain INSERT INTO dbo.JC_Product.'
    }

    $sqlSink = Join-Path $RunDir 'prepare\upsert-jc-product-5040-5041.sql'
    Write-Utf8 $sqlSink $sqlText
    $summary.sqlBytes = [System.Text.Encoding]::UTF8.GetByteCount($sqlText)

    $planDoc = [ordered]@{
        connected    = $false
        applied      = $false
        mode         = 'emit-sql-only'
        intendedHost = '129'
        intendedDb   = 'FD_Base'
        sqlSource    = 'sql/upsert-jc-product-5040-5041.sql'
        sqlSink      = 'prepare/upsert-jc-product-5040-5041.sql'
        products     = @(
            [ordered]@{ productCode = 5040; productName = '萧山城管管理平台' }
            [ordered]@{ productCode = 5041; productName = '萧山资源化利用网页端' }
        )
    }
    Write-Utf8 (Join-Path $RunDir 'prepare\plan.json') ($planDoc | ConvertTo-Json -Depth 6)

    $summary.result = 'pass'
    $summary.message = 'SQL emitted. Cook did not connect to or write any database.'
}
catch {
    $summary.result = 'fail'
    $summary.message = [string]$_.Exception.Message
}
finally {
    Write-Utf8 (Join-Path $RunDir 'summary.json') ($summary | ConvertTo-Json -Depth 6)
    $report = @(
        '# fd-base-product-5040-5041'
        ''
        "- runId: ``$RunId``"
        "- result: ``$($summary.result)``"
        "- connected: ``$($summary.connected)``"
        "- applied: ``$($summary.applied)``"
        "- sqlBytes: ``$($summary.sqlBytes)``"
        "- sql: ``$($summary.sqlSink)``"
        "- intended: ``$($summary.intendedHost)/$($summary.intendedDb)``"
        "- message: $($summary.message)"
        ''
        'Apply the SQL on 129 manually if accepted. P3 stays with the user.'
    ) -join "`r`n"
    Write-Utf8 (Join-Path $RunDir 'report.md') ($report + "`r`n")
    $rev = ''
    try { $rev = (& git -C $RepoRoot rev-parse --short HEAD) } catch { $rev = '' }
    $manifest = @"
graphId: $($summary.graphId)
graphPath: $($summary.graphPath)
runId: $RunId
result: $($summary.result)
gitRevision: "$rev"
contractPath: pipelines/graphs/baseplatform/fd-base-product-5040-5041/contract.yaml
artifacts:
  - prepare/upsert-jc-product-5040-5041.sql
  - prepare/plan.json
  - summary.json
  - report.md
  - manifest.yaml
"@
    Write-Utf8 (Join-Path $RunDir 'manifest.yaml') $manifest
}

if ($summary.result -ne 'pass') {
    Write-Error $summary.message
    exit 1
}

Write-Output "result=$($summary.result) sql=$($summary.sqlSink) bytes=$($summary.sqlBytes) runId=$RunId"
exit 0
