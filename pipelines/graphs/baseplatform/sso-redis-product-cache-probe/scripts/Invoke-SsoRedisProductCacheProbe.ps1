# experimental
# Probes SSO Redis AllTable/JCProduct for 5040/5041. Optional -Apply HDEL.
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
    # File uses JSONC (inline // comments). Extract RedisServer.Default by regex.
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
    # redis-cli may print WARNINGs on stderr mixed in
    $lines = @($text -split "`n" | Where-Object { $_ -notmatch '(?i)^Warning:' -and $_ -notmatch '(?i)using a password' })
    return [pscustomobject]@{
        ExitCode = $exit
        Text     = ($lines -join "`n").Trim()
    }
}

function Redact-Conn([string] $Conn) {
    if ([string]::IsNullOrEmpty($Conn)) { return '' }
    return [regex]::Replace($Conn, '(?i)password=[^,]+', 'password=***')
}

# --- resolve connection ---
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

$targetCodes = @('5040', '5041')
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
    runId          = $RunId
    apply          = [bool]$Apply
    connSource     = $connSource
    hostPort       = $redis.HostPort
    database       = $redis.Database
    hashKey        = $hashKey
    hashField      = $hashField
    allTableExists = $null
    fieldExists    = $null
    productCount   = $null
    sampleCodes    = @()
    targets        = @()
    deleted        = $null
    error          = $null
}

try {
    $existsKey = Invoke-RedisCli $redis.RedisHost $redis.Port $redis.Password $redis.Database @('EXISTS', $hashKey)
    if ($existsKey.ExitCode -ne 0) {
        throw "redis-cli EXISTS failed (exit $($existsKey.ExitCode)): $($existsKey.Text)"
    }
    $probe.allTableExists = ($existsKey.Text -eq '1')

    $hexists = Invoke-RedisCli $redis.RedisHost $redis.Port $redis.Password $redis.Database @('HEXISTS', $hashKey, $hashField)
    $probe.fieldExists = ($hexists.Text -eq '1')

    $products = @()
    if ($probe.fieldExists) {
        $hget = Invoke-RedisCli $redis.RedisHost $redis.Port $redis.Password $redis.Database @('HGET', $hashKey, $hashField)
        if ([string]::IsNullOrWhiteSpace($hget.Text)) {
            throw 'HGET returned empty JCProduct payload.'
        }
        # -InputObject avoids PS 5.1 nesting Object[] inside @()
        $parsed = ConvertFrom-Json -InputObject $hget.Text
        if ($null -eq $parsed) {
            throw 'JCProduct JSON parsed to null.'
        }
        $products = [System.Collections.Generic.List[object]]::new()
        foreach ($item in @($parsed)) {
            [void]$products.Add($item)
        }
        $probe.productCount = $products.Count
        $probe.sampleCodes = @(
            $products |
                ForEach-Object { [string]$_.ProductCode } |
                Sort-Object |
                Select-Object -First 20
        )

        foreach ($code in $targetCodes) {
            $hit = $null
            foreach ($item in $products) {
                if ([string]$item.ProductCode -eq $code) {
                    $hit = $item
                    break
                }
            }
            if ($null -eq $hit) {
                $probe.targets += [ordered]@{
                    productCode = $code
                    present     = $false
                }
            }
            else {
                $deleteStatus = $null
                if (@($hit.PSObject.Properties.Name) -contains 'DeleteStatus') {
                    $deleteStatus = $hit.DeleteStatus
                }
                $probe.targets += [ordered]@{
                    productCode   = $code
                    present       = $true
                    productName   = [string]$hit.ProductName
                    productType   = $hit.ProductType
                    organizeType  = $hit.OrganizeType
                    status        = $hit.Status
                    deleteStatus  = $deleteStatus
                }
            }
        }
    }
    else {
        foreach ($code in $targetCodes) {
            $probe.targets += [ordered]@{ productCode = $code; present = $false }
        }
    }

    if ($Apply) {
        $hdel = Invoke-RedisCli $redis.RedisHost $redis.Port $redis.Password $redis.Database @('HDEL', $hashKey, $hashField)
        $probe.deleted = ($hdel.Text -eq '1')
    }
}
catch {
    $probe.error = [string]$_.Exception.Message
}

$presentCount = @($probe.targets | Where-Object { $_.present -eq $true }).Length
$undeletedOk = $true
foreach ($t in @($probe.targets)) {
    if (-not $t.present) { $undeletedOk = $false; continue }
    if ($null -ne $t.deleteStatus -and [int]$t.deleteStatus -ne 0) { $undeletedOk = $false }
}

$p0 = ($null -eq $probe.error) -and ($probe.allTableExists -eq $true)
$p1 = $p0 -and ($probe.fieldExists -eq $true) -and ($null -ne $probe.productCount)
$p2 = $p1 -and ($presentCount -eq @($targetCodes).Length) -and $undeletedOk

$summary = [ordered]@{
    runId        = $RunId
    graph        = 'sso-redis-product-cache-probe'
    apply        = [bool]$Apply
    hostPort     = $redis.HostPort
    connSource   = $connSource
    productCount = $probe.productCount
    present5040  = [bool](@($probe.targets | Where-Object { $_.productCode -eq '5040' -and $_.present }).Length -gt 0)
    present5041  = [bool](@($probe.targets | Where-Object { $_.productCode -eq '5041' -and $_.present }).Length -gt 0)
    deleted      = $probe.deleted
    P0           = $p0
    P1           = $p1
    P2           = $p2
    P3           = $null
    error        = $probe.error
    message      = $(
        if ($probe.error) { $probe.error }
        elseif (-not $p0) { 'AllTable missing or Redis unreachable.' }
        elseif (-not $p1) { 'JCProduct field missing or unreadable.' }
        elseif (-not $p2) { 'Cache reachable, but 5040 and/or 5041 absent (stale cache vs FD_Base).' }
        else { 'Cache contains undeleted 5040 and 5041.' }
    )
}

$probesJson = ($probe | ConvertTo-Json -Depth 8)
$summaryJson = ($summary | ConvertTo-Json -Depth 6)
Write-Utf8 (Join-Path $RunDir 'prepare\probes.json') $probesJson
Write-Utf8 (Join-Path $RunDir 'summary.json') $summaryJson

$report = @"
# sso-redis-product-cache-probe — $RunId

| 项 | 值 |
|----|----|
| host | $($redis.HostPort) db=$($redis.Database) |
| source | $connSource (password redacted) |
| apply | $Apply |
| AllTable | $($probe.allTableExists) |
| JCProduct | $($probe.fieldExists) |
| productCount | $($probe.productCount) |
| 5040 | $($summary.present5040) |
| 5041 | $($summary.present5041) |
| HDEL | $($probe.deleted) |
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
graph: sso-redis-product-cache-probe
hostPort: $($redis.HostPort)
apply: $([bool]$Apply)
P0: $p0
P1: $p1
P2: $p2
"@
Write-Utf8 (Join-Path $RunDir 'manifest.yaml') $manifest

Write-Host "run=$RunId P0=$p0 P1=$p1 P2=$p2 present5040=$($summary.present5040) present5041=$($summary.present5041) count=$($probe.productCount)"
if ($probe.error) {
    Write-Error $probe.error
    exit 1
}
exit 0
