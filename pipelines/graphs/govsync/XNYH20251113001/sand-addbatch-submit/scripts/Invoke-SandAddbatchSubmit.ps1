#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental: sand-addbatch-submit bind / smoke / resume (HMAC addBatch).

  Default: submitEnabled=false → verify source run only, exit 0, zero HTTP.
  Smoke/full POST requires: config.submitEnabled=true AND -AllowPost.
  Durable skip ledger: state/submit-state.jsonl (status + postedAt by dataNo).
#>
[CmdletBinding()]
param(
    [switch] $AllowPost,
    [ValidateSet("", "validate-only", "smoke", "resume", "full")]
    [string] $Mode = "",
    [string] $SmokeDataNo = "",
    [string] $SmokePartFile = "",
    [string] $RunDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsPath = Join-Path $GraphRoot "secrets.local.yaml"
$StateDir = Join-Path $GraphRoot "state"
$DurableStatePath = Join-Path $StateDir "submit-state.jsonl"
$SourceRunRelDefault = "seeds\source-run\2026-09-09T152356"

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Add-Utf8NoBomLine {
    param([string] $Path, [string] $Line)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText($Path, ($Line + "`n"), $utf8)
}

# Decode HTTP body as UTF-8. PS 5.1 Invoke-WebRequest.Content often mojibakes Chinese.
function Read-WebResponseUtf8Text {
    param($Response)
    if ($null -eq $Response) { return "" }

    # Prefer raw bytes → UTF-8
    try {
        $stream = $Response.RawContentStream
        if ($null -ne $stream -and $stream.CanRead) {
            if ($stream.CanSeek) { $stream.Position = 0 }
            $ms = New-Object System.IO.MemoryStream
            $stream.CopyTo($ms)
            $bytes = $ms.ToArray()
            if ($bytes.Length -gt 0) {
                return [Text.Encoding]::UTF8.GetString($bytes)
            }
        }
    }
    catch { }

    $s = [string]$Response.Content
    if ([string]::IsNullOrEmpty($s)) { return "" }

    # Repair classic UTF-8-bytes-read-as-Latin1/CP1252 mojibake (e.g. 操作成功)
    try {
        $latin1 = [Text.Encoding]::GetEncoding(28591) # ISO-8859-1
        $repaired = [Text.Encoding]::UTF8.GetString($latin1.GetBytes($s))
        if ($repaired -match '[\u4e00-\u9fff]') { return $repaired }
    }
    catch { }

    return $s
}

function Read-ErrorResponseUtf8Text {
    param($Exception)
    if ($null -eq $Exception -or $null -eq $Exception.Response) { return "" }
    try {
        $stream = $Exception.Response.GetResponseStream()
        if ($null -eq $stream) { return "" }
        $ms = New-Object System.IO.MemoryStream
        $stream.CopyTo($ms)
        $bytes = $ms.ToArray()
        if ($bytes.Length -eq 0) { return "" }
        return [Text.Encoding]::UTF8.GetString($bytes)
    }
    catch {
        return ""
    }
}

function Get-YamlScalar {
    param([string] $Text, [string] $Key)
    $pattern = '(?m)^\s{0,4}' + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        if ($v.StartsWith("'") -and $v.EndsWith("'")) { return $v.Substring(1, $v.Length - 2) }
        if ($v.StartsWith('"') -and $v.EndsWith('"')) { return $v.Substring(1, $v.Length - 2) }
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
    if ([string]::IsNullOrEmpty($query)) { return "" }
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

function Read-SubmitStateMap {
    param([string] $Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line.Length -eq 0) { return }
        try {
            $obj = $line | ConvertFrom-Json
            if ($obj.dataNo) { $map[$obj.dataNo] = $obj }
        }
        catch { }
    }
    return $map
}

function Test-AlreadyPosted {
    param($StateObj)
    if ($null -eq $StateObj) { return $false }
    $st = [string]$StateObj.status
    return ($st -eq "posted" -or $st -eq "smoke-posted")
}

function ConvertTo-ApiPayloadObject {
    param($Trip, [string] $OutPhotosBase64, [string] $SaleContractNo)
    # Build ordered fields for addBatch element; strip outPhotosPath.
    return [ordered]@{
        dataNo            = [string]$Trip.dataNo
        dataStatus        = [int]$Trip.dataStatus
        pointNumber       = [string]$Trip.pointNumber
        carNo             = [string]$Trip.carNo
        productName       = [string]$Trip.productName
        netWeight         = [double]$Trip.netWeight
        tareWeight        = [double]$Trip.tareWeight
        grossWeight       = [double]$Trip.grossWeight
        outTime           = [string]$Trip.outTime
        outPhotos         = $OutPhotosBase64
        saleContractNo    = $SaleContractNo
        consignee         = [string]$Trip.consignee
        consigneeAddress  = [string]$Trip.consigneeAddress
        receivingTime     = [string]$Trip.receivingTime
    }
}

function Get-SaleContractNo {
    param($Trip)
    # Live platform rejects empty saleContractNo despite docs "optional".
    # Deterministic from outTime date + dataNo suffix for resume stability.
    $day = ""
    if ([string]$Trip.outTime -match '^(\d{4})-(\d{2})-(\d{2})') {
        $day = "$($Matches[1])$($Matches[2])$($Matches[3])"
    }
    else {
        $day = (Get-Date).ToString("yyyyMMdd")
    }
    $seq = "0001"
    if ([string]$Trip.dataNo -match '-(\d{4})$') { $seq = $Matches[1] }
    return "XSHT$day$seq"
}

function ConvertTo-CompactJsonArray {
    param([object[]] $Items)
    # Avoid PS ConvertTo-Json wrapping a single object as bare object.
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Items) {
        $parts.Add(($item | ConvertTo-Json -Depth 8 -Compress))
    }
    return "[" + [string]::Join(",", $parts.ToArray()) + "]"
}

