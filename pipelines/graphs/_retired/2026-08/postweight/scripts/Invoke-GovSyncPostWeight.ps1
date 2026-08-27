#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook script for pipelines/graphs/govsync/postweight.
.DESCRIPTION
  POST GovSyncWeightPayload-shaped JSON to government inoutRecord/save.
  Marked experimental — not production code; do not copy into repos/.
  Script source is ASCII-only for Windows PowerShell 5.1 parse safety;
  Chinese wire values are embedded via [char] / Unicode escapes.
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

# Chinese wire / report strings (avoid non-ASCII in source file for PS 5.1)
$CarNoColorYellow = ([string][char]0x9EC4)              # Huang
$CarTypeHeavy = ([string][char]0x5927) + ([string][char]0x8F66)  # Da Che
$StatusWaiting = "Waiting for user acceptance; not passed."
$StatusWaitingZh = -join @(
    [char]0x7B49, [char]0x5F85, [char]0x7528, [char]0x6237, [char]0x9A8C, [char]0x6536, [char]0xFF0C,
    [char]0x5C1A, [char]0x672A, [char]0x901A, [char]0x8FC7, [char]0x3002
)

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-ConfigMap {
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
            if ($raw -match '^(.*?)\s+#') { $raw = $Matches[1].Trim() }
            if ($raw.StartsWith('"') -and $raw.EndsWith('"')) {
                $raw = $raw.Substring(1, $raw.Length - 2)
            }
            if ($section -ne "") {
                $map[$section][$key] = $raw
            }
            else {
                $map[$key] = $raw
            }
        }
    }
    return $map
}

function ConvertTo-JsonUtf8Literal {
    param([hashtable] $Object)
    # Build JSON manually so Chinese is UTF-8 literal (not \uXXXX) and snapImages stays an array.
    $carNo = [string]$Object.carNo
    $carNoColor = [string]$Object.carNoColor
    $buildLicenseNo = [string]$Object.buildLicenseNo
    $inOutType = [int]$Object.inOutType
    $grossWeight = $Object.grossWeight
    $tareWeight = $Object.tareWeight
    $snapTime = [string]$Object.snapTime
    $b64 = [string]$Object.snapImageB64
    $carType = [string]$Object.carType
    $deviceID = [string]$Object.deviceID
    $siteType = [string]$Object.siteType
    $goodsWeight = [string]$Object.goodsWeight
    $areaCode = [string]$Object.areaCode

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("{")
    [void]$sb.AppendLine(('  "carNo": "{0}",' -f $carNo))
    [void]$sb.AppendLine(('  "carNoColor": "{0}",' -f $carNoColor))
    [void]$sb.AppendLine(('  "buildLicenseNo": "{0}",' -f $buildLicenseNo))
    [void]$sb.AppendLine(('  "inOutType": {0},' -f $inOutType))
    [void]$sb.AppendLine(('  "grossWeight": {0},' -f $grossWeight))
    [void]$sb.AppendLine(('  "tareWeight": {0},' -f $tareWeight))
    [void]$sb.AppendLine(('  "snapTime": "{0}",' -f $snapTime))
    [void]$sb.AppendLine(('  "snapImages": ["{0}"],' -f $b64))
    [void]$sb.AppendLine(('  "carType": "{0}",' -f $carType))
    [void]$sb.AppendLine(('  "deviceID": "{0}",' -f $deviceID))
    [void]$sb.AppendLine(('  "siteType": "{0}",' -f $siteType))
    [void]$sb.AppendLine(('  "goodsWeight": "{0}",' -f $goodsWeight))
    [void]$sb.AppendLine(('  "areaCode": "{0}"' -f $areaCode))
    [void]$sb.Append("}")
    return $sb.ToString()
}

Write-Host "[govsync-postweight] experimental Invoke starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing config: $ConfigPath"
}
if (-not (Test-Path -LiteralPath $FixturePath)) {
    throw "Missing fixture image: $FixturePath"
}

