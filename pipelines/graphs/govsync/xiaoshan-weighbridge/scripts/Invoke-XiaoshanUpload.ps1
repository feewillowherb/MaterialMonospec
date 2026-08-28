#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: Xiaoshan weighbridge / gate / product POST probe.
.DESCRIPTION
  Reads graph config.yaml (scenario.channel) and POSTs the matching payload.
  ASCII-only source for Windows PowerShell 5.1; Chinese via [char] / UTF-8 config.
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

$CarNoColorYellow = ([string][char]0x9EC4)
$CarTypeHeavy = ([string][char]0x5927) + ([string][char]0x8F66)
$StatusWaitingZh = -join @(
    [char]0x7B49, [char]0x5F85, [char]0x7528, [char]0x6237, [char]0x9A8C, [char]0x6536, [char]0xFF0C,
    [char]0x5C1A, [char]0x672A, [char]0x901A, [char]0x8FC7, [char]0x3002
)

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-YamlScalar {
    param([string] $Text, [string] $Key)
    $pattern = '(?m)^\s{2}' + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        if ($v.StartsWith('"') -and $v.EndsWith('"')) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        return $v
    }
    return $null
}

function Get-YamlTopScalar {
    param([string] $Text, [string] $Key)
    $pattern = '(?m)^' + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        return $v
    }
    return $null
}

