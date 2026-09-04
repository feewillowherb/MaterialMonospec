#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: POST XiaoShanServe /Api/Post with mGovRequestWeight body.
.DESCRIPTION
  Reads graph config.yaml (channel=legacy-weigh) and POSTs legacy weigh payload.
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
$CarColorGreen = ([string][char]0x7EFF)
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

function ConvertTo-LegacyWeighJson {
    param($Fields, [string] $B64)
    $esc = {
        param($s) ConvertTo-JsonEscape -Value $s
    }
    # Align mGovRequestWeight + LegacyApiController keys (deviceID, numeric inOutType/gross/tare)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("{")
    [void]$sb.AppendLine(('  "carNo": "{0}",' -f (& $esc $Fields.carNo)))
    [void]$sb.AppendLine(('  "carColor": "{0}",' -f (& $esc $Fields.carColor)))
    [void]$sb.AppendLine(('  "carNoColor": "{0}",' -f (& $esc $Fields.carNoColor)))
    [void]$sb.AppendLine(('  "buildLicenseNo": "{0}",' -f (& $esc $Fields.buildLicenseNo)))
    [void]$sb.AppendLine(('  "inOutType": {0},' -f $Fields.inOutType))
    [void]$sb.AppendLine(('  "equipmentNumber": "{0}",' -f (& $esc $Fields.equipmentNumber)))
    [void]$sb.AppendLine(('  "equipmentType": "{0}",' -f (& $esc $Fields.equipmentType)))
    [void]$sb.AppendLine(('  "grossWeight": {0},' -f $Fields.grossWeight))
    [void]$sb.AppendLine(('  "tareWeight": {0},' -f $Fields.tareWeight))
    [void]$sb.AppendLine(('  "snapTime": "{0}",' -f (& $esc $Fields.snapTime)))
    [void]$sb.AppendLine(('  "snapImages": ["{0}"],' -f $B64))
    [void]$sb.AppendLine(('  "carType": "{0}",' -f (& $esc $Fields.carType)))
    [void]$sb.AppendLine(('  "deviceID": "{0}",' -f (& $esc $Fields.deviceID)))
    [void]$sb.AppendLine(('  "siteType": "{0}",' -f (& $esc $Fields.siteType)))
    [void]$sb.AppendLine(('  "goodsWeight": "{0}"' -f (& $esc $Fields.goodsWeight)))
    [void]$sb.Append("}")
    return $sb.ToString()
}

Write-Host "[xiaoshan-serve-apipost] experimental Invoke starting..."

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
if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "xiaoshan-serve-apipost" }

$carNo = Get-YamlScalar -Text $configText -Key "carNo"
$carNoColor = Get-YamlScalar -Text $configText -Key "carNoColor"
if ([string]::IsNullOrWhiteSpace($carNoColor) -or $carNoColor -eq "null") {
    $carNoColor = $CarNoColorYellow
}
$carColor = Get-YamlScalar -Text $configText -Key "carColor"
if ([string]::IsNullOrWhiteSpace($carColor)) { $carColor = $CarColorGreen }
$carType = Get-YamlScalar -Text $configText -Key "carType"
if ([string]::IsNullOrWhiteSpace($carType)) { $carType = $CarTypeHeavy }

$inOutRaw = Get-YamlScalar -Text $configText -Key "inOutType"
$grossRaw = Get-YamlScalar -Text $configText -Key "grossWeight"
$tareRaw = Get-YamlScalar -Text $configText -Key "tareWeight"
$inOutType = 0
$grossWeight = 0
$tareWeight = 0
[void][int]::TryParse($inOutRaw, [ref]$inOutType)
[void][int]::TryParse($grossRaw, [ref]$grossWeight)
[void][int]::TryParse($tareRaw, [ref]$tareWeight)

$fields = @{
    carNo            = $carNo
    carColor         = $carColor
    carNoColor       = $carNoColor
    carType          = $carType
    buildLicenseNo   = Get-YamlScalar -Text $configText -Key "buildLicenseNo"
    inOutType        = $inOutType
    equipmentNumber  = Get-YamlScalar -Text $configText -Key "equipmentNumber"
    equipmentType    = Get-YamlScalar -Text $configText -Key "equipmentType"
    grossWeight      = $grossWeight
    tareWeight       = $tareWeight
    goodsWeight      = Get-YamlScalar -Text $configText -Key "goodsWeight"
    deviceID         = Get-YamlScalar -Text $configText -Key "deviceID"
    siteType         = Get-YamlScalar -Text $configText -Key "siteType"
}

