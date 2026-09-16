#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental probe: UM DeviceStatusHub + Urban online badge (no BasePlatform).
.DESCRIPTION
  Optional start UM/Urban, then negotiate Hub, probe Urban host, poll client-list for
  isConnected=true. Optional presence-hold after live TTL. Writes runs/<ts>/ evidence.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [switch] $SkipStartUm,
    [switch] $SkipStartUrban,
    [switch] $SkipConfirm,
    [switch] $SkipPresenceHold
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$StartUmScript = Join-Path $PSScriptRoot "Start-UmForSignalROnlineProbe.ps1"
$StartUrbanScript = Join-Path $PSScriptRoot "Start-UrbanForSignalROnlineProbe.ps1"

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
    $v = $m.Groups[1].Value.Trim()
    if ($v -match "^(.*?)\s+#") { $v = $Matches[1].Trim() }
    return $v.Trim('"').Trim("'")
}

function Get-YamlBoolLocal {
    param([string] $Text, [string] $Key, [bool] $Default)
    $raw = Get-YamlScalarLocal -Text $Text -Key $Key
    if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
    switch -Regex ($raw.ToLowerInvariant()) {
        "^(true|yes|1)$" { return $true }
        "^(false|no|0)$" { return $false }
        default { return $Default }
    }
}

function Get-YamlIntLocal {
    param([string] $Text, [string] $Key, [int] $Default)
    $raw = Get-YamlScalarLocal -Text $Text -Key $Key
    $n = 0
    if ([int]::TryParse($raw, [ref]$n)) { return $n }
    return $Default
}

function Test-TcpPort {
    param([string] $HostName, [int] $Port, [int] $TimeoutMs = 2000)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $ok) { return $false }
        $client.EndConnect($iar)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Save-HttpEvidence {
    param(
        [string] $SinkDir,
        [string] $Name,
        [string] $Method,
        [string] $Url,
        [int] $StatusCode,
        [string] $Body,
        [hashtable] $Extra = @{}
    )
    $payload = [ordered]@{
        name       = $Name
        method     = $Method
        url        = $Url
        statusCode = $StatusCode
        capturedAt = (Get-Date).ToString("o")
        body       = $Body
    }
    foreach ($k in $Extra.Keys) { $payload[$k] = $Extra[$k] }
    Write-Utf8NoBom (Join-Path $SinkDir "$Name.json") ($payload | ConvertTo-Json -Depth 8)
}

function Wait-HttpOk {
    param([string] $Url, [int] $Attempts = 45, [int] $DelaySec = 2)
    $last = $null
    for ($i = 0; $i -lt $Attempts; $i++) {
        try {
            $null = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 5 -UseBasicParsing
            return $true
        }
        catch {
            $last = $_.Exception.Message
            Start-Sleep -Seconds $DelaySec
        }
    }
    Write-Warning "Wait-HttpOk failed for $Url : $last"
    return $false
}

function Invoke-HttpCapture {
    param(
        [string] $SinkDir,
        [string] $Name,
        [string] $Method,
        [string] $Url,
        [string] $Body = $null,
        [hashtable] $Headers = @{}
    )
    $status = 0
    $respBody = ""
    try {
        $params = @{
            Uri             = $Url
            Method          = $Method
            TimeoutSec      = 30
            UseBasicParsing = $true
        }
        if ($Headers.Count -gt 0) { $params.Headers = $Headers }
        if ($null -ne $Body) {
            $params.ContentType = "text/plain"
            $params.Body = $Body
        }
        $resp = Invoke-WebRequest @params
        $status = [int]$resp.StatusCode
        $respBody = [string]$resp.Content
    }
    catch {
        $ex = $_.Exception
        if ($ex.Response -and $ex.Response.StatusCode) {
            $status = [int]$ex.Response.StatusCode
        }
        $respBody = $ex.Message
    }
    Save-HttpEvidence -SinkDir $SinkDir -Name $Name -Method $Method -Url $Url -StatusCode $status -Body $respBody
    return @{ StatusCode = $status; Body = $respBody }
}

