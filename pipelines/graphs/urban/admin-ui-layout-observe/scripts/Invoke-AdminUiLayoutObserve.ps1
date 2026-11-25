# experimental: prepare runs/<ts>/, Redis+GetToken on 135, Admin cookie preflight on 138.
# Browser page-walk is completed by the Agent via cursor-ide-browser per pipeline.md.
[CmdletBinding()]
param(
    [switch] $SkipConfirm,
    [switch] $RefreshProductCache
)

$ErrorActionPreference = "Stop"
$GraphDir = Split-Path $PSScriptRoot -Parent
$RepoRoot = (Resolve-Path (Join-Path $GraphDir "..\..\..\..")).Path

function Read-YamlScalar([string] $Text, [string] $Key) {
    if ($Text -match "(?m)^\s*$([regex]::Escape($Key)):\s*(.*?)\s*$") {
        return $Matches[1].Trim().Trim('"').Trim("'")
    }
    return $null
}

function Get-RedisConnectionFromAppsettings([string] $Path, [string] $Section, [string] $Key) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "SSO appsettings not found: $Path" }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $sectionMatch = [regex]::Match($raw, '(?s)"' + [regex]::Escape($Section) + '"\s*:\s*\{(?<body>.*?)\}')
    if (-not $sectionMatch.Success) { throw "Missing section $Section in $Path" }
    $keyMatch = [regex]::Match($sectionMatch.Groups['body'].Value, '"' + [regex]::Escape($Key) + '"\s*:\s*"(?<val>[^"]+)"')
    if (-not $keyMatch.Success) { throw "Missing $Section.$Key in $Path" }
    return [string]$keyMatch.Groups['val'].Value
}

function Parse-RedisConnection([string] $Raw) {
    $hostPort = ($Raw -split ',')[0].Trim()
    if ($hostPort -notmatch '^([^:]+):(\d+)$') {
        throw "Cannot parse host:port from Redis connection: $hostPort"
    }
    $redisHostName = $Matches[1]
    $port = [int]$Matches[2]
    $password = $null
    $db = 0
    if ($Raw -match '(?i)password=([^,]+)') { $password = $Matches[1].Trim().Trim('"') }
    if ($Raw -match '(?i)defaultDatabase=(\d+)') { $db = [int]$Matches[1] }
    return [pscustomobject]@{ RedisHost = $redisHostName; Port = $port; Password = $password; Database = $db; HostPort = $hostPort }
}

function Invoke-RedisCli($Redis, [string[]] $Args) {
    $cliArgs = @('-h', $Redis.RedisHost, '-p', "$($Redis.Port)", '--no-auth-warning')
    if ($Redis.Password) { $cliArgs += @('-a', $Redis.Password) }
    if ($null -ne $Redis.Database) { $cliArgs += @('-n', "$($Redis.Database)") }
    $cliArgs += $Args
    $output = & redis-cli @cliArgs 2>&1
    return ($output | Out-String).Trim()
}

$configPath = Join-Path $GraphDir "config.yaml"
$secretsPath = Join-Path $GraphDir "secrets.local.yaml"
$configText = Get-Content -LiteralPath $configPath -Raw
$secretsText = if (Test-Path -LiteralPath $secretsPath) { Get-Content -LiteralPath $secretsPath -Raw } else { "" }

$baseUrl = Read-YamlScalar $configText 'baseUrl'
$ssoBaseUrl = Read-YamlScalar $configText 'ssoBaseUrl'
$userName = Read-YamlScalar $configText 'userName'
$webProductCode = [int](Read-YamlScalar $configText 'webProductCode')
$loginMethod = Read-YamlScalar $configText 'loginMethod'
$environment = Read-YamlScalar $configText 'environment'

if ($secretsText) {
    $o = Read-YamlScalar $secretsText 'baseUrl'; if ($o) { $baseUrl = $o }
    $o = Read-YamlScalar $secretsText 'ssoBaseUrl'; if ($o) { $ssoBaseUrl = $o }
    $o = Read-YamlScalar $secretsText 'userName'; if ($o) { $userName = $o }
}
$passWord = Read-YamlScalar $secretsText 'passWord'
$refreshCache = $RefreshProductCache
if ((Read-YamlScalar $secretsText 'refreshProductCache') -eq 'true') { $refreshCache = $true }

