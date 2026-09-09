#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental cook: RecycleSync HMAC auth probe against resourcePlace addBatch.
.DESCRIPTION
  POST empty JSON array [] with X-AKZTJG-* headers (ResourcePlaceHmacSigner).
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
$SecretsPath = Join-Path $GraphRoot "secrets.local.yaml"

$StatusWaitingZh = -join @(
    [char]0x7B49, [char]0x5F85, [char]0x7528, [char]0x6237, [char]0x9A8C, [char]0x6536, [char]0xFF0C,
    [char]0x5C1A, [char]0x672A, [char]0x901A, [char]0x8FC7, [char]0x3002
)
$KwSign = -join @([char]0x7B7E, [char]0x540D)
$KwAuth = -join @([char]0x9274, [char]0x6743)
$KwSecret = -join @([char]0x5BC6, [char]0x94A5)
$KwUnauthorized = -join @([char]0x672A, [char]0x6388, [char]0x6743)
$KwExpired = -join @([char]0x8FC7, [char]0x671F)
$KwTimestamp = -join @([char]0x65F6, [char]0x95F4, [char]0x6233)

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-YamlScalar {
    param([string] $Text, [string] $Key)
    $pattern = '(?m)^\s{0,4}' + [regex]::Escape($Key) + ':\s*(.+)$'
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

function Get-ResourcePlaceSortedQuery {
    param([Uri] $RequestUri)
    if ($null -eq $RequestUri -or [string]::IsNullOrWhiteSpace($RequestUri.Query)) {
        return ""
    }
    $query = $RequestUri.Query.TrimStart('?')
    if ([string]::IsNullOrEmpty($query)) {
        return ""
    }
    $pairs = $query.Split(@('&'), [StringSplitOptions]::RemoveEmptyEntries)
    $encoded = New-Object System.Collections.Generic.List[string]
    foreach ($pair in $pairs) {
        $parts = $pair.Split(@('='), 2)
        $key = [Uri]::EscapeDataString([Uri]::UnescapeDataString($parts[0]))
        $value = ""
        if ($parts.Length -gt 1) {
            $value = [Uri]::EscapeDataString([Uri]::UnescapeDataString($parts[1]))
        }
        $encoded.Add(("{0}={1}" -f $key, $value))
    }
    $arr = $encoded.ToArray()
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    return [string]::Join("&", $arr)
}

function Get-ResourcePlaceGmtDateTime {
    return [DateTime]::UtcNow.ToString("R", [Globalization.CultureInfo]::InvariantCulture)
}

function Get-ResourcePlaceSignature {
    param(
        [string] $Method,
        [string] $Url,
        [string] $AccessKey,
        [string] $SecretKey,
        [string] $GmtDateTime
    )
    $uri = New-Object Uri($Url)
    $sortedQuery = Get-ResourcePlaceSortedQuery -RequestUri $uri
    $signString = "{0}`n{1}`n{2}`n{3}`n" -f $Method, $sortedQuery, $AccessKey, $GmtDateTime
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    try {
        $hmac.Key = [Text.Encoding]::UTF8.GetBytes($SecretKey)
        $hash = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($signString))
        return [Convert]::ToBase64String($hash)
    }
    finally {
        $hmac.Dispose()
    }
}

function Test-AuthRejected {
    param(
        $HttpStatus,
        $BizCode,
        [string] $BizMsg
    )
    if ($HttpStatus -eq 401 -or $HttpStatus -eq 403) { return $true }
    if ($null -ne $BizCode -and ($BizCode -eq 401 -or $BizCode -eq 403)) { return $true }
    if ([string]::IsNullOrWhiteSpace($BizMsg)) { return $false }
    if ($BizMsg.IndexOf($KwSign) -ge 0) { return $true }
    if ($BizMsg.IndexOf($KwAuth) -ge 0) { return $true }
    if ($BizMsg.IndexOf($KwSecret) -ge 0) { return $true }
    if ($BizMsg.IndexOf($KwUnauthorized) -ge 0) { return $true }
    if ($BizMsg.IndexOf($KwExpired) -ge 0) { return $true }
    if ($BizMsg.IndexOf($KwTimestamp) -ge 0) { return $true }
    $lower = $BizMsg.ToLowerInvariant()
    if ($lower -match 'access.?key|secret|unauthorized|invalid.?sign|hmac') { return $true }
    return $false
}

Write-Host "[recycle-hmac-auth] experimental Invoke starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing config: $ConfigPath"
}
if (-not (Test-Path -LiteralPath $SecretsPath)) {
    throw "Missing secrets.local.yaml: $SecretsPath"
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
catch { }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$secretsText = [System.IO.File]::ReadAllText($SecretsPath, [System.Text.Encoding]::UTF8)

$slug = Get-YamlTopScalar -Text $configText -Key "id"
if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "recycle-hmac-auth" }
$environment = Get-YamlTopScalar -Text $configText -Key "environment"
if ([string]::IsNullOrWhiteSpace($environment)) { $environment = "local" }
$method = Get-YamlScalar -Text $configText -Key "method"
if ([string]::IsNullOrWhiteSpace($method)) { $method = "POST" }
$baseUrl = Get-YamlScalar -Text $configText -Key "baseUrl"
$path = Get-YamlScalar -Text $configText -Key "path"
$bodyMode = Get-YamlScalar -Text $configText -Key "bodyMode"
$pointNumber = Get-YamlScalar -Text $configText -Key "pointNumber"
$channel = Get-YamlScalar -Text $configText -Key "channel"
if ([string]::IsNullOrWhiteSpace($channel)) { $channel = "recycle-hmac-auth" }