$cfg = Get-ConfigMap
$url = [string]$cfg["target"]["url"]
$method = [string]$cfg["target"]["method"]
$carNo = [string]$cfg["scenario"]["carNo"]
# Prefer config; fall back to yellow plate label
$carNoColorCfg = [string]$cfg["scenario"]["carNoColor"]
$carNoColor = if ([string]::IsNullOrWhiteSpace($carNoColorCfg) -or $carNoColorCfg -eq "null") {
    $CarNoColorYellow
}
else {
    # config.yaml may already be UTF-8 Chinese; re-read via .NET UTF8 to be safe
    $carNoColorCfg
}
$buildLicenseNo = [string]$cfg["scenario"]["buildLicenseNo"]
$inOutType = [int]$cfg["scenario"]["inOutType"]
$grossWeight = [decimal]$cfg["scenario"]["grossWeightKg"]
$tareWeight = [decimal]$cfg["scenario"]["tareWeight"]
$carTypeCfg = [string]$cfg["scenario"]["carType"]
$carType = if ([string]::IsNullOrWhiteSpace($carTypeCfg)) { $CarTypeHeavy } else { $carTypeCfg }
$deviceID = [string]$cfg["scenario"]["deviceID"]
$siteType = [string]$cfg["scenario"]["siteType"]
$areaCode = [string]$cfg["scenario"]["areaCode"]
$environment = if ($cfg.ContainsKey("environment")) { [string]$cfg["environment"] } else { "local" }

if ([string]::IsNullOrWhiteSpace($url)) {
    throw "target.url missing in config.yaml"
}

# Re-read Chinese fields from config with explicit UTF-8 (PS Get-Content may mangle)
$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
if ($configText -match '(?m)^\s{2}carNo:\s*(\S+)') {
    $v = $Matches[1]
    if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
    $carNo = $v
}
if ($configText -match '(?m)^\s{2}carNoColor:\s*(\S+)') {
    $v = $Matches[1]
    if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
    if ($v -ne "null") { $carNoColor = $v }
}
if ($configText -match '(?m)^\s{2}carType:\s*(\S+)') {
    $v = $Matches[1]
    if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
    $carType = $v
}