if (-not $SkipConfirm -and $environment -eq 'shared') {
    Write-Host "[admin-ui-layout-observe] environment=shared baseUrl=$baseUrl sso=$ssoBaseUrl user=$userName method=$loginMethod"
    Write-Host "Re-run with -SkipConfirm after shared-environment gate, or let Agent continue cook."
}

if ([string]::IsNullOrEmpty($passWord)) {
    throw "missing-secrets: passWord required in secrets.local.yaml for redis-session login."
}

$runId = Get-Date -Format "yyyy-MM-ddTHHmmss"
$runDir = Join-Path $GraphDir "runs\$runId"
if (Test-Path -LiteralPath $runDir) { throw "Run directory already exists: $runDir" }

foreach ($d in @('screenshots', 'snapshots', 'logs', 'prepare')) {
    New-Item -ItemType Directory -Path (Join-Path $runDir $d) -Force | Out-Null
}

$redisLogin = [ordered]@{
    runId = $runId
    loginMethod = $loginMethod
    baseUrl = $baseUrl
    ssoBaseUrl = $ssoBaseUrl
    userName = $userName
    webProductCode = $webProductCode
    redisHostPort = $null
    redisPing = $null
    productCacheHexistsBefore = $null
    productCacheHdel = $null
    getTokenHttp = $null
    getTokenCode = $null
    getTokenHasToken = $false
    getTokenMsg = $null
    adminLoginHttp = $null
    adminHasSessionCookie = $false
    error = $null
}

