# experimental
# Invalidates SSO Redis AllTable/JCProduct on 127 (from .local SSO appsettings).
# Default dry-run; -Apply performs HDEL. Does not HSET rebuild.
# Redis password never written to evidence.
[CmdletBinding()]
param(
    [switch] $Apply
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$ConfigPath = Join-Path $GraphRoot 'config.yaml'
$SecretsPath = Join-Path $GraphRoot 'secrets.local.yaml'
$RunId = Get-Date -Format 'yyyy-MM-ddTHHmmss'
$RunDir = Join-Path $GraphRoot (Join-Path 'runs' $RunId)

function Write-Utf8([string] $Path, [string] $Content) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Read-YamlScalar([string] $Text, [string] $Key) {
    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + ':\s*"?([^"#\r\n]+?)"?\s*$'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim()
}

function Parse-RedisConnection([string] $Conn) {
    if ([string]::IsNullOrWhiteSpace($Conn)) {
        throw 'Redis connection string is empty.'
    }
    $hostPort = ($Conn -split ',')[0].Trim()
    if ($hostPort -notmatch '^([^:]+):(\d+)$') {
        throw "Cannot parse host:port from Redis connection: $($hostPort.Substring(0, [Math]::Min(40, $hostPort.Length)))"
    }
    $redisHost = $Matches[1]
    $port = [int]$Matches[2]
    $password = $null
    $db = 0
    if ($Conn -match '(?i)password=([^,]+)') { $password = $Matches[1].Trim() }
    if ($Conn -match '(?i)defaultDatabase=(\d+)') { $db = [int]$Matches[1] }
    return [pscustomobject]@{
        RedisHost = $redisHost
        Port      = $port
        Password  = $password
        Database  = $db
        HostPort  = $hostPort
    }
}

function Get-RedisConnectionFromAppsettings([string] $Path, [string] $Section, [string] $Key) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "SSO appsettings not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $sectionPattern = '(?s)"' + [regex]::Escape($Section) + '"\s*:\s*\{(?<body>.*?)\}'
    $sectionMatch = [regex]::Match($raw, $sectionPattern)
    if (-not $sectionMatch.Success) {
        throw "Missing section $Section in $Path"
    }
    $body = $sectionMatch.Groups['body'].Value
    $keyPattern = '"' + [regex]::Escape($Key) + '"\s*:\s*"(?<val>[^"]+)"'
    $keyMatch = [regex]::Match($body, $keyPattern)
    if (-not $keyMatch.Success) {
        throw "Missing $Section.$Key in $Path"
    }
    return [string]$keyMatch.Groups['val'].Value
}

function Invoke-RedisCli(
    [string] $HostName,
    [int] $Port,
    [string] $Password,
    [int] $Database,
    [string[]] $RedisArgs
) {
    $cliArgs = @('-h', $HostName, '-p', $Port, '-n', $Database)
    if (-not [string]::IsNullOrEmpty($Password)) {
        $cliArgs += @('-a', $Password)
    }
    $cliArgs += @('--raw')
    $cliArgs += $RedisArgs
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & redis-cli @cliArgs 2>&1
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prev
    $text = ($output | ForEach-Object { "$_" }) -join "`n"
    $lines = @($text -split "`n" | Where-Object {
            $_ -notmatch '(?i)^Warning:' -and $_ -notmatch '(?i)using a password'
        })
    return [pscustomobject]@{
        ExitCode = $exit
        Text     = ($lines -join "`n").Trim()
    }
}

function Redact-Conn([string] $Conn) {
    if ([string]::IsNullOrEmpty($Conn)) { return '' }
    return [regex]::Replace($Conn, '(?i)password=[^,]+', 'password=***')
}

function Get-ProductSummary([string] $JsonText) {
    $summary = [ordered]@{
        productCount = $null
        present5040  = $false
        present5041  = $false
        sampleCodes  = @()
    }
    if ([string]::IsNullOrWhiteSpace($JsonText)) { return $summary }
    $parsed = ConvertFrom-Json -InputObject $JsonText
    $products = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($parsed)) {
        [void]$products.Add($item)
    }
    $summary.productCount = $products.Count
    $codes = New-Object System.Collections.Generic.List[string]
    foreach ($item in $products) {
        $code = [string]$item.ProductCode
        [void]$codes.Add($code)
        if ($code -eq '5040') { $summary.present5040 = $true }
        if ($code -eq '5041') { $summary.present5041 = $true }
    }
    $summary.sampleCodes = @($codes | Sort-Object | Select-Object -First 20)
    return $summary
}

# --- resolve ---
$configText = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
$hashKey = Read-YamlScalar $configText 'hashKey'
$hashField = Read-YamlScalar $configText 'hashField'
$appsettingsRel = Read-YamlScalar $configText 'redisAppsettingsRel'
$redisSection = Read-YamlScalar $configText 'redisSection'
$redisKey = Read-YamlScalar $configText 'redisKey'
if ([string]::IsNullOrEmpty($hashKey)) { $hashKey = 'AllTable' }
if ([string]::IsNullOrEmpty($hashField)) { $hashField = 'JCProduct' }
if ([string]::IsNullOrEmpty($appsettingsRel)) { $appsettingsRel = '.local/SSO/appsettings.json' }
if ([string]::IsNullOrEmpty($redisSection)) { $redisSection = 'RedisServer' }
if ([string]::IsNullOrEmpty($redisKey)) { $redisKey = 'Default' }

