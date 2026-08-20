#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook script for pipelines/govsync-postweight.

.DESCRIPTION
  POST GovSyncWeightPayload-shaped JSON to government inoutRecord/save.
  Marked experimental — not production code; do not copy into repos/.

.PARAMETER RunDir
  Optional absolute path to an existing runs/<ts> directory.
  If omitted, creates pipelines/govsync-postweight/runs/<yyyy-MM-ddTHHmmss>/.

.PARAMETER SkipConfirm
  Skip interactive shared-environment / write-side-effect prompts (for Agent-driven runs that already passed human gates).
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$FixtureRel = "fixtures/test_pic.jpg"
$FixturePath = Join-Path $GraphRoot $FixtureRel

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-ConfigMap {
    # Minimal YAML subset reader for this Graph's known keys (no external module).
    $lines = Get-Content -LiteralPath $ConfigPath -Encoding UTF8
    $map = @{}
    $section = ""
    foreach ($line in $lines) {
        if ($line -match '^\s*#' -or $line.Trim() -eq "") { continue }
        if ($line -match '^([A-Za-z0-9_]+):\s*$') {
            $section = $Matches[1]
            if (-not $map.ContainsKey($section)) { $map[$section] = @{} }
            continue
        }
        if ($line -match '^\s{2}([A-Za-z0-9_]+):\s*(.+)$') {
            $key = $Matches[1]
            $raw = $Matches[2].Trim()
            # strip inline comments
            if ($raw -match '^(.*?)\s+#') { $raw = $Matches[1].Trim() }
            if ($raw.StartsWith('"') -and $raw.EndsWith('"')) {
                $raw = $raw.Substring(1, $raw.Length - 2)
            }
            if ($section -ne "") {
                $map[$section][$key] = $raw
            } else {
                $map[$key] = $raw
            }
        }
    }
    return $map
}

Write-Host "[govsync-postweight] experimental Invoke starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing config: $ConfigPath"
}
if (-not (Test-Path -LiteralPath $FixturePath)) {
    throw "Missing fixture image: $FixturePath"
}

$cfg = Get-ConfigMap
$url = $cfg["target"]["url"]
$method = $cfg["target"]["method"]
$carNo = $cfg["scenario"]["carNo"]
$carNoColor = $cfg["scenario"]["carNoColor"]
$buildLicenseNo = $cfg["scenario"]["buildLicenseNo"]
$inOutType = [int]$cfg["scenario"]["inOutType"]
$grossWeight = [decimal]$cfg["scenario"]["grossWeightKg"]
$tareWeight = [decimal]$cfg["scenario"]["tareWeight"]
$carType = $cfg["scenario"]["carType"]
$deviceID = $cfg["scenario"]["deviceID"]
$siteType = $cfg["scenario"]["siteType"]
$areaCode = $cfg["scenario"]["areaCode"]
$environment = if ($cfg.ContainsKey("environment")) { [string]$cfg["environment"] } else { "local" }

if ([string]::IsNullOrWhiteSpace($url)) {
    throw "target.url missing in config.yaml"
}