function Find-OnlineClient {
    param([string] $JsonBody, [string] $ExpectedProId)
    $match = $null
    try {
        $obj = $JsonBody | ConvertFrom-Json
        $items = @()
        if ($obj.items) { $items = @($obj.items) }
        elseif ($obj.Items) { $items = @($obj.Items) }
        foreach ($item in $items) {
            $proId = [string]($item.proId)
            if ([string]::IsNullOrWhiteSpace($proId)) { $proId = [string]($item.ProId) }
            $connected = $false
            if ($null -ne $item.isConnected) { $connected = [bool]$item.isConnected }
            elseif ($null -ne $item.IsConnected) { $connected = [bool]$item.IsConnected }
            if ($proId -and ($proId -ieq $ExpectedProId) -and $connected) {
                $match = $item
                break
            }
        }
    }
    catch {
        $match = $null
    }
    return $match
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing config: $ConfigPath"
}
if (-not (Test-Path -LiteralPath $StartUmScript)) {
    throw "Missing start UM script: $StartUmScript"
}
if (-not (Test-Path -LiteralPath $StartUrbanScript)) {
    throw "Missing start Urban script: $StartUrbanScript"
}

Write-Host "[urban-signalr-online-probe] experimental Invoke starting..."

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$umBaseUrl = Get-YamlScalarLocal -Text $configText -Key "umBaseUrl"
if ([string]::IsNullOrWhiteSpace($umBaseUrl)) { $umBaseUrl = "http://127.0.0.1:44371" }
$urbanBaseUrl = Get-YamlScalarLocal -Text $configText -Key "urbanDiagnosticBaseUrl"
if ([string]::IsNullOrWhiteSpace($urbanBaseUrl)) { $urbanBaseUrl = "http://localhost:9961" }
$redisHost = Get-YamlScalarLocal -Text $configText -Key "redisHost"
if ([string]::IsNullOrWhiteSpace($redisHost)) { $redisHost = "127.0.0.1" }
$redisPort = Get-YamlIntLocal -Text $configText -Key "redisPort" -Default 6379
$expectedProId = Get-YamlScalarLocal -Text $configText -Key "expectedProjectId"
$negotiatePath = Get-YamlScalarLocal -Text $configText -Key "negotiatePath"
if ([string]::IsNullOrWhiteSpace($negotiatePath)) { $negotiatePath = "/hubs/devicestatus/negotiate?negotiateVersion=1" }
$clientListPath = Get-YamlScalarLocal -Text $configText -Key "clientListGet"
if ([string]::IsNullOrWhiteSpace($clientListPath)) { $clientListPath = "/api/app/device-status/client-list?MaxResultCount=100&SkipCount=0" }
$settleSec = Get-YamlIntLocal -Text $configText -Key "onlineSettleSeconds" -Default 90
$holdSec = Get-YamlIntLocal -Text $configText -Key "presenceHoldSeconds" -Default 150
$skipHoldCfg = Get-YamlBoolLocal -Text $configText -Key "skipPresenceHold" -Default $true
if ($SkipPresenceHold) { $skipHoldCfg = $true }

$secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
if (Test-Path -LiteralPath $secretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
    $sUm = Get-YamlScalarLocal -Text $secretsText -Key "umBaseUrl"
    if (-not [string]::IsNullOrWhiteSpace($sUm)) { $umBaseUrl = $sUm }
    $sUrban = Get-YamlScalarLocal -Text $secretsText -Key "urbanDiagnosticBaseUrl"
    if (-not [string]::IsNullOrWhiteSpace($sUrban)) { $urbanBaseUrl = $sUrban }
    $sRedisHost = Get-YamlScalarLocal -Text $secretsText -Key "redisHost"
    if (-not [string]::IsNullOrWhiteSpace($sRedisHost)) { $redisHost = $sRedisHost }
    $sRedisPort = Get-YamlIntLocal -Text $secretsText -Key "redisPort" -Default $redisPort
    $redisPort = $sRedisPort
    if ($secretsText -match "(?m)^skipPresenceHold\s*:") {
        $skipHoldCfg = Get-YamlBoolLocal -Text $secretsText -Key "skipPresenceHold" -Default $skipHoldCfg
    }
    if ($SkipPresenceHold) { $skipHoldCfg = $true }
    $sHold = Get-YamlIntLocal -Text $secretsText -Key "presenceHoldSeconds" -Default $holdSec
    $holdSec = $sHold
}

$umBaseUrl = $umBaseUrl.Trim().TrimEnd('/')
$urbanBaseUrl = $urbanBaseUrl.Trim().TrimEnd('/')
if (-not $negotiatePath.StartsWith("/")) { $negotiatePath = "/" + $negotiatePath }
if (-not $clientListPath.StartsWith("/")) { $clientListPath = "/" + $clientListPath }