$connSource = 'appsettings'
$connRaw = $null
if (Test-Path -LiteralPath $SecretsPath) {
    $secretsText = Get-Content -LiteralPath $SecretsPath -Raw -Encoding UTF8
    $override = Read-YamlScalar $secretsText 'redisConnection'
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        $connRaw = $override
        $connSource = 'secrets.local.yaml'
    }
}
if ([string]::IsNullOrEmpty($connRaw)) {
    $appPath = Join-Path $RepoRoot $appsettingsRel
    $connRaw = Get-RedisConnectionFromAppsettings $appPath $redisSection $redisKey
}

$redis = Parse-RedisConnection $connRaw
New-Item -ItemType Directory -Path (Join-Path $RunDir 'prepare') -Force | Out-Null

$probe = [ordered]@{
    runId            = $RunId
    apply            = [bool]$Apply
    connSource       = $connSource
    hostPort         = $redis.HostPort
    database         = $redis.Database
    hashKey          = $hashKey
    hashField        = $hashField
    ping             = $null
    fieldExistsBefore = $null
    productCountBefore = $null
    present5040Before = $null
    present5041Before = $null
    sampleCodesBefore = @()
    hdelResult       = $null
    fieldExistsAfter = $null
    error            = $null
}

try {
    $ping = Invoke-RedisCli $redis.RedisHost $redis.Port $redis.Password $redis.Database @('PING')
    if ($ping.Text -ne 'PONG') {
        throw "Redis PING failed: $($ping.Text)"
    }
    $probe.ping = 'PONG'

    $hexBefore = Invoke-RedisCli $redis.RedisHost $redis.Port $redis.Password $redis.Database @(
        'HEXISTS', $hashKey, $hashField
    )
    $probe.fieldExistsBefore = ($hexBefore.Text -eq '1')

    if ($probe.fieldExistsBefore) {
        $hget = Invoke-RedisCli $redis.RedisHost $redis.Port $redis.Password $redis.Database @(
            'HGET', $hashKey, $hashField
        )
        $before = Get-ProductSummary $hget.Text
        $probe.productCountBefore = $before.productCount
        $probe.present5040Before = $before.present5040
        $probe.present5041Before = $before.present5041
        $probe.sampleCodesBefore = $before.sampleCodes
    }

    if ($Apply) {
        $hdel = Invoke-RedisCli $redis.RedisHost $redis.Port $redis.Password $redis.Database @(
            'HDEL', $hashKey, $hashField
        )
        # 1 = deleted, 0 = already absent
        $probe.hdelResult = $hdel.Text
        $hexAfter = Invoke-RedisCli $redis.RedisHost $redis.Port $redis.Password $redis.Database @(
            'HEXISTS', $hashKey, $hashField
        )
        $probe.fieldExistsAfter = ($hexAfter.Text -eq '1')
    }
}
catch {
    $probe.error = [string]$_.Exception.Message
}

$p0 = ($null -eq $probe.error) -and ($probe.ping -eq 'PONG')
$p1 = $p0 -and ($(if ($Apply) { $null -ne $probe.hdelResult } else { $true }))
$p2 = $Apply -and $p1 -and ($probe.fieldExistsAfter -eq $false)

$summary = [ordered]@{
    runId              = $RunId
    graph              = 'sso-redis-product-cache-refresh'
    apply              = [bool]$Apply
    hostPort           = $redis.HostPort
    connSource         = $connSource
    fieldExistsBefore  = $probe.fieldExistsBefore
    productCountBefore = $probe.productCountBefore
    present5040Before  = $probe.present5040Before
    present5041Before  = $probe.present5041Before
    hdelResult         = $probe.hdelResult
    fieldExistsAfter   = $probe.fieldExistsAfter
    P0                 = $p0
    P1                 = $p1
    P2                 = $p2
    P3                 = $null
    error              = $probe.error
    message            = $(
        if ($probe.error) { $probe.error }
        elseif (-not $Apply) {
            "Dry-run only. JCProduct exists=$($probe.fieldExistsBefore) count=$($probe.productCountBefore). Re-run with -Apply to HDEL."
        }
        elseif ($p2) {
            'HDEL done; JCProduct field gone. Next GetToken will rebuild from FD_Base.'
        }
        else {
            'Apply ran but JCProduct field still present.'
        }
    )
}

Write-Utf8 (Join-Path $RunDir 'prepare\probes.json') ($probe | ConvertTo-Json -Depth 8)
Write-Utf8 (Join-Path $RunDir 'summary.json') ($summary | ConvertTo-Json -Depth 6)

$report = @"
# sso-redis-product-cache-refresh — $RunId

| 项 | 值 |
|----|----|
| host | $($redis.HostPort) db=$($redis.Database) |
| source | $connSource |
| apply | $Apply |
| before HEXISTS | $($probe.fieldExistsBefore) |
| before count | $($probe.productCountBefore) |
| before 5040/5041 | $($probe.present5040Before) / $($probe.present5041Before) |
| HDEL | $($probe.hdelResult) |
| after HEXISTS | $($probe.fieldExistsAfter) |
| P0 | $p0 |
| P1 | $p1 |
| P2 | $p2 |
| P3 | pending (user only) |

summary: $($summary.message)

conn: $(Redact-Conn $connRaw)
"@
Write-Utf8 (Join-Path $RunDir 'report.md') $report

$manifest = @"
id: $RunId
graph: sso-redis-product-cache-refresh
hostPort: $($redis.HostPort)
apply: $([bool]$Apply)
P0: $p0
P1: $p1
P2: $p2
"@
Write-Utf8 (Join-Path $RunDir 'manifest.yaml') $manifest

Write-Host "run=$RunId apply=$Apply P0=$p0 P1=$p1 P2=$p2 existsBefore=$($probe.fieldExistsBefore) hdel=$($probe.hdelResult) existsAfter=$($probe.fieldExistsAfter)"
if ($probe.error) {
    Write-Error $probe.error
    exit 1
}
exit 0