if ([string]::IsNullOrWhiteSpace($url)) {
    throw "target.url missing in config.yaml"
}
if ($channel -ne "legacy-weigh") {
    throw ("This graph expects scenario.channel=legacy-weigh; got: {0}" -f $channel)
}
if ([string]::IsNullOrWhiteSpace($fields.buildLicenseNo)) {
    throw "scenario.buildLicenseNo missing"
}
if ([string]::IsNullOrWhiteSpace($fields.goodsWeight)) {
    $fields.goodsWeight = ([string]$fields.grossWeight)
}

if (-not $SkipConfirm) {
    if ($environment -ne "local") {
        $ans = Read-Host ("environment={0} (non-local). Type YES to continue" -f $environment)
        if ($ans -ne "YES") { throw "Aborted at environment gate." }
    }
    $ans2 = Read-Host "POST XiaoShanServe /Api/Post may WRITE UrbanWeighingRecord (or reject staging) via UM forward. Type YES to continue"
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

$payloadJson = ConvertTo-LegacyWeighJson -Fields $fields -B64 $b64
$redactedBody = ConvertTo-LegacyWeighJson -Fields $fields -B64 $b64Omitted
$snapImagesCount = 1

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
    grossWeight      = $fields.grossWeight
    goodsWeight      = $fields.goodsWeight
    inOutType        = $fields.inOutType
    deviceID         = $fields.deviceID
    fixture          = $FixtureRel
    writeTarget      = "xiaoshanserve-forward-um"
    payloadSchema    = "mGovRequestWeight"
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
$bizSuccess = $null
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
    $hasSuccess = $null -ne ($obj.PSObject.Properties["success"])
    if (-not ($hasCode -or $hasMsg -or $hasSuccess)) {
        throw "JSON missing success/code/msg"
    }
    $jsonOk = $true
    if ($hasCode -and $null -ne $obj.code) { $bizCode = [int]$obj.code }
    if ($hasMsg -and $null -ne $obj.msg) { $bizMsg = [string]$obj.msg }
    if ($hasSuccess -and $null -ne $obj.success) { $bizSuccess = [bool]$obj.success }
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ($obj | ConvertTo-Json -Depth 8)
}
catch {
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ("{0}`"source`":`"unparseable`",`"rawLength`":{1}{2}" -f "{", $respText.Length, "}")
}

$l0 = if ($null -ne $httpStatus) { "pass" } else { "fail" }
$l1 = if ($jsonOk) { "pass" } else { "fail" }
$l2 = "fail"
if ($bizCode -eq 200) {
    if ($null -eq $bizSuccess -or $bizSuccess -eq $true) { $l2 = "pass" }
}

$summary = [ordered]@{
    slug            = $slug
    channel         = $channel
    family          = "probe"
    runDir          = $RunDir
    url             = $url
    httpStatus      = $httpStatus
    elapsedMs       = $sw.ElapsedMilliseconds
    businessCode    = $bizCode
    businessMsg     = $bizMsg
    businessSuccess = $bizSuccess
    snapTime        = $snapTime
    buildLicenseNo  = $fields.buildLicenseNo
    grossWeight     = $fields.grossWeight
    L0              = $l0
    L1              = $l1
    L2              = $l2
    L3              = "pending-user"
    error           = $errorText
    status          = $StatusWaitingZh
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
    ("| grossWeight | {0} |" -f $fields.grossWeight)
    ("| HTTP | {0} |" -f $httpStatus)
    ("| elapsedMs | {0} |" -f $sw.ElapsedMilliseconds)
    ("| snapTime | {0} |" -f $snapTime)
    ("| business code | {0} |" -f $bizCode)
    ("| business msg | {0} |" -f $bizMsg)
    ("| business success | {0} |" -f $bizSuccess)
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

Write-Host ("[{0}] done. channel={1} runDir={2} http={3} code={4} success={5} license={6}" -f $slug, $channel, $RunDir, $httpStatus, $bizCode, $bizSuccess, $fields.buildLicenseNo)
Write-Host "Please accept: pass / fail + object + reason."

if ($null -ne $errorText -and $null -eq $httpStatus) {
    exit 2
}
exit 0