if (-not $SkipConfirm) {
    if ($environment -ne "local") {
        $ans = Read-Host "environment=$environment (non-local). Type YES to continue"
        if ($ans -ne "YES") { throw "Aborted at environment gate." }
    }
    $ans2 = Read-Host "POST save will WRITE to government platform. Type YES to continue"
    if ($ans2 -ne "YES") { throw "Aborted at destructive-write gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$HttpDir = Join-Path $RunDir "http"
New-Item -ItemType Directory -Force -Path $HttpDir | Out-Null

$snapTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$bytes = [System.IO.File]::ReadAllBytes($FixturePath)
$b64 = [Convert]::ToBase64String($bytes)

# Manual JSON (known shape) keeps Chinese labels as UTF-8 and snapImages as a real array.
$payloadJson = @"
{
  "carNo": "$carNo",
  "carNoColor": "$carNoColor",
  "buildLicenseNo": "$buildLicenseNo",
  "inOutType": $inOutType,
  "grossWeight": $grossWeight,
  "tareWeight": $tareWeight,
  "snapTime": "$snapTime",
  "snapImages": ["$b64"],
  "carType": "$carType",
  "deviceID": "$deviceID",
  "siteType": "$siteType",
  "goodsWeight": "$([string][int]$grossWeight)",
  "areaCode": "$areaCode"
}
"@

$requestMeta = [ordered]@{
    method           = $method
    url              = $url
    contentType      = "application/json; charset=utf-8"
    snapTime         = $snapTime
    snapImagesCount  = 1
    snapImagesBytes  = $bytes.Length
    carNo            = $carNo
    buildLicenseNo   = $buildLicenseNo
    grossWeightKg    = $grossWeight
    carType          = $carType
    areaCode         = $areaCode
    fixture          = $FixtureRel
}
$requestMetaJson = ($requestMeta | ConvertTo-Json -Depth 5)
Write-Utf8NoBom -Path (Join-Path $HttpDir "request.meta.json") -Content $requestMetaJson

# Redacted request body for evidence (no full base64)
$redactedBody = @"
{
  "carNo": "$carNo",
  "carNoColor": "$carNoColor",
  "buildLicenseNo": "$buildLicenseNo",
  "inOutType": $inOutType,
  "grossWeight": $grossWeight,
  "tareWeight": $tareWeight,
  "snapTime": "$snapTime",
  "snapImages": ["[omitted base64; bytes=$($bytes.Length)]"],
  "carType": "$carType",
  "deviceID": "$deviceID",
  "siteType": "$siteType",
  "goodsWeight": "$([string][int]$grossWeight)",
  "areaCode": "$areaCode"
}
"@
Write-Utf8NoBom -Path (Join-Path $HttpDir "request.body.redacted.json") -Content $redactedBody

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$httpStatus = $null
$respText = $null
$errorText = $null
try {
    $resp = Invoke-WebRequest -Uri $url -Method $method -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($payloadJson)) `
        -UseBasicParsing -TimeoutSec 120
    $httpStatus = [int]$resp.StatusCode
    $respText = $resp.Content
}
catch {
    $errorText = $_.Exception.Message
    if ($_.Exception.Response) {
        $httpStatus = [int]$_.Exception.Response.StatusCode
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $respText = $reader.ReadToEnd()
            $reader.Close()
        }
        catch { }
    }
}
$sw.Stop()

if ($null -eq $respText) { $respText = "" }
Write-Utf8NoBom -Path (Join-Path $HttpDir "response.raw.txt") -Content $respText

$bizCode = $null
$bizMsg = $null
$jsonOk = $false
try {
    $obj = $respText | ConvertFrom-Json
    $jsonOk = $true
    if ($null -ne $obj.code) { $bizCode = [int]$obj.code }
    if ($null -ne $obj.msg) { $bizMsg = [string]$obj.msg }
    ($obj | ConvertTo-Json -Depth 8) | ForEach-Object {
        Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content $_
    }
}
catch {
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content "{`"source`":`"unparseable`",`"rawLength`":$($respText.Length)}"
}

$l0 = if ($null -ne $httpStatus) { "pass" } else { "fail" }
$l1 = if ($jsonOk) { "pass" } else { "fail" }
$l2 = if ($bizCode -eq 200) { "pass" } else { "fail" }

$summary = [ordered]@{
    slug           = "govsync-postweight"
    family         = "probe"
    runDir         = $RunDir
    url            = $url
    httpStatus     = $httpStatus
    elapsedMs      = $sw.ElapsedMilliseconds
    businessCode   = $bizCode
    businessMsg    = $bizMsg
    snapTime       = $snapTime
    L0             = $l0
    L1             = $l1
    L2             = $l2
    L3             = "pending-user"
    error          = $errorText
    status         = "等待用户验收，尚未通过。"
}
$summaryJson = ($summary | ConvertTo-Json -Depth 5)
Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content $summaryJson

$report = @"
# Report — govsync-postweight

Status: **等待用户验收，尚未通过。**

| 项 | 值 |
|----|-----|
| run | ``$RunDir`` |
| url | $url |
| HTTP | $httpStatus |
| elapsedMs | $($sw.ElapsedMilliseconds) |
| snapTime | $snapTime |
| business code | $bizCode |
| business msg | $bizMsg |
| L0 | $l0 |
| L1 | $l1 |
| L2 | $l2 |
| L3 | pending（仅用户） |

## Evidence

- ``http/request.meta.json``
- ``http/request.body.redacted.json``
- ``http/response.raw.txt``
- ``http/response.json``
- ``summary.json``

## Agent note

Agent 不宣布 L3 通过。请验收：``pass`` / ``fail`` + 对象与原因。
"@
Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content $report

$acceptance = @"
# Acceptance — govsync-postweight (run copy)

Status: **pending**

| 项 | 值 |
|----|-----|
| run | ``$RunDir`` |
| L0 | $l0 |
| L1 | $l1 |
| L2 | $l2 |
| L3 | pending（仅用户） |
| 对象 | |
| 原因 | |
"@
Write-Utf8NoBom -Path (Join-Path $RunDir "acceptance.md") -Content $acceptance

Write-Host "[govsync-postweight] done. runDir=$RunDir http=$httpStatus code=$bizCode"
Write-Host "请验收：pass / fail + 对象与原因。"

if ($null -ne $errorText -and $null -eq $httpStatus) {
    exit 2
}
exit 0
