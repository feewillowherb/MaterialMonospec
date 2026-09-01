#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental reconcile: MaterialClient passage seeds ↔ UrbanManagement ingest/list APIs.
.DESCRIPTION
  Modes:
    Bridge (default) — POST UM receive from urban-passage-probe seed cases (simulates client upload).
    ReconcileOnly    — GET UM lists and compare to seed plate expectations (no POST).
  Optional -IncludeClientProbe runs urban-passage-probe first (client local SQLite).
#>
[CmdletBinding()]
param(
    [ValidateSet("Bridge", "ReconcileOnly")]
    [string] $Mode = "Bridge",

    [string] $RunDir = "",
    [switch] $IncludeClientProbe,
    [switch] $SkipAttachment,
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$PassageCasesPath = Join-Path $GraphRoot "../urban-passage-probe/seeds/passage-cases.json"
$LprDevicesPath = Join-Path $GraphRoot "../urban-passage-probe/seeds/lpr-devices.json"
$FixturePath = Join-Path $GraphRoot "../../govsync/xiaoshan-gate/fixtures/test_pic.jpg"
$ClientProbeScript = Join-Path $GraphRoot "../urban-passage-probe/scripts/Invoke-UrbanPassageProbe.ps1"

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-YamlScalarLocal {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*{0}\s*:\s*(.+)\s*$" -f [regex]::Escape($Key)
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { return $null }
    return ($m.Groups[1].Value.Trim().Trim('"').Trim("'"))
}

function Get-SecretsScalar {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*{0}\s*:\s*(.+)\s*$" -f [regex]::Escape($Key)
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { return $null }
    $v = $m.Groups[1].Value.Trim()
    if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
    return $v
}

function Invoke-UmJson {
    param(
        [string] $Method,
        [string] $Url,
        [object] $Body = $null,
        [hashtable] $Headers = @{}
    )
    $params = @{
        Uri        = $Url
        Method     = $Method
        TimeoutSec = 120
        Headers    = $Headers
    }
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 12 -Compress
        $params.ContentType = "application/json; charset=utf-8"
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
    }
    return Invoke-RestMethod @params
}

function New-DeviceMap {
    param([object[]] $Devices)
    $map = @{}
    foreach ($d in $Devices) {
        $map[[string]$d.name] = $d
    }
    return $map
}

function Build-ReceiveBody {
    param(
        [object] $Case,
        [object] $Device,
        [string] $ProId,
        [string] $BuildLicenseNo,
        [string[]] $AttachmentIds = @()
    )
    return [ordered]@{
        proId           = $ProId
        buildLicenseNo  = $BuildLicenseNo
        plateNumber     = [string]$Case.plateNumber
        plateColor      = [string]$Case.plateColor
        vehicleType     = [string]$Case.vehicleType
        urbanInOutType  = [string]$Device.urbanInOutType
        urbanSiteType   = [string]$Device.urbanSiteType
        capturedAt      = (Get-Date).ToString("o")
        attachmentIds   = @($AttachmentIds)
    }
}

if (-not (Test-Path -LiteralPath $PassageCasesPath)) {
    throw "Missing passage cases: $PassageCasesPath"
}
if (-not (Test-Path -LiteralPath $LprDevicesPath)) {
    throw "Missing LPR devices: $LprDevicesPath"
}

Write-Host "[urban-passage-um-reconcile] experimental reconcile starting (Mode=$Mode)..."

$umBaseUrl = "http://localhost:44300"
$configText = ""
if (Test-Path -LiteralPath $ConfigPath) {
    $configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
    $fromConfig = Get-YamlScalarLocal -Text $configText -Key "umBaseUrl"
    if (-not [string]::IsNullOrWhiteSpace($fromConfig)) {
        $umBaseUrl = $fromConfig.Trim().TrimEnd('/')
    }
}

$proId = "08DDCF46-3744-D3E1-1999-0D645800B322"
$buildLicenseNo = "XNXS20260611001"
$authHeader = @{}
$secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
if (Test-Path -LiteralPath $secretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
    $fromSecrets = Get-SecretsScalar -Text $secretsText -Key "umBaseUrl"
    if (-not [string]::IsNullOrWhiteSpace($fromSecrets)) {
        $umBaseUrl = $fromSecrets.Trim().TrimEnd('/')
    }
    $p = Get-SecretsScalar -Text $secretsText -Key "proId"
    if (-not [string]::IsNullOrWhiteSpace($p)) { $proId = $p.Trim() }
    $b = Get-SecretsScalar -Text $secretsText -Key "buildLicenseNo"
    if (-not [string]::IsNullOrWhiteSpace($b)) { $buildLicenseNo = $b.Trim() }
    $auth = Get-SecretsScalar -Text $secretsText -Key "authorization"
    if (-not [string]::IsNullOrWhiteSpace($auth)) {
        $authHeader["Authorization"] = $auth.Trim()
    }
}