Write-Host "[sand-addbatch-submit] starting..."

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
catch { }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$submitEnabled = Get-YamlScalar -Text $configText -Key "submitEnabled"
$runId = Get-YamlScalar -Text $configText -Key "runId"
if ([string]::IsNullOrWhiteSpace($runId)) { $runId = "2026-09-09T152356" }
$sourceRel = Get-YamlScalar -Text $configText -Key "runDirRel"
if ([string]::IsNullOrWhiteSpace($sourceRel)) { $sourceRel = $SourceRunRelDefault.Replace("\", "/") }
$cfgMode = Get-YamlScalar -Text $configText -Key "mode"
if ([string]::IsNullOrWhiteSpace($Mode)) {
    if ([string]::IsNullOrWhiteSpace($cfgMode)) { $Mode = "validate-only" }
    else { $Mode = $cfgMode }
}
$smokeMaxTrips = Get-YamlScalar -Text $configText -Key "smokeMaxTrips"
if ([string]::IsNullOrWhiteSpace($smokeMaxTrips)) { $smokeMaxTrips = "1" }
$smokeMaxTrips = [int]$smokeMaxTrips
$skipPostedRaw = Get-YamlScalar -Text $configText -Key "skipPosted"
$skipPosted = ($skipPostedRaw -ne "false")
$embedPhotos = (Get-YamlScalar -Text $configText -Key "embedOutPhotosFromPath") -ne "false"
$stripPath = (Get-YamlScalar -Text $configText -Key "stripOutPhotosPath") -ne "false"
$baseUrl = Get-YamlScalar -Text $configText -Key "baseUrl"
$path = Get-YamlScalar -Text $configText -Key "path"
$method = Get-YamlScalar -Text $configText -Key "method"
if ([string]::IsNullOrWhiteSpace($method)) { $method = "POST" }

$sourceDir = Join-Path $GraphRoot (($sourceRel -replace "/", "\"))
if (-not (Test-Path -LiteralPath $sourceDir)) {
    throw "Missing frozen source run: $sourceDir"
}

$jsonDir = Join-Path $sourceDir "json"
$ledger = Join-Path $sourceDir "ledgers\dataNo-ledger.jsonl"
$submitMeta = Join-Path $sourceDir "submit-meta.json"
if (-not (Test-Path -LiteralPath $jsonDir)) { throw "Missing json/: $jsonDir" }
if (-not (Test-Path -LiteralPath $ledger)) { throw "Missing ledger: $ledger" }
if (-not (Test-Path -LiteralPath $submitMeta)) { throw "Missing submit-meta: $submitMeta" }

$partFiles = @(Get-ChildItem -LiteralPath $jsonDir -Filter "*.json" -File | Sort-Object Name)
$partCount = $partFiles.Count
$ledgerLines = @(Get-Content -LiteralPath $ledger | Where-Object { $_.Trim().Length -gt 0 }).Count
Write-Host "[bind] sourceRunId=$runId"
Write-Host "[bind] parts=$partCount ledgerRows=$ledgerLines"
Write-Host "[bind] submitEnabled=$submitEnabled AllowPost=$($AllowPost.IsPresent) mode=$Mode"

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path $GraphRoot "runs\$stamp"
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$HttpDir = Join-Path $RunDir "http"
New-Item -ItemType Directory -Force -Path $HttpDir | Out-Null
$runStatePath = Join-Path $RunDir "submit-state.jsonl"
$runLogPath = Join-Path $RunDir "submit-log.jsonl"

$wantPost = ($submitEnabled -eq "true") -and $AllowPost -and ($Mode -ne "validate-only")

$summary = [ordered]@{
    graph          = "sand-addbatch-submit"
    goal           = "gov-sand-product-addbatch-submit"
    site           = "XNYH20251113001"
    submitEnabled  = ($submitEnabled -eq "true")
    allowPost      = [bool]$AllowPost
    mode           = $Mode
    httpAttempted  = $false
    sourceRunId    = $runId
    sourceDir      = $sourceDir
    partCount      = $partCount
    ledgerRows     = $ledgerLines
    secretsPresent = (Test-Path -LiteralPath $SecretsPath)
    durableState   = $DurableStatePath
    posted         = @()
    skipped        = @()
    failed         = @()
    levels         = @{
        L0 = "pass"
        L1 = "pass"
        L2 = "n/a"
        L3 = "pending-user"
    }
    message        = "Source run bound. No HTTP."
}

if (-not $wantPost) {
    if (($submitEnabled -eq "true" -or $AllowPost) -and ($Mode -ne "validate-only")) {
        Write-Host "[gate] POST requested but gate incomplete (need submitEnabled=true AND -AllowPost AND mode!=validate-only)." -ForegroundColor Yellow
        throw "Refusing POST: set config.submitEnabled=true and pass -AllowPost (mode=smoke|resume|full)."
    }

    $summaryPath = Join-Path $RunDir "summary.json"
    Write-Utf8NoBom -Path $summaryPath -Content ($summary | ConvertTo-Json -Depth 8)
    $report = @(
        "# sand-addbatch-submit report",
        "",
        "- submitEnabled: **$submitEnabled**",
        "- AllowPost: **$($AllowPost.IsPresent)**",
        "- mode: $Mode",
        "- httpAttempted: **false**",
        "- sourceRunId: $runId",
        "- durableState: ``$DurableStatePath``",
        "",
        "validate-only / gate closed — no HTTP.",
        ""
    ) -join "`n"
    Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content $report
    Write-Host "[done] validate-only runDir=$RunDir (no HTTP)"
    exit 0
}

# --- POST path (smoke / resume / full) ---
if (-not (Test-Path -LiteralPath $SecretsPath)) {
    throw "Missing secrets.local.yaml: $SecretsPath"
}
$secretsText = [System.IO.File]::ReadAllText($SecretsPath, [System.Text.Encoding]::UTF8)
$accessKey = Get-YamlScalar -Text $secretsText -Key "accessKey"
$secretKey = Get-YamlScalar -Text $secretsText -Key "secretKey"
$apiBaseOverride = Get-YamlScalar -Text $secretsText -Key "apiBaseUrl"
if (-not [string]::IsNullOrWhiteSpace($apiBaseOverride)) { $baseUrl = $apiBaseOverride }
if ([string]::IsNullOrWhiteSpace($accessKey) -or [string]::IsNullOrWhiteSpace($secretKey)) {
    throw "secrets.local.yaml accessKey/secretKey missing"
}
if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($path)) {
    throw "target.baseUrl / target.path missing"
}
$url = $baseUrl.TrimEnd('/') + $(if ($path.StartsWith('/')) { $path } else { '/' + $path })

$stateMap = Read-SubmitStateMap -Path $DurableStatePath

# Collect candidate trips
$candidates = New-Object System.Collections.Generic.List[object]
$filesToScan = $partFiles
if (-not [string]::IsNullOrWhiteSpace($SmokePartFile)) {
    $pf = Join-Path $jsonDir $SmokePartFile
    if (-not (Test-Path -LiteralPath $pf)) { throw "SmokePartFile not found: $pf" }
    $filesToScan = @(Get-Item -LiteralPath $pf)
}

foreach ($pf in $filesToScan) {
    $arr = Get-Content -LiteralPath $pf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $arr) { continue }
    if ($arr -isnot [System.Array]) { $arr = @($arr) }
    foreach ($trip in $arr) {
        if (-not $trip.dataNo) { continue }
        if (-not [string]::IsNullOrWhiteSpace($SmokeDataNo) -and $trip.dataNo -ne $SmokeDataNo) {
            continue
        }
        $candidates.Add([pscustomobject]@{
                Trip     = $trip
                PartFile = $pf.Name
            }) | Out-Null
    }
}

if ($Mode -eq "smoke") {
    if ($candidates.Count -gt $smokeMaxTrips) {
        $candidates = [System.Collections.Generic.List[object]]$candidates.GetRange(0, $smokeMaxTrips)
    }
}

if ($candidates.Count -eq 0) {
    throw "No candidate trips to POST (check SmokeDataNo / SmokePartFile / mode)."
}

$posted = New-Object System.Collections.Generic.List[object]
$skipped = New-Object System.Collections.Generic.List[object]
$failed = New-Object System.Collections.Generic.List[object]

foreach ($cand in $candidates) {
    $trip = $cand.Trip
    $dataNo = [string]$trip.dataNo
    $prev = $null
    if ($stateMap.ContainsKey($dataNo)) { $prev = $stateMap[$dataNo] }

    if ($skipPosted -and (Test-AlreadyPosted $prev)) {
        $skipRow = [ordered]@{
            dataNo     = $dataNo
            status     = "skipped"
            reason     = "already-$($prev.status)"
            priorAt    = $prev.postedAt
            partFile   = $cand.PartFile
            attemptedAt = (Get-Date).ToString("o")
        }
        $skipped.Add($skipRow) | Out-Null
        $line = ($skipRow | ConvertTo-Json -Compress -Depth 5)
        Add-Utf8NoBomLine -Path $runLogPath -Line $line
        Write-Host "[skip] $dataNo already $($prev.status) at $($prev.postedAt)"
        continue
    }

    if (-not $embedPhotos) { throw "embedOutPhotosFromPath must be true for POST" }
    $photoPath = [string]$trip.outPhotosPath
    if ([string]::IsNullOrWhiteSpace($photoPath) -or -not (Test-Path -LiteralPath $photoPath)) {
        throw "Photo missing for $dataNo : $photoPath"
    }
    $bytes = [System.IO.File]::ReadAllBytes($photoPath)
    $b64 = [Convert]::ToBase64String($bytes)
    $saleContractNo = Get-SaleContractNo -Trip $trip
    $payloadObj = ConvertTo-ApiPayloadObject -Trip $trip -OutPhotosBase64 $b64 -SaleContractNo $saleContractNo
    if (-not $stripPath) {
        $payloadObj["outPhotosPath"] = $photoPath
    }
    $payloadJson = ConvertTo-CompactJsonArray -Items @($payloadObj)

    $gmtDateTime = Get-ResourcePlaceGmtDateTime
    $signature = Get-ResourcePlaceSignature -Method $method.ToUpperInvariant() -Url $url `
        -AccessKey $accessKey -SecretKey $secretKey -GmtDateTime $gmtDateTime

    $akHint = $accessKey
    if ($accessKey.Length -gt 6) {
        $akHint = $accessKey.Substring(0, 4) + "..." + $accessKey.Substring($accessKey.Length - 2)
    }

    $reqMeta = [ordered]@{
        method          = $method
        url             = $url
        dataNo          = $dataNo
        partFile        = $cand.PartFile
        photoPath       = $photoPath
        photoBytes      = $bytes.Length
        accessKeyHint   = $akHint
        hmacDateTime    = $gmtDateTime
        bodyBytes       = ([Text.Encoding]::UTF8.GetByteCount($payloadJson))
        outPhotosRedacted = $true
    }
    $safeName = ($dataNo -replace '[^\w\-]', '_')
    Write-Utf8NoBom -Path (Join-Path $HttpDir "request.$safeName.meta.json") -Content ($reqMeta | ConvertTo-Json -Depth 5)
    # Redacted body preview (no base64)
    $preview = [ordered]@{}
    foreach ($k in $payloadObj.Keys) {
        if ($k -eq "outPhotos") {
            $preview[$k] = "<redacted-base64 len=$($b64.Length)>"
        }
        else {
            $preview[$k] = $payloadObj[$k]
        }
    }
    Write-Utf8NoBom -Path (Join-Path $HttpDir "request.$safeName.body.redacted.json") `
        -Content (ConvertTo-CompactJsonArray -Items @($preview))

    $headers = @{
        "X-AKZTJG-HMAC-SIGNATURE"  = $signature
        "X-AKZTJG-HMAC-ALGORITHM"  = "hmac-sha256"
        "X-AKZTJG-HMAC-ACCESS-KEY" = $accessKey
        "X-AKZTJG-DATE-TIME"       = $gmtDateTime
    }

    $summary.httpAttempted = $true
    $postedAt = (Get-Date).ToString("o")
    $httpStatus = $null
    $respText = ""
    $errorText = $null
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-WebRequest -Uri $url -Method $method -Headers $headers `
            -ContentType "application/json; charset=utf-8" `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($payloadJson)) `
            -UseBasicParsing -TimeoutSec 180
        $httpStatus = [int]$resp.StatusCode
        $respText = Read-WebResponseUtf8Text -Response $resp
    }
    catch {
        $errorText = $_.Exception.Message
        if ($_.Exception.Response) {
            $httpStatus = [int]$_.Exception.Response.StatusCode
            $respText = Read-ErrorResponseUtf8Text -Exception $_.Exception
        }
    }
    $sw.Stop()

    Write-Utf8NoBom -Path (Join-Path $HttpDir "response.$safeName.raw.txt") -Content $respText

    $bizCode = $null
    $bizMsg = $null
    try {
        if (-not [string]::IsNullOrWhiteSpace($respText)) {
            $obj = $respText | ConvertFrom-Json
            if ($null -ne $obj.PSObject.Properties["code"]) { $bizCode = $obj.code }
            if ($null -ne $obj.PSObject.Properties["msg"]) { $bizMsg = [string]$obj.msg }
        }
    }
    catch { }

    $okHttp = ($httpStatus -ge 200 -and $httpStatus -lt 300)
    # Platform often returns HTTP 200 with business code; treat code 0/200/"0" as success when present.
    $okBiz = $true
    if ($null -ne $bizCode) {
        $okBiz = ($bizCode -eq 0 -or $bizCode -eq 200 -or [string]$bizCode -eq "0" -or [string]$bizCode -eq "200")
    }
    $success = $okHttp -and $okBiz -and [string]::IsNullOrWhiteSpace($errorText)

    $status = if ($success) {
        if ($Mode -eq "smoke") { "smoke-posted" } else { "posted" }
    } else { "failed" }

    $stateRow = [pscustomobject]@{
        dataNo         = $dataNo
        status         = $status
        postedAt       = $postedAt
        partFile       = $cand.PartFile
        mode           = $Mode
        httpStatus     = $httpStatus
        bizCode        = $bizCode
        bizMsg         = $bizMsg
        saleContractNo = $saleContractNo
        elapsedMs      = $sw.ElapsedMilliseconds
        photoBytes     = $bytes.Length
        error          = $errorText
        runDir         = $RunDir
    }
    $stateLine = ($stateRow | ConvertTo-Json -Compress -Depth 6)
    Add-Utf8NoBomLine -Path $DurableStatePath -Line $stateLine
    Add-Utf8NoBomLine -Path $runStatePath -Line $stateLine
    Add-Utf8NoBomLine -Path $runLogPath -Line $stateLine
    $stateMap[$dataNo] = $stateRow

    if ($success) {
        $posted.Add($stateRow) | Out-Null
        Write-Host "[posted] $dataNo status=$status http=$httpStatus code=$bizCode at $postedAt"
    }
    else {
        $failed.Add($stateRow) | Out-Null
        Write-Host "[failed] $dataNo http=$httpStatus code=$bizCode msg=$bizMsg err=$errorText" -ForegroundColor Red
    }
}

$summary["posted"] = @($posted.ToArray())
$summary["skipped"] = @($skipped.ToArray())
$summary["failed"] = @($failed.ToArray())
$l2 = if ($failed.Count -eq 0 -and $posted.Count -gt 0) { "pass" } elseif ($failed.Count -gt 0) { "fail" } else { "n/a" }
$summary["levels"] = @{
    L0 = "pass"
    L1 = "n/a"
    L2 = $l2
    L3 = "pending-user"
}
$summary["message"] = "HTTP done. posted=$($posted.Count) skipped=$($skipped.Count) failed=$($failed.Count). L3 pending-user."
Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 10)

$report = @(
    "# sand-addbatch-submit report",
    "",
    "- mode: **$Mode**",
    "- httpAttempted: **true**",
    "- posted: $($posted.Count)",
    "- skipped: $($skipped.Count)",
    "- failed: $($failed.Count)",
    "- durableState: ``$DurableStatePath``",
    "- runDir: ``$RunDir``",
    "",
    "## Posted",
    ""
) 
foreach ($p in $posted) {
    $report += "- $($p.dataNo) @ $($p.postedAt) status=$($p.status) http=$($p.httpStatus) code=$($p.bizCode)"
}
$report += ""
$report += "## Levels"
$report += ""
$report += "- L0: pass"
$report += "- L1: n/a (HTTP enabled by gate)"
$report += "- L2: $($summary.levels.L2)"
$report += "- L3: pending-user"
$report += ""
Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content ($report -join "`n")

Write-Host "[done] posted=$($posted.Count) skipped=$($skipped.Count) failed=$($failed.Count) runDir=$RunDir"
if ($failed.Count -gt 0) { exit 1 }