if (-not $SkipConfirm) {
    if ($environment -ne "local") {
        $ans = Read-Host ("environment={0} (non-local). Type YES to continue" -f $environment)
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
$goodsWeight = ([string][int]$grossWeight)

$payloadJson = ConvertTo-JsonUtf8Literal -Object @{
    carNo          = $carNo
    carNoColor     = $carNoColor
    buildLicenseNo = $buildLicenseNo
    inOutType      = $inOutType
    grossWeight    = $grossWeight
    tareWeight     = $tareWeight
    snapTime       = $snapTime
    snapImageB64   = $b64
    carType        = $carType
    deviceID       = $deviceID
    siteType       = $siteType
    goodsWeight    = $goodsWeight
    areaCode       = $areaCode
}

$requestMeta = [ordered]@{
    method          = $method
    url             = $url
    contentType     = "application/json; charset=utf-8"
    snapTime        = $snapTime
    snapImagesCount = 1
    snapImagesBytes = $bytes.Length
    carNo           = $carNo
    buildLicenseNo  = $buildLicenseNo
    grossWeightKg   = $grossWeight
    carType         = $carType
    areaCode        = $areaCode
    fixture         = $FixtureRel
}
Write-Utf8NoBom -Path (Join-Path $HttpDir "request.meta.json") -Content ($requestMeta | ConvertTo-Json -Depth 5)

$redactedBody = ConvertTo-JsonUtf8Literal -Object @{
    carNo          = $carNo
    carNoColor     = $carNoColor
    buildLicenseNo = $buildLicenseNo
    inOutType      = $inOutType
    grossWeight    = $grossWeight
    tareWeight     = $tareWeight
    snapTime       = $snapTime
    snapImageB64   = ("[omitted base64; bytes={0}]" -f $bytes.Length)
    carType        = $carType
    deviceID       = $deviceID
    siteType       = $siteType
    goodsWeight    = $goodsWeight
    areaCode       = $areaCode
}
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
    if ([string]::IsNullOrWhiteSpace($respText)) {
        throw "Empty response body"
    }
    $obj = $respText | ConvertFrom-Json
    if ($null -eq $obj) {
        throw "JSON parsed to null"
    }
    $hasCode = $null -ne ($obj.PSObject.Properties["code"])
    $hasMsg = $null -ne ($obj.PSObject.Properties["msg"])
    if (-not ($hasCode -or $hasMsg)) {
        throw "JSON missing code/msg"
    }
    $jsonOk = $true
    if ($hasCode -and $null -ne $obj.code) { $bizCode = [int]$obj.code }
    if ($hasMsg -and $null -ne $obj.msg) { $bizMsg = [string]$obj.msg }
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ($obj | ConvertTo-Json -Depth 8)
}
catch {
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ("{0}`"source`":`"unparseable`",`"rawLength`":{1}{2}" -f "{", $respText.Length, "}")
}

$l0 = if ($null -ne $httpStatus) { "pass" } else { "fail" }
$l1 = if ($jsonOk) { "pass" } else { "fail" }
$l2 = if ($bizCode -eq 200) { "pass" } else { "fail" }

$summary = [ordered]@{
    slug         = "govsync-postweight"
    family       = "probe"
    runDir       = $RunDir
    url          = $url
    httpStatus   = $httpStatus
    elapsedMs    = $sw.ElapsedMilliseconds
    businessCode = $bizCode
    businessMsg  = $bizMsg
    snapTime     = $snapTime
    L0           = $l0
    L1           = $l1
    L2           = $l2
    L3           = "pending-user"
    error        = $errorText
    status       = $StatusWaitingZh
}
Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 5)

$reportLines = @(
    "# Report - govsync-postweight"
    ""
    ("Status: **{0}**" -f $StatusWaitingZh)
    ""
    "| Item | Value |"
    "|------|-------|"
    ("| run | ``{0}`` |" -f $RunDir)
    ("| url | {0} |" -f $url)
    ("| HTTP | {0} |" -f $httpStatus)
    ("| elapsedMs | {0} |" -f $sw.ElapsedMilliseconds)
    ("| snapTime | {0} |" -f $snapTime)
    ("| business code | {0} |" -f $bizCode)
    ("| business msg | {0} |" -f $bizMsg)
    ("| L0 | {0} |" -f $l0)
    ("| L1 | {0} |" -f $l1)
    ("| L2 | {0} |" -f $l2)
    "| L3 | pending-user |"
    ""
    "## Evidence"
    ""
    "- ``http/request.meta.json``"
    "- ``http/request.body.redacted.json``"
    "- ``http/response.raw.txt``"
    "- ``http/response.json``"
    "- ``summary.json``"
    ""
    "## Agent note"
    ""
    "Agent does not declare L3 pass. Please accept: pass / fail + object + reason."
)
Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content ($reportLines -join "`n")

$acceptanceLines = @(
    "# Acceptance - govsync-postweight (run copy)"
    ""
    "Status: **pending**"
    ""
    "| Item | Value |"
    "|------|-------|"
    ("| run | ``{0}`` |" -f $RunDir)
    ("| L0 | {0} |" -f $l0)
    ("| L1 | {0} |" -f $l1)
    ("| L2 | {0} |" -f $l2)
    "| L3 | pending-user |"
    "| object | |"
    "| reason | |"
)
Write-Utf8NoBom -Path (Join-Path $RunDir "acceptance.md") -Content ($acceptanceLines -join "`n")

Write-Host ("[govsync-postweight] done. runDir={0} http={1} code={2}" -f $RunDir, $httpStatus, $bizCode)
Write-Host "Please accept: pass / fail + object + reason."

if ($null -ne $errorText -and $null -eq $httpStatus) {
    exit 2
}
exit 0
