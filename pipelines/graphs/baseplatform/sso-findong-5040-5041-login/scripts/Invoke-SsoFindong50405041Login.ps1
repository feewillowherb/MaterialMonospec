# experimental
# Probes production SSO GetToken for products 5040 and 5041. Never logs password or token.
[CmdletBinding()]
param()

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

function Read-Products([string] $Text) {
    $matches = [regex]::Matches(
        $Text,
        '(?m)^\s+-\s+productCode:\s*(\d+)\s*[\r\n]+\s+productName:\s*"([^"]+)"\s*$')
    $products = @()
    foreach ($match in $matches) {
        $products += [pscustomobject]@{
            ProductCode = [int]$match.Groups[1].Value
            ProductName = [string]$match.Groups[2].Value
        }
    }
    return $products
}

function Redact-Message([string] $Text) {
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $value = $Text
    $value = $value -replace '(?i)(password|pwd|passWord)\s*[:=]\s*[^\s,;}"]+', '$1=***'
    if ($value.Length -gt 240) { return $value.Substring(0, 240) + '...' }
    return $value
}

function Invoke-GetToken(
    [string] $Url,
    [string] $UserName,
    [string] $PassWord,
    [int] $ProductCode,
    [int] $SwitchType,
    [int] $ProductType,
    [bool] $IsPlaintext
) {
    $bodyObj = [ordered]@{
        userName     = $UserName
        passWord     = $PassWord
        switchType   = $SwitchType
        productType  = $ProductType
        toProductIds = @($ProductCode)
        isPlaintext  = $IsPlaintext
    }
    $json = ($bodyObj | ConvertTo-Json -Compress)
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $bodyBytes = $utf8.GetBytes($json)
    $result = [ordered]@{
        productCode   = $ProductCode
        http          = $null
        code          = $null
        msg           = $null
        productId     = $null
        productName   = $null
        hasToken      = $false
        parse         = 'none'
        error         = $null
    }

    function Read-Utf8Body($ResponseOrWebResponse) {
        if ($null -eq $ResponseOrWebResponse) { return '' }
        # Prefer raw bytes + UTF-8. Windows PowerShell .Content often mis-decodes Chinese.
        if ($ResponseOrWebResponse.PSObject.Properties.Name -contains 'RawContentStream') {
            $stream = $ResponseOrWebResponse.RawContentStream
            if ($null -ne $stream) {
                if ($stream.CanSeek) { [void]$stream.Seek(0, [System.IO.SeekOrigin]::Begin) }
                $reader = New-Object System.IO.StreamReader($stream, $utf8, $true, 1024, $true)
                try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
            }
        }
        if ($ResponseOrWebResponse -is [System.Net.WebResponse]) {
            $stream = $ResponseOrWebResponse.GetResponseStream()
            if ($null -ne $stream) {
                $reader = New-Object System.IO.StreamReader($stream, $utf8, $true)
                try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
            }
        }
        return [string]$ResponseOrWebResponse.Content
    }

    function Fill-FromJson([string] $Raw) {
        $parsed = $Raw | ConvertFrom-Json
        $result.parse = 'json'
        if ($null -ne $parsed.code) { $result.code = [int]$parsed.code }
        if ($null -ne $parsed.msg) { $result.msg = [string]$parsed.msg }
        $data = $null
        if ($parsed.PSObject.Properties.Name -contains 'data') {
            $data = $parsed.data
        }
        if ($null -ne $data -and $data -isnot [string]) {
            $props = @($data.PSObject.Properties.Name)
            if ($props -contains 'productId') { $result.productId = $data.productId }
            elseif ($props -contains 'ProductId') { $result.productId = $data.ProductId }
            if ($props -contains 'productName') { $result.productName = [string]$data.productName }
            elseif ($props -contains 'ProductName') { $result.productName = [string]$data.ProductName }
            $token = $null
            if ($props -contains 'token') { $token = [string]$data.token }
            elseif ($props -contains 'Token') { $token = [string]$data.Token }
            $result.hasToken = -not [string]::IsNullOrWhiteSpace($token)
        }
    }

    try {
        $response = Invoke-WebRequest -Uri $Url -Method POST -Body $bodyBytes -ContentType 'application/json; charset=utf-8' -UseBasicParsing -TimeoutSec 30
        $result.http = [int]$response.StatusCode
        $raw = Read-Utf8Body $response
        try {
            Fill-FromJson $raw
        }
        catch {
            if ($null -eq $result.code) {
                $result.parse = 'non-json'
                $result.error = 'Response body is not JSON.'
            }
            else {
                $result.parse = 'json'
                $result.error = Redact-Message ([string]$_.Exception.Message)
            }
        }
    }
    catch {
        $ex = $_.Exception
        $result.error = Redact-Message ([string]$ex.Message)
        $webResponse = $null
        if ($null -ne $_.Exception.Response) { $webResponse = $_.Exception.Response }
        if ($null -ne $webResponse) {
            try { $result.http = [int]$webResponse.StatusCode } catch { }
            try {
                $rawErr = Read-Utf8Body $webResponse
                if (-not [string]::IsNullOrWhiteSpace($rawErr)) {
                    Fill-FromJson $rawErr
                    $result.error = $null
                }
            }
            catch { }
        }
    }
    return [pscustomobject]$result
}