$accessKey = Get-YamlScalar -Text $secretsText -Key "accessKey"
$secretKey = Get-YamlScalar -Text $secretsText -Key "secretKey"

if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($path)) {
    throw "target.baseUrl or target.path missing in config.yaml"
}
if ($bodyMode -ne "empty-array") {
    throw ("This graph expects target.bodyMode=empty-array; got: {0}" -f $bodyMode)
}
if ([string]::IsNullOrWhiteSpace($accessKey)) {
    throw "secrets.local.yaml accessKey missing"
}
if ([string]::IsNullOrWhiteSpace($secretKey)) {
    throw "secrets.local.yaml secretKey missing"
}

$url = $baseUrl.TrimEnd('/') + $path
if (-not $path.StartsWith('/')) {
    $url = $baseUrl.TrimEnd('/') + '/' + $path
}

if (-not $SkipConfirm) {
    if ($environment -ne "local") {
        $ans = Read-Host ("environment={0} (non-local hangzhou.gov.cn). Type YES to continue" -f $environment)
        if ($ans -ne "YES") { throw "Aborted at environment gate." }
    }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$HttpDir = Join-Path $RunDir "http"
New-Item -ItemType Directory -Force -Path $HttpDir | Out-Null

$gmtDateTime = Get-ResourcePlaceGmtDateTime
$signature = Get-ResourcePlaceSignature -Method $method.ToUpperInvariant() -Url $url -AccessKey $accessKey -SecretKey $secretKey -GmtDateTime $gmtDateTime
$payloadJson = "[]"

$akHint = $accessKey
if ($accessKey.Length -gt 6) {
    $akHint = $accessKey.Substring(0, 4) + "..." + $accessKey.Substring($accessKey.Length - 2)
}

$requestMeta = [ordered]@{
    method           = $method
    url              = $url
    channel          = $channel
    contentType      = "application/json; charset=utf-8"
    bodyMode         = $bodyMode
    pointNumber      = $pointNumber
    accessKeyHint    = $akHint
    hmacAlgorithm    = "hmac-sha256"
    hmacDateTime     = $gmtDateTime
    headersRedacted  = @("X-AKZTJG-HMAC-ACCESS-KEY", "X-AKZTJG-HMAC-SIGNATURE")
    writeTarget      = "none-empty-array"
    payloadSchema    = "JSON-Array-empty"
}
Write-Utf8NoBom -Path (Join-Path $HttpDir "request.meta.json") -Content ($requestMeta | ConvertTo-Json -Depth 5)
Write-Utf8NoBom -Path (Join-Path $HttpDir "request.body.redacted.json") -Content $payloadJson

$headers = @{
    "X-AKZTJG-HMAC-SIGNATURE"  = $signature
    "X-AKZTJG-HMAC-ALGORITHM"  = "hmac-sha256"
    "X-AKZTJG-HMAC-ACCESS-KEY" = $accessKey
    "X-AKZTJG-DATE-TIME"       = $gmtDateTime
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$httpStatus = $null
$respText = $null
$errorText = $null
try {
    $resp = Invoke-WebRequest -Uri $url -Method $method -Headers $headers `
        -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($payloadJson)) `
        -UseBasicParsing -TimeoutSec 60
    $httpStatus = [int]$resp.StatusCode
    $respText = $resp.Content
}
catch {
    $errorText = $_.Exception.Message
    if ($_.Exception.Response) {
        $httpStatus = [int]$_.Exception.Response.StatusCode
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
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
    if ($hasCode -and $null -ne $obj.code) {
        try { $bizCode = [int]$obj.code } catch { $bizCode = $obj.code }
    }
    if ($hasMsg -and $null -ne $obj.msg) { $bizMsg = [string]$obj.msg }
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ($obj | ConvertTo-Json -Depth 8)
}
catch {
    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.json") -Content ("{0}`"source`":`"unparseable`",`"rawLength`":{1}{2}" -f "{", $respText.Length, "}")
}

$authRejected = Test-AuthRejected -HttpStatus $httpStatus -BizCode $bizCode -BizMsg $bizMsg
$l0 = if ($null -ne $httpStatus) { "pass" } else { "fail" }
$l1 = if ($jsonOk) { "pass" } else { "fail" }
$l2 = "fail"
if ($jsonOk -and -not $authRejected) { $l2 = "pass" }

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
    authRejected    = $authRejected
    hmacAccepted    = ($l2 -eq "pass")
    pointNumber     = $pointNumber
    accessKeyHint   = $akHint
    hmacDateTime    = $gmtDateTime
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
    ("| pointNumber | {0} |" -f $pointNumber)
    ("| accessKey | {0} |" -f $akHint)
    ("| HTTP | {0} |" -f $httpStatus)
    ("| elapsedMs | {0} |" -f $sw.ElapsedMilliseconds)
    ("| hmacDateTime | {0} |" -f $gmtDateTime)
    ("| business code | {0} |" -f $bizCode)
    ("| business msg | {0} |" -f $bizMsg)
    ("| authRejected | {0} |" -f $authRejected)
    ("| hmacAccepted | {0} |" -f ($l2 -eq "pass"))
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
    "| object | RecycleSync HMAC addBatch empty-array |"
    "| reason | |"
)
Write-Utf8NoBom -Path (Join-Path $RunDir "acceptance.md") -Content ($acceptanceLines -join "`n")

Write-Host ("[{0}] done. channel={1} runDir={2} http={3} code={4} authRejected={5} hmacAccepted={6}" -f $slug, $channel, $RunDir, $httpStatus, $bizCode, $authRejected, ($l2 -eq "pass"))
Write-Host "Please accept: pass / fail + object + reason."

if ($null -ne $errorText -and $null -eq $httpStatus) {
    exit 2
}
exit 0