if (-not $SkipConfirm) {
    $ans = Read-Host (
        "Will probe SignalR online (UM={0}, Urban={1}, Redis={2}:{3}, presenceHold={4}). Type YES to continue" -f `
            $umBaseUrl, $urbanBaseUrl, $redisHost, $redisPort, (-not $skipHoldCfg))
    if ($ans -ne "YES") { throw "Aborted at human gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$HttpDir = Join-Path $RunDir "http"
$PrepareDir = Join-Path $RunDir "prepare"
New-Item -ItemType Directory -Force -Path $HttpDir, $PrepareDir | Out-Null

# --- preflight redis ---
$redisOk = Test-TcpPort -HostName $redisHost -Port $redisPort
Write-Utf8NoBom (Join-Path $PrepareDir "redis-preflight.json") ([ordered]@{
        host      = $redisHost
        port      = $redisPort
        reachable = $redisOk
        at        = (Get-Date).ToString("o")
    } | ConvertTo-Json)
if (-not $redisOk) {
    throw "Redis not reachable at ${redisHost}:${redisPort}. Start Redis before this probe (UM live online requires it)."
}

# --- start UM ---
if (-not $SkipStartUm) {
    & $StartUmScript
    Write-Utf8NoBom (Join-Path $PrepareDir "um-start.json") ([ordered]@{
            skipped  = $false
            umBaseUrl = $umBaseUrl
            at       = (Get-Date).ToString("o")
        } | ConvertTo-Json)
    $null = Wait-HttpOk -Url "$umBaseUrl/" -Attempts 60 -DelaySec 2
}
else {
    Write-Utf8NoBom (Join-Path $PrepareDir "um-start.json") ([ordered]@{
            skipped   = $true
            umBaseUrl = $umBaseUrl
            at        = (Get-Date).ToString("o")
        } | ConvertTo-Json)
}

# --- start Urban (seed + SignalR URL) ---
if (-not $SkipStartUrban) {
    & $StartUrbanScript -UmBaseUrl $umBaseUrl
}
$lastSeed = Join-Path $PSScriptRoot ".last-seed.json"
if (Test-Path -LiteralPath $lastSeed) {
    Copy-Item -LiteralPath $lastSeed -Destination (Join-Path $PrepareDir "license-seed.json") -Force
    try {
        $seedMeta = Get-Content -LiteralPath $lastSeed -Raw | ConvertFrom-Json
        if ($seedMeta.projectId) { $expectedProId = [string]$seedMeta.projectId }
    }
    catch { }
}
else {
    Write-Utf8NoBom (Join-Path $PrepareDir "license-seed.json") (@{
            source = "missing"
            note   = "Start script did not write .last-seed.json (SkipStartUrban?)"
        } | ConvertTo-Json)
}

if ([string]::IsNullOrWhiteSpace($expectedProId)) {
    throw "expectedProjectId missing from config and seed meta."
}

# --- wait Urban diagnostic ---
Write-Host "[urban-signalr-online-probe] waiting for Urban diagnostic host..."
$urbanReady = Wait-HttpOk -Url "$urbanBaseUrl/" -Attempts 45 -DelaySec 2

# --- L0 hub negotiate ---
$negotiateUrl = "$umBaseUrl$negotiatePath"
$neg = Invoke-HttpCapture -SinkDir $HttpDir -Name "hub-negotiate" -Method "POST" -Url $negotiateUrl `
    -Headers @{ "Content-Type" = "text/plain;charset=UTF-8" }
$l0Hub = ($neg.StatusCode -ge 200 -and $neg.StatusCode -lt 300) -and (
    ($neg.Body -match "connectionToken") -or ($neg.Body -match "negotiateVersion") -or ($neg.Body -match "availableTransports")
)

# --- L0/L1 Urban host ---
$root = Invoke-HttpCapture -SinkDir $HttpDir -Name "urban-root" -Method "GET" -Url "$urbanBaseUrl/"
$l0Urban = ($root.StatusCode -eq 200)
$settings = Invoke-HttpCapture -SinkDir $HttpDir -Name "urban-settings" -Method "GET" -Url "$urbanBaseUrl/api/settings"
$l1Settings = ($settings.StatusCode -eq 200)

# --- L2 poll client-list ---
$clientListUrl = "$umBaseUrl$clientListPath"
$l2Online = $false
$matchedClient = $null
$deadline = (Get-Date).AddSeconds($settleSec)
$pollIndex = 0
while ((Get-Date) -lt $deadline) {
    $pollIndex++
    $list = Invoke-HttpCapture -SinkDir $HttpDir -Name ("client-list-{0:D3}" -f $pollIndex) `
        -Method "GET" -Url $clientListUrl
    $matchedClient = Find-OnlineClient -JsonBody $list.Body -ExpectedProId $expectedProId
    if ($null -ne $matchedClient) {
        $l2Online = $true
        break
    }
    Start-Sleep -Seconds 3
}

Write-Utf8NoBom (Join-Path $PrepareDir "online-poll.json") ([ordered]@{
        expectedProId = $expectedProId
        settleSeconds = $settleSec
        polls         = $pollIndex
        online        = $l2Online
        matched       = $matchedClient
        at            = (Get-Date).ToString("o")
    } | ConvertTo-Json -Depth 8)

# --- optional presence hold ---
$l2Hold = $null
$holdSkipped = $skipHoldCfg
if (-not $skipHoldCfg) {
    if (-not $l2Online) {
        Write-Warning "Skipping presence-hold because client never became online."
        $holdSkipped = $true
    }
    else {
        Write-Host ("[urban-signalr-online-probe] presence-hold {0}s (live TTL risk window)..." -f $holdSec)
        Start-Sleep -Seconds $holdSec
        $hold = Invoke-HttpCapture -SinkDir $HttpDir -Name "client-list-after-hold" `
            -Method "GET" -Url $clientListUrl
        $after = Find-OnlineClient -JsonBody $hold.Body -ExpectedProId $expectedProId
        $l2Hold = ($null -ne $after)
        Write-Utf8NoBom (Join-Path $PrepareDir "presence-hold.json") ([ordered]@{
                holdSeconds   = $holdSec
                stillOnline   = $l2Hold
                expectedProId = $expectedProId
                matched       = $after
                at            = (Get-Date).ToString("o")
            } | ConvertTo-Json -Depth 8)
    }
}

$summary = [ordered]@{
    graph              = "urban/urban-signalr-online-probe"
    umBaseUrl          = $umBaseUrl
    urbanDiagnosticUrl = $urbanBaseUrl
    redis              = @{ host = $redisHost; port = $redisPort; reachable = $redisOk }
    expectedProId      = $expectedProId
    urbanReady         = $urbanReady
    levels             = [ordered]@{
        L0_redis          = $redisOk
        L0_hub_negotiate  = $l0Hub
        L0_urban_host     = $l0Urban
        L1_urban_settings = $l1Settings
        L2_client_online  = $l2Online
        L2_presence_hold  = $(if ($holdSkipped) { "skipped" } else { $l2Hold })
    }
    presenceHoldSkipped = $holdSkipped
    finishedAt          = (Get-Date).ToString("o")
}
Write-Utf8NoBom (Join-Path $RunDir "summary.json") ($summary | ConvertTo-Json -Depth 8)

$report = @"
# urban-signalr-online-probe report

- Run: ``$RunDir``
- UM: ``$umBaseUrl``
- Urban: ``$urbanBaseUrl``
- Redis: ``${redisHost}:${redisPort}`` reachable=$redisOk
- Expected ProId: ``$expectedProId``

| Level | Result |
|-------|--------|
| L0 Redis | $redisOk |
| L0 Hub negotiate | $l0Hub |
| L0 Urban GET / | $l0Urban |
| L1 Urban settings | $l1Settings |
| L2 Client online | $l2Online |
| L2 Presence hold | $(if ($holdSkipped) { "skipped" } else { $l2Hold }) |

## Notes

- BasePlatform not started; UM uses ``BasePlatformSync__Enabled=false``.
- Presence hold (when enabled) may fail with current product: Redis live TTL ~2× ClientTimeout and change-only UploadStatus.
- L3: confirm UM project management online badge manually.

## Agent

Do **not** mark L3 pass. User replies pass/fail on acceptance copy under this run if desired.
"@
Write-Utf8NoBom (Join-Path $RunDir "report.md") $report

Write-Host "[urban-signalr-online-probe] done. summary=$($RunDir)\summary.json"
Write-Host ($summary.levels | ConvertTo-Json -Compress)

$hardFail = (-not $redisOk) -or (-not $l0Hub) -or (-not $l0Urban) -or (-not $l1Settings) -or (-not $l2Online)
if ($hardFail) {
    exit 1
}
exit 0