function ConvertTo-JsonEscape {
    param([string] $Value)
    if ($null -eq $Value) { return "" }
    return ($Value.Replace('\', '\\').Replace('"', '\"'))
}

function ConvertTo-WeighbridgeJson {
    param($Fields, [string] $B64)
    $esc = {
        param($s) ConvertTo-JsonEscape -Value $s
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("{")
    [void]$sb.AppendLine(('  "carNo": "{0}",' -f (& $esc $Fields.carNo)))
    [void]$sb.AppendLine(('  "carNoColor": "{0}",' -f (& $esc $Fields.carNoColor)))
    [void]$sb.AppendLine(('  "carType": "{0}",' -f (& $esc $Fields.carType)))
    [void]$sb.AppendLine(('  "buildLicenseNo": "{0}",' -f (& $esc $Fields.buildLicenseNo)))
    [void]$sb.AppendLine(('  "dataSource": "{0}",' -f (& $esc $Fields.dataSource)))
    [void]$sb.AppendLine(('  "inOutType": "{0}",' -f (& $esc $Fields.inOutType)))
    [void]$sb.AppendLine(('  "placeType": "{0}",' -f (& $esc $Fields.placeType)))
    [void]$sb.AppendLine(('  "goodsWeight": "{0}",' -f (& $esc $Fields.goodsWeight)))
    [void]$sb.AppendLine(('  "snapTime": "{0}",' -f (& $esc $Fields.snapTime)))
    [void]$sb.AppendLine(('  "snapImages": ["{0}"]' -f $B64))
    [void]$sb.Append("}")
    return $sb.ToString()
}

function ConvertTo-GateJson {
    param($Fields, [string] $B64)
    $esc = {
        param($s) ConvertTo-JsonEscape -Value $s
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("{")
    [void]$sb.AppendLine(('  "carNo": "{0}",' -f (& $esc $Fields.carNo)))
    [void]$sb.AppendLine(('  "carNoColor": "{0}",' -f (& $esc $Fields.carNoColor)))
    [void]$sb.AppendLine(('  "carType": "{0}",' -f (& $esc $Fields.carType)))
    [void]$sb.AppendLine(('  "snapTime": "{0}",' -f (& $esc $Fields.snapTime)))
    [void]$sb.AppendLine(('  "snapImages": ["{0}", "{0}"],' -f $B64))
    [void]$sb.AppendLine(('  "deviceID": "{0}",' -f (& $esc $Fields.deviceID)))
    [void]$sb.AppendLine(('  "buildLicenseNo": "{0}",' -f (& $esc $Fields.buildLicenseNo)))
    [void]$sb.AppendLine(('  "siteType": "{0}",' -f (& $esc $Fields.siteType)))
    [void]$sb.AppendLine(('  "goodsWeight": "{0}",' -f (& $esc $Fields.goodsWeight)))
    [void]$sb.AppendLine(('  "areaCode": "{0}"' -f (& $esc $Fields.areaCode)))
    [void]$sb.Append("}")
    return $sb.ToString()
}

function Get-ProductLicenseNo {
    param([string] $Raw, [string] $Suffix)
    if ([string]::IsNullOrWhiteSpace($Suffix)) { $Suffix = "-02" }
    if ($Raw.EndsWith($Suffix)) { return $Raw }
    return ($Raw + $Suffix)
}

Write-Host "[xiaoshan-upload] experimental Invoke starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing config: $ConfigPath"
}
if (-not (Test-Path -LiteralPath $FixturePath)) {
    throw "Missing fixture image: $FixturePath"
}

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$channel = Get-YamlScalar -Text $configText -Key "channel"
$url = Get-YamlScalar -Text $configText -Key "url"
$method = Get-YamlScalar -Text $configText -Key "method"
if ([string]::IsNullOrWhiteSpace($method)) { $method = "POST" }
$environment = Get-YamlTopScalar -Text $configText -Key "environment"
if ([string]::IsNullOrWhiteSpace($environment)) { $environment = "local" }
$slug = Get-YamlTopScalar -Text $configText -Key "id"
if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "xiaoshan-upload" }

$carNo = Get-YamlScalar -Text $configText -Key "carNo"
$carNoColor = Get-YamlScalar -Text $configText -Key "carNoColor"
if ([string]::IsNullOrWhiteSpace($carNoColor) -or $carNoColor -eq "null") {
    $carNoColor = $CarNoColorYellow
}
$carType = Get-YamlScalar -Text $configText -Key "carType"
if ([string]::IsNullOrWhiteSpace($carType)) { $carType = $CarTypeHeavy }
$licenseRaw = Get-YamlScalar -Text $configText -Key "buildLicenseNo"
$goodsWeight = Get-YamlScalar -Text $configText -Key "goodsWeight"
if ([string]::IsNullOrWhiteSpace($goodsWeight)) {
    $kg = Get-YamlScalar -Text $configText -Key "grossWeightKg"
    $goodsWeight = $kg
}

$fields = @{
    carNo          = $carNo
    carNoColor     = $carNoColor
    carType        = $carType
    goodsWeight    = $goodsWeight
    dataSource     = Get-YamlScalar -Text $configText -Key "dataSource"
    inOutType      = Get-YamlScalar -Text $configText -Key "inOutType"
    placeType      = Get-YamlScalar -Text $configText -Key "placeType"
    deviceID       = Get-YamlScalar -Text $configText -Key "deviceID"
    siteType       = Get-YamlScalar -Text $configText -Key "siteType"
    areaCode       = Get-YamlScalar -Text $configText -Key "areaCode"
    productSuffix  = Get-YamlScalar -Text $configText -Key "productSuffix"
}

if ([string]::IsNullOrWhiteSpace($url)) {
    throw "target.url missing in config.yaml"
}
if ([string]::IsNullOrWhiteSpace($channel)) {
    throw "scenario.channel missing (weighbridge|gate|product)"
}

switch ($channel) {
    "weighbridge" { $fields.buildLicenseNo = $licenseRaw }
    "gate" { $fields.buildLicenseNo = $licenseRaw }
    "product" {
        $sfx = $fields.productSuffix
        if ([string]::IsNullOrWhiteSpace($sfx)) { $sfx = "-02" }
        $fields.buildLicenseNo = Get-ProductLicenseNo -Raw $licenseRaw -Suffix $sfx
    }
    default { throw ("Unknown scenario.channel: {0}" -f $channel) }
}

if (-not $SkipConfirm) {
    if ($environment -ne "local") {
        $ans = Read-Host ("environment={0} (non-local). Type YES to continue" -f $environment)
        if ($ans -ne "YES") { throw "Aborted at environment gate." }
    }
    $ans2 = Read-Host ("POST {0} will WRITE to government platform. Type YES to continue" -f $channel)
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
$fields.snapTime = $snapTime
$bytes = [System.IO.File]::ReadAllBytes($FixturePath)
$b64 = [Convert]::ToBase64String($bytes)
$b64Omitted = "[omitted base64; bytes={0}]" -f $bytes.Length

if ($channel -eq "weighbridge") {
    $payloadJson = ConvertTo-WeighbridgeJson -Fields $fields -B64 $b64
    $redactedBody = ConvertTo-WeighbridgeJson -Fields $fields -B64 $b64Omitted
    $snapImagesCount = 1
}
else {
    $payloadJson = ConvertTo-GateJson -Fields $fields -B64 $b64
    $redactedBody = ConvertTo-GateJson -Fields $fields -B64 $b64Omitted
    $snapImagesCount = 2
}

$requestMeta = [ordered]@{
    method           = $method
    url              = $url
    channel          = $channel
    contentType      = "application/json; charset=utf-8"
    snapTime         = $snapTime
    snapImagesCount  = $snapImagesCount
    snapImagesBytes  = $bytes.Length
    carNo            = $carNo
    buildLicenseNo   = $fields.buildLicenseNo
    goodsWeight      = $goodsWeight
    fixture          = $FixtureRel
}
Write-Utf8NoBom -Path (Join-Path $HttpDir "request.meta.json") -Content ($requestMeta | ConvertTo-Json -Depth 5)
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
    slug           = $slug
    channel        = $channel
    family         = "probe"
    runDir         = $RunDir
    url            = $url
    httpStatus     = $httpStatus
    elapsedMs      = $sw.ElapsedMilliseconds
    businessCode   = $bizCode
    businessMsg    = $bizMsg
    snapTime       = $snapTime
    buildLicenseNo = $fields.buildLicenseNo
    L0             = $l0
    L1             = $l1
    L2             = $l2
    L3             = "pending-user"
    error          = $errorText
    status         = $StatusWaitingZh
}
Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 5)

$reportLines = @(
    ("# Report - {0}" -f $slug)
    ""
    ("Status: **{0}**" -f $StatusWaitingZh)
    ""
    "| Item | Value |"
    "|------|-------|"
    ("| run | ``{0}`` |" -f $RunDir)
    ("| channel | {0} |" -f $channel)
    ("| url | {0} |" -f $url)
    ("| buildLicenseNo | {0} |" -f $fields.buildLicenseNo)
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
    ("# Acceptance - {0} (run copy)" -f $slug)
    ""
    "Status: **pending**"
    ""
    "| Item | Value |"
    "|------|-------|"
    ("| run | ``{0}`` |" -f $RunDir)
    ("| channel | {0} |" -f $channel)
    ("| L0 | {0} |" -f $l0)
    ("| L1 | {0} |" -f $l1)
    ("| L2 | {0} |" -f $l2)
    "| L3 | pending-user |"
    "| object | |"
    "| reason | |"
)
Write-Utf8NoBom -Path (Join-Path $RunDir "acceptance.md") -Content ($acceptanceLines -join "`n")

Write-Host ("[{0}] done. channel={1} runDir={2} http={3} code={4} license={5}" -f $slug, $channel, $RunDir, $httpStatus, $bizCode, $fields.buildLicenseNo)
Write-Host "Please accept: pass / fail + object + reason."

if ($null -ne $errorText -and $null -eq $httpStatus) {
    exit 2
}
exit 0
