#Requires -Version 5.1
<#
  Standalone XNXS20240725003 weighbridge probe for internal network.
  Params match pipelines/graphs/govsync/xnxs20240725003-weighbridge/config.yaml.
  Place snap image (test_pic.png or b94c5e7e31e77b9eb42ec009e8deeb49.png) next to this script.
#>
[CmdletBinding()]
param(
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Url = "http://191.12.15.58:8899/sapi/v1/inoutRecord/lantu/saveRecord"

$FixtureCandidates = @(
    (Join-Path $ScriptDir "b94c5e7e31e77b9eb42ec009e8deeb49.png"),
    (Join-Path $ScriptDir "test_pic.png"),
    (Join-Path $ScriptDir "test_pic.jpg")
)
$FixturePath = $null
foreach ($c in $FixtureCandidates) {
    if (Test-Path -LiteralPath $c) {
        $FixturePath = $c
        break
    }
}

$Fields = @{
    carNo          = ([string][char]0x6D59) + "A12345"
    carNoColor     = [string][char]0x9EC4
    carType        = ([string][char]0x5927) + ([string][char]0x8F66)
    buildLicenseNo = "XNXS20240725003"
    dataSource     = "WEIGHBRIDGE_XIAOSHAN"
    inOutType      = "0"
    placeType      = "1"
    goodsWeight    = "1385"
    snapTime       = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
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

function ConvertTo-WeighbridgeJson {
    param($F, [string] $B64)
    $e = { param($s) ConvertTo-JsonEscape -Value $s }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("{")
    [void]$sb.AppendLine(('  "carNo": "{0}",' -f (& $e $F.carNo)))
    [void]$sb.AppendLine(('  "carNoColor": "{0}",' -f (& $e $F.carNoColor)))
    [void]$sb.AppendLine(('  "carType": "{0}",' -f (& $e $F.carType)))
    [void]$sb.AppendLine(('  "buildLicenseNo": "{0}",' -f (& $e $F.buildLicenseNo)))
    [void]$sb.AppendLine(('  "dataSource": "{0}",' -f (& $e $F.dataSource)))
    [void]$sb.AppendLine(('  "inOutType": "{0}",' -f (& $e $F.inOutType)))
    [void]$sb.AppendLine(('  "placeType": "{0}",' -f (& $e $F.placeType)))
    [void]$sb.AppendLine(('  "goodsWeight": "{0}",' -f (& $e $F.goodsWeight)))
    [void]$sb.AppendLine(('  "snapTime": "{0}",' -f (& $e $F.snapTime)))
    [void]$sb.AppendLine(('  "snapImages": ["{0}"]' -f $B64))
    [void]$sb.Append("}")
    return $sb.ToString()
}

Write-Host "=== XNXS20240725003 weighbridge internal probe ===" -ForegroundColor Cyan
Write-Host "URL: $Url"

if (-not $FixturePath) {
    Write-Host "ERROR: missing snap image in: $ScriptDir" -ForegroundColor Red
    Write-Host "Expected: b94c5e7e31e77b9eb42ec009e8deeb49.png (or test_pic.png)" -ForegroundColor Yellow
    exit 1
}
Write-Host "Fixture: $FixturePath"

if (-not $SkipConfirm) {
    Write-Host ""
    Write-Host "WARNING: POST will WRITE a weighbridge record (license XNXS20240725003)." -ForegroundColor Yellow
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
$payloadJson = ConvertTo-WeighbridgeJson -F $Fields -B64 $b64

$meta = [ordered]@{
    url             = $Url
    channel         = "weighbridge"
    snapTime        = $Fields.snapTime
    buildLicenseNo  = $Fields.buildLicenseNo
    dataSource      = $Fields.dataSource
    carNo           = $Fields.carNo
    goodsWeight     = $Fields.goodsWeight
    snapImagesBytes = $bytes.Length
    fixture         = [System.IO.Path]::GetFileName($FixturePath)
}
Write-Utf8NoBom -Path (Join-Path $HttpDir "request.meta.json") -Content ($meta | ConvertTo-Json -Depth 5)

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
$jsonOk = $false
try {
    if ([string]::IsNullOrWhiteSpace($respText)) { throw "empty body" }
    $obj = $respText | ConvertFrom-Json
    $jsonOk = ($null -ne $obj.code) -or ($null -ne $obj.msg)
    if ($null -ne $obj.code) { $bizCode = [int]$obj.code }
    if ($null -ne $obj.msg) { $bizMsg = [string]$obj.msg }
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ($obj | ConvertTo-Json -Depth 8)
}
catch {
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ('{"source":"unparseable"}')
}

$l0 = if ($null -ne $httpStatus) { "pass" } else { "fail" }
$l1 = if ($jsonOk) { "pass" } else { "fail" }
$l2 = if ($bizCode -eq 200) { "pass" } else { "fail" }

$summary = [ordered]@{
    url            = $Url
    buildLicenseNo = $Fields.buildLicenseNo
    goodsWeight    = $Fields.goodsWeight
    httpStatus     = $httpStatus
    elapsedMs      = $sw.ElapsedMilliseconds
    businessCode   = $bizCode
    businessMsg    = $bizMsg
    L0             = $l0
    L1             = $l1
    L2             = $l2
    error          = $errorText
    outputDir      = $OutDir
}
Write-Utf8NoBom -Path (Join-Path $OutDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 5)

Write-Host ""
Write-Host "HTTP status : $httpStatus"
Write-Host "Elapsed ms  : $($sw.ElapsedMilliseconds)"
Write-Host "Business    : code=$bizCode msg=$bizMsg"
Write-Host "L0/L1/L2    : $l0 / $l1 / $l2"
if ($errorText) { Write-Host "Error       : $errorText" -ForegroundColor Red }
Write-Host ""
Write-Host "Evidence saved to: $OutDir" -ForegroundColor Green
Write-Host "Copy output folder back for review if needed."

if ($null -ne $errorText -and $null -eq $httpStatus) { exit 2 }
if ($l2 -ne "pass") { exit 1 }
exit 0