try {
    $appRel = Read-YamlScalar $configText 'redisAppsettingsRel'
    if ([string]::IsNullOrEmpty($appRel)) { $appRel = '.local/SSO/appsettings.json' }
    $connOverride = Read-YamlScalar $secretsText 'redisConnection'
    $connRaw = if ($connOverride) { $connOverride } else {
        Get-RedisConnectionFromAppsettings (Join-Path $RepoRoot ($appRel -replace '/', '\')) 'RedisServer' 'Default'
    }
    $redis = Parse-RedisConnection $connRaw
    $redisLogin.redisHostPort = $redis.HostPort

    $redisLogin.redisPing = Invoke-RedisCli $redis @('PING')
    $redisLogin.productCacheHexistsBefore = Invoke-RedisCli $redis @('HEXISTS', 'AllTable', 'JCProduct')
    if ($refreshCache) {
        $redisLogin.productCacheHdel = Invoke-RedisCli $redis @('HDEL', 'AllTable', 'JCProduct')
    }

    $clientId = [guid]::NewGuid().ToString()
    $bodyObj = @{
        UserName     = $userName
        PassWord     = $passWord
        SwitchType   = 0
        ProductType  = 2
        ToProductIds = @($webProductCode)
        ClientId     = $clientId
    }
    $bodyJson = $bodyObj | ConvertTo-Json -Compress
    $tokenUrl = ($ssoBaseUrl.TrimEnd('/') + '/GetToken')
    $tokenResp = Invoke-WebRequest -Uri $tokenUrl -Method POST -Body $bodyJson -ContentType 'application/json; charset=utf-8' -UseBasicParsing -TimeoutSec 30
    $redisLogin.getTokenHttp = [int]$tokenResp.StatusCode
    $tokenJson = $tokenResp.Content | ConvertFrom-Json
    $redisLogin.getTokenCode = $tokenJson.code
    $redisLogin.getTokenMsg = [string]$tokenJson.msg
    $redisLogin.getTokenHasToken = $null -ne $tokenJson.data -and -not [string]::IsNullOrEmpty([string]$tokenJson.data.token) `
        -or ($null -ne $tokenJson.data -and -not [string]::IsNullOrEmpty([string]$tokenJson.data.Token))

    # Admin cookie: form POST (Anti-forgery may block; record result for Agent).
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    try {
        $loginGet = Invoke-WebRequest -Uri ($baseUrl.TrimEnd('/') + '/login') -Method GET -WebSession $session -UseBasicParsing -TimeoutSec 30
        $form = @{
            UserName = $userName
            Password = $passWord
            CaptchaKey = ''
            CaptchaCode = ''
        }
        $loginPost = Invoke-WebRequest -Uri ($baseUrl.TrimEnd('/') + '/login') -Method POST -Body $form -WebSession $session -UseBasicParsing -TimeoutSec 30 -MaximumRedirection 0 -ErrorAction SilentlyContinue
        if (-not $loginPost -and $Error[0].Exception.Response) {
            $loginPost = [pscustomobject]@{ StatusCode = [int]$Error[0].Exception.Response.StatusCode }
        }
        $redisLogin.adminLoginHttp = if ($loginPost) { [int]$loginPost.StatusCode } else { 'error' }
    } catch {
        $redisLogin.adminLoginHttp = 'error'
        $redisLogin.error = $_.Exception.Message
    }
    $cookie = $session.Cookies.GetCookies($baseUrl) | Where-Object { $_.Name -eq 'UrbanAdmin.Session' }
    $redisLogin.adminHasSessionCookie = $null -ne $cookie
}
catch {
    $redisLogin.error = $_.Exception.Message
}

$redisLogin | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runDir "prepare\redis-login.json") -Encoding utf8

$readyHttp = $null; $liveHttp = $null
try { $readyHttp = [int](Invoke-WebRequest -Uri ($baseUrl.TrimEnd('/') + '/health/ready') -UseBasicParsing -TimeoutSec 15).StatusCode } catch { $readyHttp = 'error' }
try { $liveHttp = [int](Invoke-WebRequest -Uri ($baseUrl.TrimEnd('/') + '/health/live') -UseBasicParsing -TimeoutSec 15).StatusCode } catch { $liveHttp = 'error' }

@{
    readyHttp = $readyHttp
    liveHttp = $liveHttp
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDir "prepare\preflight.json") -Encoding utf8

$cookList = @"
# Cook checklist — admin-ui-layout-observe
runId: $runId
baseUrl: $baseUrl
ssoBaseUrl: $ssoBaseUrl
userName: $userName
loginMethod: redis-session

1. Confirm prepare/redis-login.json: getTokenHasToken + redisPing
2. If adminHasSessionCookie=false, Agent browser: open /login, submit userName+passWord (captcha gate if needed)
3. Capture shell → screenshots/shell.png + snapshots/shell.yaml
4. Walk eight routes from config.yaml target.routes
5. Spot-check weighing/projects; optional readonly dialog
6. Write summary.json + report.md; do NOT declare P3 / product APPROVED

Forbidden clicks: 通过, 驳回, 启用同步, 退出 (submit)
Never write passWord or Token into report.md
"@
Set-Content -LiteralPath (Join-Path $runDir "prepare\cook-checklist.md") -Value $cookList -Encoding utf8
Copy-Item -LiteralPath (Join-Path $GraphDir "acceptance.md") -Destination (Join-Path $runDir "acceptance.md") -Force

$p0 = ($redisLogin.redisPing -match 'PONG') -and ($redisLogin.getTokenHasToken -eq $true)
$summary = [ordered]@{
    runId = $runId
    result = $(if ($p0) { 'prepared' } else { 'prepared-with-login-gap' })
    mode = 'observe-prepare'
    baseUrl = $baseUrl
    ssoBaseUrl = $ssoBaseUrl
    userName = $userName
    loginMethod = $loginMethod
    levels = @{
        P0 = $p0
        P1 = $false
        P2 = $false
        P3 = 'user-only'
    }
    note = 'Invoke prepared Redis/GetToken preflight; Agent completes browser walk.'
    adminHasSessionCookie = $redisLogin.adminHasSessionCookie
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runDir "summary.json") -Encoding utf8

Write-Host "[admin-ui-layout-observe] prepared $runDir"
Write-Host "[admin-ui-layout-observe] redisPing=$($redisLogin.redisPing) getTokenHasToken=$($redisLogin.getTokenHasToken) adminCookie=$($redisLogin.adminHasSessionCookie)"
exit 0