if (-not $SkipConfirm) {
    $ans = Read-Host (
        "Mode={0} will POST/GET UrbanManagement at {1} (proId={2}). Type YES to continue" -f $Mode, $umBaseUrl, $proId)
    if ($ans -ne "YES") { throw "Aborted at human gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$HttpDir = Join-Path $RunDir "http"
$ReconcileDir = Join-Path $RunDir "reconcile"
$ClientProbeDir = Join-Path $RunDir "client-probe"
New-Item -ItemType Directory -Force -Path $HttpDir, $ReconcileDir | Out-Null

$cases = @(Get-Content -LiteralPath $PassageCasesPath -Raw | ConvertFrom-Json)
$devices = @(Get-Content -LiteralPath $LprDevicesPath -Raw | ConvertFrom-Json)
$deviceMap = New-DeviceMap -Devices $devices

if ($IncludeClientProbe) {
    if (-not (Test-Path -LiteralPath $ClientProbeScript)) {
        throw "Missing client probe script: $ClientProbeScript"
    }
    New-Item -ItemType Directory -Force -Path $ClientProbeDir | Out-Null
    Write-Host "[urban-passage-um-reconcile] running urban-passage-probe..."
    & $ClientProbeScript -RunDir $ClientProbeDir -SkipConfirm
    if ($LASTEXITCODE -ne 0) {
        throw "urban-passage-probe failed (exit $LASTEXITCODE)."
    }
}

$checkpointReceiveUrl = "$umBaseUrl/api/app/urban-checkpoint-passage/receive"
$productReceiveUrl = "$umBaseUrl/api/app/urban-finished-product-passage/receive"
$checkpointListUrl = "$umBaseUrl/api/app/urban-checkpoint-passage?MaxResultCount=100"
$productListUrl = "$umBaseUrl/api/app/urban-finished-product-passage?MaxResultCount=100"

$ingestResults = @()
$l0 = $false
$l1 = $true

if ($Mode -eq "Bridge") {
    $idx = 0
    foreach ($case in $cases) {
        $idx++
        $deviceName = [string]$case.deviceName
        if (-not $deviceMap.ContainsKey($deviceName)) {
            throw "Unknown deviceName in case $($case.id): $deviceName"
        }
        $device = $deviceMap[$deviceName]
        $siteType = [string]$case.siteType
        $body = Build-ReceiveBody -Case $case -Device $device -ProId $proId -BuildLicenseNo $buildLicenseNo
        $prefix = ("{0:D2}-{1}" -f $idx, [string]$case.id)

        $url = if ($siteType -eq "Checkpoint") { $checkpointReceiveUrl } else { $productReceiveUrl }
        Write-Utf8NoBom (Join-Path $HttpDir ("{0}.request.json" -f $prefix)) -Content ($body | ConvertTo-Json -Depth 8)

        $ok = $false
        $recordId = $null
        $err = $null
        try {
            $resp = Invoke-UmJson -Method Post -Url $url -Body $body -Headers $authHeader
            $ok = ($null -ne $resp) -and ($null -ne $resp.recordId)
            if ($ok) { $recordId = [string]$resp.recordId }
            Write-Utf8NoBom (Join-Path $HttpDir ("{0}.response.json" -f $prefix)) -Content ($resp | ConvertTo-Json -Depth 8)
        }
        catch {
            $err = $_.Exception.Message
            Write-Utf8NoBom (Join-Path $HttpDir ("{0}.response.error.txt" -f $prefix)) -Content $err
            $l1 = $false
        }

        $ingestResults += [ordered]@{
            index      = $idx
            id         = [string]$case.id
            siteType   = $siteType
            plateNumber = [string]$case.plateNumber
            url        = $url
            success    = $ok
            recordId   = $recordId
            error      = $err
        }
    }
}

# L0/L2: fetch UM lists
$checkpointList = $null
$productList = $null
$listErr = $null
try {
    $checkpointList = Invoke-UmJson -Method Get -Url $checkpointListUrl -Headers $authHeader
    Write-Utf8NoBom (Join-Path $HttpDir "90-checkpoint-list.json") -Content ($checkpointList | ConvertTo-Json -Depth 10)
    $l0 = $true
}
catch {
    $listErr = $_.Exception.Message
    Write-Utf8NoBom (Join-Path $HttpDir "90-checkpoint-list.error.txt") -Content $listErr
}

try {
    $productList = Invoke-UmJson -Method Get -Url $productListUrl -Headers $authHeader
    Write-Utf8NoBom (Join-Path $HttpDir "91-product-list.json") -Content ($productList | ConvertTo-Json -Depth 10)
    if (-not $l0) { $l0 = $true }
}
catch {
    if (-not $listErr) { $listErr = $_.Exception.Message }
    Write-Utf8NoBom (Join-Path $HttpDir "91-product-list.error.txt") -Content $_.Exception.Message
}

function Get-ListPlates {
    param([object] $ListResponse)
    if ($null -eq $ListResponse) { return @() }
    $items = $null
    if ($ListResponse.PSObject.Properties.Name -contains "items") {
        $items = $ListResponse.items
    }
    elseif ($ListResponse -is [System.Array]) {
        $items = $ListResponse
    }
    if ($null -eq $items) { return @() }
    return @($items | ForEach-Object { [string]$_.plateNumber })
}

$expectedCheckpointPlates = @($cases | Where-Object { $_.siteType -eq "Checkpoint" } | ForEach-Object { [string]$_.plateNumber })
$expectedProductPlates = @($cases | Where-Object { $_.siteType -eq "FinishedProduct" } | ForEach-Object { [string]$_.plateNumber })

$actualCheckpointPlates = Get-ListPlates -ListResponse $checkpointList
$actualProductPlates = Get-ListPlates -ListResponse $productList

$missingCheckpoint = @($expectedCheckpointPlates | Where-Object { $actualCheckpointPlates -notcontains $_ })
$missingProduct = @($expectedProductPlates | Where-Object { $actualProductPlates -notcontains $_ })

$l2 = $l0 -and ($missingCheckpoint.Count -eq 0) -and ($missingProduct.Count -eq 0)
if ($Mode -eq "Bridge") {
    $l2 = $l2 -and $l1
}

$reconcilePayload = [ordered]@{
    mode                   = $Mode
    includeClientProbe     = [bool]$IncludeClientProbe
    expectedCheckpointPlates = $expectedCheckpointPlates
    expectedProductPlates  = $expectedProductPlates
    actualCheckpointPlates = $actualCheckpointPlates
    actualProductPlates    = $actualProductPlates
    missingCheckpointPlates = $missingCheckpoint
    missingProductPlates   = $missingProduct
    ingestResults          = $ingestResults
}
Write-Utf8NoBom (Join-Path $ReconcileDir "plate-match.json") -Content ($reconcilePayload | ConvertTo-Json -Depth 8)

$summary = [ordered]@{
    graph          = "urban/urban-passage-um-reconcile"
    runDir         = $RunDir
    mode           = $Mode
    umBaseUrl      = $umBaseUrl
    proId          = $proId
    buildLicenseNo = $buildLicenseNo
    includeClientProbe = [bool]$IncludeClientProbe
    levels         = @{
        L0 = $l0
        L1 = if ($Mode -eq "Bridge") { $l1 } else { "skipped-bridge" }
        L2 = $l2
        L3 = "pending-user"
    }
    missingCheckpointPlates = $missingCheckpoint
    missingProductPlates    = $missingProduct
    finishedAt     = (Get-Date).ToString("o")
}
Write-Utf8NoBom (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 8)

$report = @"
# urban-passage-um-reconcile report

- Mode: $Mode
- UM: $umBaseUrl
- proId: $proId
- buildLicenseNo: $buildLicenseNo
- IncludeClientProbe: $IncludeClientProbe
- L0 UM lists reachable: $l0
- L1 bridge ingest ok: $(if ($Mode -eq 'Bridge') { $l1 } else { 'n/a' })
- L2 plate lists aligned: $l2
- Missing checkpoint plates: $($missingCheckpoint -join ', ')
- Missing product plates: $($missingProduct -join ', ')
- L3: pending (Blazor pages + optional Gov outbound)

OpenSpec: add-urbanmanagement-passage-xiaoshan-upload (client tasks 7.1–7.2 pending for native client-upload mode).
"@
Write-Utf8NoBom (Join-Path $RunDir "report.md") -Content $report

Write-Host "[urban-passage-um-reconcile] done. L0=$l0 L1=$l1 L2=$l2 runDir=$RunDir"
if (-not $l2) { exit 1 }