$summary = [ordered]@{
    graphId       = 'sso-findong-5040-5041-login'
    graphPath     = 'pipelines/graphs/baseplatform/sso-findong-5040-5041-login'
    runId         = $RunId
    result        = 'unknown'
    baseUrl       = $null
    accountMasked = $null
    productType   = $null
    p0            = $false
    p1            = $false
    p2            = $false
    products      = @()
    message       = $null
}

try {
    if (Test-Path -LiteralPath $RunDir) { throw "Run directory already exists: $RunId" }
    New-Item -ItemType Directory -Path (Join-Path $RunDir 'prepare') | Out-Null

    if (-not (Test-Path -LiteralPath $SecretsPath)) {
        throw 'Missing secrets.local.yaml (copy from secrets.example.yaml).'
    }
    $configText = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
    $secretText = Get-Content -LiteralPath $SecretsPath -Raw -Encoding UTF8
    $userName = Read-YamlScalar $secretText 'userName'
    $passWord = Read-YamlScalar $secretText 'passWord'
    if ([string]::IsNullOrWhiteSpace($userName) -or [string]::IsNullOrWhiteSpace($passWord)) {
        throw 'secrets.local.yaml must set userName and passWord.'
    }

    $baseUrl = (Read-YamlScalar $configText 'baseUrl').TrimEnd('/')
    $path = Read-YamlScalar $configText 'path'
    if ([string]::IsNullOrWhiteSpace($path)) { $path = '/GetToken' }
    if (-not $path.StartsWith('/')) { $path = '/' + $path }
    $url = $baseUrl + $path
    $switchType = [int](Read-YamlScalar $configText 'switchType')
    $productType = [int](Read-YamlScalar $configText 'productType')
    $wrongPassword = Read-YamlScalar $configText 'wrongPassword'
    if ([string]::IsNullOrWhiteSpace($wrongPassword)) { $wrongPassword = '__probe_wrong_password__' }
    $products = @(Read-Products $configText)
    if ($products.Count -ne 2) { throw 'config must list exactly two products.' }

    $summary.baseUrl = $baseUrl
    $summary.productType = $productType
    if ($userName.Length -ge 4) {
        $summary.accountMasked = ('*' * ($userName.Length - 4)) + $userName.Substring($userName.Length - 4)
    }
    else {
        $summary.accountMasked = '****'
    }

    $probes = @()
    $anyJson = $false
    $allWrongRejected = $true
    $allMatchOk = $true

    foreach ($product in $products) {
        $wrong = Invoke-GetToken $url $userName $wrongPassword $product.ProductCode $switchType $productType $true
        $match = Invoke-GetToken $url $userName $passWord $product.ProductCode $switchType $productType $true
        if ($wrong.parse -eq 'json' -or $match.parse -eq 'json') { $anyJson = $true }
        if ($wrong.hasToken) { $allWrongRejected = $false }
        $productIdOk = $false
        if ($null -ne $match.productId) {
            $productIdOk = ([string]$match.productId -eq [string]$product.ProductCode)
        }
        $nameOk = $true
        if (-not [string]::IsNullOrWhiteSpace([string]$match.productName)) {
            $nameOk = ([string]$match.productName -eq $product.ProductName)
        }
        $ok = ($match.code -eq 200) -and $match.hasToken -and $productIdOk
        if (-not $ok) { $allMatchOk = $false }

        $entry = [ordered]@{
            productCode     = $product.ProductCode
            expectedName    = $product.ProductName
            wrongPassword   = $wrong
            matchingPassword = $match
            loginOk         = $ok
            nameMatched     = $nameOk
        }
        $probes += $entry
        $summary.products += [ordered]@{
            productCode = $product.ProductCode
            loginOk     = $ok
            wrongCode   = $wrong.code
            matchCode   = $match.code
            hasToken    = $match.hasToken
            msg         = $match.msg
        }
    }

    $summary.p0 = $anyJson
    $summary.p1 = $anyJson -and $allWrongRejected
    $summary.p2 = $summary.p1 -and $allMatchOk
    $summary.result = if ($summary.p2) { 'pass' } else { 'fail' }
    if ($summary.p2) {
        $summary.message = 'Both products returned code 200 with a token.'
    }
    elseif (-not $summary.p0) {
        $summary.message = 'SSO GetToken was not reachable or not JSON.'
    }
    else {
        $summary.message = 'Reachable, but one or more product logins failed. Check authority, roles, Redis product cache, and ProductType.'
    }

    Write-Utf8 (Join-Path $RunDir 'prepare\probes.json') ([ordered]@{
        baseUrl     = $baseUrl
        path        = $path
        productType = $productType
        switchType  = $switchType
        probes      = $probes
    } | ConvertTo-Json -Depth 8)
}
catch {
    $summary.result = 'fail'
    $summary.message = Redact-Message ([string]$_.Exception.Message)
}
finally {
    Write-Utf8 (Join-Path $RunDir 'summary.json') ($summary | ConvertTo-Json -Depth 8)
    $lines = @(
        '# sso-findong-5040-5041-login'
        ''
        "- runId: ``$RunId``"
        "- result: ``$($summary.result)``"
        "- baseUrl: ``$($summary.baseUrl)``"
        "- account: ``$($summary.accountMasked)``"
        "- productType: ``$($summary.productType)``"
        "- P0: ``$($summary.p0)``"
        "- P1: ``$($summary.p1)``"
        "- P2: ``$($summary.p2)``"
        "- message: $($summary.message)"
        ''
    )
    foreach ($p in @($summary.products)) {
        $lines += "- product $($p.productCode): loginOk=$($p.loginOk) matchCode=$($p.matchCode) hasToken=$($p.hasToken) msg=$($p.msg)"
    }
    $lines += ''
    $lines += 'P3 stays with the user. Tokens and passwords are not stored in this report.'
    Write-Utf8 (Join-Path $RunDir 'report.md') (($lines -join "`r`n") + "`r`n")
    $rev = ''
    try { $rev = (& git -C $RepoRoot rev-parse --short HEAD) } catch { $rev = '' }
    $manifest = @"
graphId: $($summary.graphId)
graphPath: $($summary.graphPath)
runId: $RunId
result: $($summary.result)
gitRevision: "$rev"
contractPath: pipelines/graphs/baseplatform/sso-findong-5040-5041-login/contract.yaml
artifacts:
  - prepare/probes.json
  - summary.json
  - report.md
  - manifest.yaml
"@
    Write-Utf8 (Join-Path $RunDir 'manifest.yaml') $manifest
}

if ($summary.result -ne 'pass') {
    Write-Error $summary.message
    exit 1
}

Write-Output "result=$($summary.result) p0=$($summary.p0) p1=$($summary.p1) p2=$($summary.p2) runId=$RunId"
exit 0
