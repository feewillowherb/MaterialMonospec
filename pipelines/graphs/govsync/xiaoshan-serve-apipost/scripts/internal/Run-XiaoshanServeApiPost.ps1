#Requires -Version 5.1
<#
  Standalone XiaoShanServe /Api/Post probe (mGovRequestWeight body).
  Params match pipelines/graphs/govsync/xiaoshan-serve-apipost/config.yaml.
  Place test_pic.jpg in the same folder as this script / the .cmd launcher.
#>
[CmdletBinding()]
param(
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FixturePath = Join-Path $ScriptDir "test_pic.jpg"
$Url = "http://191.12.234.212:8899/Api/Post"
$Channel = "legacy-weigh"
$Slug = "xiaoshan-serve-apipost"

$Fields = @{
    carNo           = ([string][char]0x6D59) + "A12345"
    carColor        = [string][char]0x7EFF
    carNoColor      = [string][char]0x9EC4
    carType         = ([string][char]0x5927) + ([string][char]0x8F66)
    buildLicenseNo  = "XNXS20250819001"
    inOutType       = 0
    equipmentNumber = "WB-01"
    equipmentType   = "SCALE"
    grossWeight     = 20000
    tareWeight      = 0
    goodsWeight     = "20000"
    deviceID        = "01"
    siteType        = "1"
    snapTime        = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function ConvertTo-JsonEscape {
    param([string] $Value)
    if ($null -eq $Value) { return "" }
    return ($Value.Replace('\', '\\').Replace('"', '\"'))
}

function ConvertTo-LegacyWeighJson {
    param($F, [string] $B64)
    $e = { param($s) ConvertTo-JsonEscape -Value $s }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("{")
    [void]$sb.AppendLine(('  "carNo": "{0}",' -f (& $e $F.carNo)))
    [void]$sb.AppendLine(('  "carColor": "{0}",' -f (& $e $F.carColor)))
    [void]$sb.AppendLine(('  "carNoColor": "{0}",' -f (& $e $F.carNoColor)))
    [void]$sb.AppendLine(('  "buildLicenseNo": "{0}",' -f (& $e $F.buildLicenseNo)))
    [void]$sb.AppendLine(('  "inOutType": {0},' -f $F.inOutType))
    [void]$sb.AppendLine(('  "equipmentNumber": "{0}",' -f (& $e $F.equipmentNumber)))
    [void]$sb.AppendLine(('  "equipmentType": "{0}",' -f (& $e $F.equipmentType)))
    [void]$sb.AppendLine(('  "grossWeight": {0},' -f $F.grossWeight))
    [void]$sb.AppendLine(('  "tareWeight": {0},' -f $F.tareWeight))
    [void]$sb.AppendLine(('  "snapTime": "{0}",' -f (& $e $F.snapTime)))
    [void]$sb.AppendLine(('  "snapImages": ["{0}"],' -f $B64))
    [void]$sb.AppendLine(('  "carType": "{0}",' -f (& $e $F.carType)))
    [void]$sb.AppendLine(('  "deviceID": "{0}",' -f (& $e $F.deviceID)))
    [void]$sb.AppendLine(('  "siteType": "{0}",' -f (& $e $F.siteType)))
    [void]$sb.AppendLine(('  "goodsWeight": "{0}"' -f (& $e $F.goodsWeight)))
    [void]$sb.Append("}")
    return $sb.ToString()
}

Write-Host "=== XiaoShanServe /Api/Post (mGovRequestWeight) ===" -ForegroundColor Cyan
Write-Host "URL: $Url"
Write-Host ("buildLicenseNo: {0} grossWeight: {1}" -f $Fields.buildLicenseNo, $Fields.grossWeight)

if (-not (Test-Path -LiteralPath $FixturePath)) {
    Write-Host "ERROR: missing test_pic.jpg in: $ScriptDir" -ForegroundColor Red
    exit 1
}

if (-not $SkipConfirm) {
    Write-Host ""
    Write-Host "WARNING: POST may WRITE UrbanWeighingRecord via Serve->UM forward." -ForegroundColor Yellow
    $ans = Read-Host "Type YES to continue"
    if ($ans -ne "YES") {
        Write-Host "Aborted."
        exit 1
    }
}

$stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
$OutDir = Join-Path $ScriptDir ("output\" + $stamp)
$HttpDir = Join-Path $OutDir "http"
New-Item -ItemType Directory -Force -Path $HttpDir | Out-Null

$bytes = [System.IO.File]::ReadAllBytes($FixturePath)
$b64 = [Convert]::ToBase64String($bytes)
$b64Omitted = "[omitted base64; bytes={0}]" -f $bytes.Length
$payloadJson = ConvertTo-LegacyWeighJson -F $Fields -B64 $b64
$redactedBody = ConvertTo-LegacyWeighJson -F $Fields -B64 $b64Omitted

$meta = [ordered]@{
    url             = $Url
    channel         = $Channel
    payloadSchema   = "mGovRequestWeight"
    snapTime        = $Fields.snapTime
    buildLicenseNo  = $Fields.buildLicenseNo
    grossWeight     = $Fields.grossWeight
    carNo           = $Fields.carNo
    deviceID        = $Fields.deviceID
    snapImagesCount = 1
    snapImagesBytes = $bytes.Length
}
Write-Utf8NoBom -Path (Join-Path $HttpDir "request.meta.json") -Content ($meta | ConvertTo-Json -Depth 5)
Write-Utf8NoBom -Path (Join-Path $HttpDir "request.body.redacted.json") -Content $redactedBody

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$httpStatus = $null
$respText = ""
$errorText = $null
try {
    $resp = Invoke-WebRequest -Uri $Url -Method POST `
        -ContentType "application/json; charset=utf-8" `
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

Write-Utf8NoBom -Path (Join-Path $HttpDir "response.raw.txt") -Content $respText

$bizCode = $null
$bizMsg = $null
$bizSuccess = $null
$jsonOk = $false
try {
    if ([string]::IsNullOrWhiteSpace($respText)) { throw "empty body" }
    $obj = $respText | ConvertFrom-Json
    $jsonOk = ($null -ne $obj.code) -or ($null -ne $obj.msg) -or ($null -ne $obj.success)
    if ($null -ne $obj.code) { $bizCode = [int]$obj.code }
    if ($null -ne $obj.msg) { $bizMsg = [string]$obj.msg }
    if ($null -ne $obj.success) { $bizSuccess = [bool]$obj.success }
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ($obj | ConvertTo-Json -Depth 8)
}
catch {
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ('{"source":"unparseable"}')
}

$l0 = if ($null -ne $httpStatus) { "pass" } else { "fail" }
$l1 = if ($jsonOk) { "pass" } else { "fail" }
$l2 = "fail"
if ($bizCode -eq 200) {
    if ($null -eq $bizSuccess -or $bizSuccess -eq $true) { $l2 = "pass" }
}

$summary = [ordered]@{
    slug            = $Slug
    channel         = $Channel
    url             = $Url
    httpStatus      = $httpStatus
    elapsedMs       = $sw.ElapsedMilliseconds
    businessCode    = $bizCode
    businessMsg     = $bizMsg
    businessSuccess = $bizSuccess
    buildLicenseNo  = $Fields.buildLicenseNo
    L0              = $l0
    L1              = $l1
    L2              = $l2
    error           = $errorText
    outputDir       = $OutDir
}
Write-Utf8NoBom -Path (Join-Path $OutDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 5)

Write-Host ""
Write-Host "HTTP status : $httpStatus"
Write-Host "Business    : code=$bizCode msg=$bizMsg success=$bizSuccess"
Write-Host "L0/L1/L2    : $l0 / $l1 / $l2"
if ($errorText) { Write-Host "Error       : $errorText" -ForegroundColor Red }
Write-Host "Evidence    : $OutDir" -ForegroundColor Green

if ($null -ne $errorText -and $null -eq $httpStatus) { exit 2 }
if ($l2 -ne "pass") { exit 1 }
exit 0
