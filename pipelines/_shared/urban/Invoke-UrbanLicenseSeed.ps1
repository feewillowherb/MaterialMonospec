#Requires -Version 5.1
<#
.SYNOPSIS
  Shared: seed MaterialClient.Urban demo license before or during diagnostic runs.
.DESCRIPTION
  Local mode (default): writes license.urban and upserts LicenseInfo in MaterialClient.db via Node/TS upsert-license-info.
  Api mode: POST /api/license/seed when the diagnostic host is already running.

  License seeds live under seeds/*.json (default: seeds/demo-license.json).
  Local mode patches machineCode to this PC before upsert; Debug builds also skip JWT machineCode mismatch at startup.
#>

function Get-UrbanLocalMachineCode {
    $cpu = ""
    $board = ""
    $mac = ""
    try {
        $cpu = [string](Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty ProcessorId)
    }
    catch {
        $cpu = [string][Environment]::ProcessorCount
    }
    try {
        $board = [string](Get-CimInstance Win32_BaseBoard | Select-Object -First 1 -ExpandProperty SerialNumber)
    }
    catch {
        $board = [Environment]::MachineName
    }
    try {
        $mac = [string](Get-CimInstance Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" |
            Select-Object -First 1 -ExpandProperty MACAddress)
    }
    catch {
        $mac = [Environment]::UserName
    }

    $combined = "{0}-{1}-{2}" -f $cpu, $board, $mac
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($combined))
    return -join ($hash | ForEach-Object { $_.ToString("x2") })
}

function Write-UrbanUtf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-UrbanYamlScalar {
    param([string] $Text, [string] $Key)
    $pattern = '(?m)^\s{2}' + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        if ($v.StartsWith('"') -and $v.EndsWith('"')) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        return $v
    }
    return $null
}

function Get-UrbanSecretsScalar {
    param([string] $Text, [string] $Key)
    $pattern = '(?m)^' + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v.StartsWith('"') -and $v.EndsWith('"')) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        return $v
    }
    return $null
}

function Resolve-UrbanDiagnosticBaseUrl {
    param(
        [string] $GraphRoot,
        [string] $DefaultBaseUrl = "http://localhost:9961"
    )
    $configPath = Join-Path $GraphRoot "config.yaml"
    $secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
    $baseUrl = $DefaultBaseUrl

    if (Test-Path -LiteralPath $configPath) {
        $configText = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
        $fromConfig = Get-UrbanYamlScalar -Text $configText -Key "baseUrl"
        if (-not [string]::IsNullOrWhiteSpace($fromConfig)) {
            $baseUrl = $fromConfig.Trim()
        }
    }

    if (Test-Path -LiteralPath $secretsPath) {
        $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
        $fromSecrets = Get-UrbanSecretsScalar -Text $secretsText -Key "baseUrl"
        if (-not [string]::IsNullOrWhiteSpace($fromSecrets)) {
            $baseUrl = $fromSecrets.Trim()
        }
    }

    return $baseUrl.TrimEnd('/')
}

function Resolve-UrbanDemoLicenseSeedPath {
    param([string] $SharedRoot, [string] $SeedRelPath = "seeds/demo-license.json")
    $seedPath = Join-Path $SharedRoot $SeedRelPath
    if (-not (Test-Path -LiteralPath $seedPath)) {
        throw "Missing demo license seed: $seedPath"
    }

    return @{
        Path    = (Resolve-Path -LiteralPath $seedPath).Path
        RelPath = $SeedRelPath
    }
}

function Read-UrbanDemoLicenseSeed {
    param([string] $SharedRoot, [string] $SeedRelPath = "seeds/demo-license.json")
    $seed = Resolve-UrbanDemoLicenseSeedPath -SharedRoot $SharedRoot -SeedRelPath $SeedRelPath
    $json = [System.IO.File]::ReadAllText($seed.Path, [System.Text.Encoding]::UTF8)
    $license = $json | ConvertFrom-Json
    if ($null -eq $license) {
        throw "Demo license seed is empty: $($seed.Path)"
    }

    return @{
        Path    = $seed.Path
        RelPath = $seed.RelPath
        License = $license
    }
}

function Resolve-UrbanPipelinesRoot {
    param([string] $SharedRoot)
    $pipelinesRoot = Join-Path $SharedRoot "../.."
    if (-not (Test-Path -LiteralPath $pipelinesRoot)) {
        throw "Missing pipelines root: $pipelinesRoot"
    }

    return (Resolve-Path -LiteralPath $pipelinesRoot).Path
}

function Resolve-UrbanUpsertLicenseInfoScript {
    param([string] $SharedRoot)
    $scriptPath = Join-Path $SharedRoot "tools/upsert-license-info/upsert-license-info.ts"
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Missing upsert-license-info script: $scriptPath"
    }

    return (Resolve-Path -LiteralPath $scriptPath).Path
}

function Ensure-UrbanPipelinesNodeModules {
    param([string] $PipelinesRoot)

    $nodeModules = Join-Path $PipelinesRoot "node_modules"
    if (Test-Path -LiteralPath $nodeModules) {
        return
    }

    $packageJson = Join-Path $PipelinesRoot "package.json"
    if (-not (Test-Path -LiteralPath $packageJson)) {
        throw "Missing pipelines/package.json — cannot install Node dependencies."
    }

    Write-Host "[urban-license-seed] installing pipelines Node dependencies (first run)..."
    Push-Location $PipelinesRoot
    try {
        if (Get-Command pnpm -ErrorAction SilentlyContinue) {
            & pnpm install 2>&1 | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0) {
                throw "pnpm install failed (exit $LASTEXITCODE)."
            }
        }
        elseif (Get-Command npm -ErrorAction SilentlyContinue) {
            & npm install 2>&1 | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0) {
                throw "npm install failed (exit $LASTEXITCODE)."
            }
        }
        else {
            throw "Neither pnpm nor npm found. Install Node.js and pnpm, then run: cd pipelines && pnpm install"
        }
    }
    finally {
        Pop-Location
    }
}

function Test-UrbanNodeVersion {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        throw "Node.js not found. Install Node.js 22.5+ (uses built-in node:sqlite), then: cd pipelines && pnpm install"
    }

    $raw = (& node -p "process.versions.node" 2>&1 | Select-Object -Last 1).ToString().Trim()
    if ($raw -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Unable to parse Node.js version from: $raw"
    }

    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    if ($major -lt 22 -or ($major -eq 22 -and $minor -lt 5)) {
        throw "Node.js $raw is too old for upsert-license-info. Require Node.js 22.5+ (built-in node:sqlite)."
    }
}

function Invoke-UrbanUpsertLicenseInfoTool {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DatabasePath,

        [Parameter(Mandatory = $true)]
        [string] $LicenseJsonPath,

        [Parameter(Mandatory = $true)]
        [string] $SharedRoot
    )

    $pipelinesRoot = Resolve-UrbanPipelinesRoot -SharedRoot $SharedRoot
    $scriptPath = Resolve-UrbanUpsertLicenseInfoScript -SharedRoot $SharedRoot
    Test-UrbanNodeVersion
    Ensure-UrbanPipelinesNodeModules -PipelinesRoot $pipelinesRoot

    Push-Location $pipelinesRoot
    try {
        $prevEap = $ErrorActionPreference
        $prevNodeOptions = $env:NODE_OPTIONS
        $ErrorActionPreference = 'Continue'
        if ([string]::IsNullOrWhiteSpace($prevNodeOptions)) {
            $env:NODE_OPTIONS = '--disable-warning=ExperimentalWarning'
        }
        elseif ($prevNodeOptions -notmatch 'disable-warning=ExperimentalWarning') {
            $env:NODE_OPTIONS = "$prevNodeOptions --disable-warning=ExperimentalWarning"
        }
        try {
            if (Get-Command pnpm -ErrorAction SilentlyContinue) {
                $toolOutput = & pnpm exec tsx $scriptPath $DatabasePath $LicenseJsonPath 2>&1
            }
            elseif (Get-Command npx -ErrorAction SilentlyContinue) {
                $toolOutput = & npx tsx $scriptPath $DatabasePath $LicenseJsonPath 2>&1
            }
            else {
                throw "tsx runner not found. Install Node.js, then: cd pipelines && pnpm install"
            }
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $prevEap
            if ($null -eq $prevNodeOptions) {
                Remove-Item -Path Env:NODE_OPTIONS -ErrorAction SilentlyContinue
            }
            else {
                $env:NODE_OPTIONS = $prevNodeOptions
            }
        }

        if ($null -eq $exitCode) {
            $exitCode = 0
        }
        if ($exitCode -ne 0) {
            throw ("upsert-license-info failed (exit {0}): {1}" -f $exitCode, ($toolOutput -join [Environment]::NewLine))
        }

        return @($toolOutput)
    }
    finally {
        Pop-Location
    }
}

function New-UrbanEffectiveLicenseSeedFile {
    param(
        [Parameter(Mandatory = $true)]
        [object] $License,

        [Parameter(Mandatory = $true)]
        [string] $LocalMachineCode
    )

    $effective = @{}
    foreach ($prop in $License.PSObject.Properties) {
        $effective[$prop.Name] = $prop.Value
    }

    $seedMachineCode = [string]$effective["machineCode"]
    if (-not [string]::IsNullOrWhiteSpace($seedMachineCode) -and
        $LocalMachineCode -ne $seedMachineCode.ToLowerInvariant()) {
        Write-Host (
            "[urban-license-seed] patching machineCode for local upsert: seed={0} local={1}" -f `
                $seedMachineCode, $LocalMachineCode)
    }

    $effective["machineCode"] = $LocalMachineCode
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) (
        "urban-license-seed-{0}.json" -f [Guid]::NewGuid().ToString("N"))
    Write-UrbanUtf8NoBom -Path $tempPath -Content ($effective | ConvertTo-Json -Depth 6)
    return $tempPath
}

function Invoke-UrbanLicenseSeedLocal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $UrbanAppDir,

        [string] $DatabasePath = "",
        [string] $SharedRoot = "",
        [string] $SeedRelPath = "seeds/demo-license.json",
        [string] $RunDir = "",
        [switch] $SkipConfirm
    )

    if ([string]::IsNullOrWhiteSpace($SharedRoot)) {
        $SharedRoot = $PSScriptRoot
    }

    $SharedRoot = (Resolve-Path -LiteralPath $SharedRoot).Path
    $UrbanAppDir = (Resolve-Path -LiteralPath $UrbanAppDir).Path
    $seed = Read-UrbanDemoLicenseSeed -SharedRoot $SharedRoot -SeedRelPath $SeedRelPath

    $localMachineCode = Get-UrbanLocalMachineCode
    $effectiveSeedPath = New-UrbanEffectiveLicenseSeedFile -License $seed.License -LocalMachineCode $localMachineCode

    if ([string]::IsNullOrWhiteSpace($DatabasePath)) {
        $DatabasePath = Join-Path $UrbanAppDir "MaterialClient.db"
    }
    else {
        $DatabasePath = (Resolve-Path -LiteralPath $DatabasePath).Path
    }

    $licenseFilePath = Join-Path $UrbanAppDir "license.urban"

    if (-not $SkipConfirm) {
        $ans = Read-Host (
            "Local license seed will REPLACE LicenseInfo and write {0}. Type YES to continue" -f $licenseFilePath)
        if ($ans -ne "YES") {
            throw "Aborted at license seed human gate."
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RunDir)) {
        New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
    }

    $jwt = [string]$seed.License.latestJwtToken
    if ([string]::IsNullOrWhiteSpace($jwt)) {
        throw "Demo license seed is missing latestJwtToken."
    }

    Write-UrbanUtf8NoBom -Path $licenseFilePath -Content $jwt.Trim()

    try {
        $toolOutput = Invoke-UrbanUpsertLicenseInfoTool -DatabasePath $DatabasePath `
            -LicenseJsonPath $effectiveSeedPath -SharedRoot $SharedRoot
    }
    finally {
        if (Test-Path -LiteralPath $effectiveSeedPath) {
            Remove-Item -LiteralPath $effectiveSeedPath -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RunDir)) {
        Write-UrbanUtf8NoBom -Path (Join-Path $RunDir "license-seed-summary.json") -Content ([ordered]@{
                mode           = "local"
                urbanAppDir    = $UrbanAppDir
                databasePath   = $DatabasePath
                licenseFile    = $licenseFilePath
                seedFile       = $seed.RelPath
                projectId      = [string]$seed.License.projectId
                accessCode     = [string]$seed.License.accessCode
                authEndTime    = [string]$seed.License.authEndTime
                machineCode    = $localMachineCode
                seedMachineCode = [string]$seed.License.machineCode
                toolOutput     = @($toolOutput)
                finishedAt     = (Get-Date).ToString("o")
            } | ConvertTo-Json -Depth 6)
    }

    Write-Host ("[urban-license-seed] local seed complete. licenseFile={0} db={1}" -f $licenseFilePath, $DatabasePath)

    return [pscustomobject]@{
        Mode           = "local"
        UrbanAppDir    = $UrbanAppDir
        DatabasePath   = $DatabasePath
        LicenseFile    = $licenseFilePath
        SeedFile       = $seed.RelPath
        ProjectId      = [string]$seed.License.projectId
        AccessCode     = [string]$seed.License.accessCode
        AuthEndTime    = [string]$seed.License.authEndTime
        MachineCode    = $localMachineCode
        SeedMachineCode = [string]$seed.License.machineCode
        ToolOutput     = @($toolOutput)
    }
}

function Invoke-UrbanLicenseSeedApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $BaseUrl,

        [string] $SharedRoot = "",
        [string] $SeedRelPath = "seeds/demo-license.json",
        [string] $RunDir = "",
        [switch] $SkipConfirm
    )

    if ([string]::IsNullOrWhiteSpace($SharedRoot)) {
        $SharedRoot = $PSScriptRoot
    }

    $SharedRoot = (Resolve-Path -LiteralPath $SharedRoot).Path
    $seed = Read-UrbanDemoLicenseSeed -SharedRoot $SharedRoot -SeedRelPath $SeedRelPath
    $BaseUrl = $BaseUrl.Trim().TrimEnd('/')
    $licenseUrl = "$BaseUrl/api/license/seed"

    if (-not $SkipConfirm) {
        $ans = Read-Host ("POST {0} will REPLACE demo license. Type YES to continue" -f $licenseUrl)
        if ($ans -ne "YES") {
            throw "Aborted at license seed human gate."
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RunDir)) {
        New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
        $httpDir = Join-Path $RunDir "http"
        New-Item -ItemType Directory -Force -Path $httpDir | Out-Null
    }

    $body = [ordered]@{
        id              = [string]$seed.License.id
        projectId       = [string]$seed.License.projectId
        accessCode      = [string]$seed.License.accessCode
        authEndTime     = [string]$seed.License.authEndTime
        proName         = [string]$seed.License.proName
        machineCode     = [string]$seed.License.machineCode
        latestJwtToken  = [string]$seed.License.latestJwtToken
    }

    $json = $body | ConvertTo-Json -Depth 6 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

    try {
        $resp = Invoke-RestMethod -Uri $licenseUrl -Method Post -ContentType "application/json; charset=utf-8" `
            -Body $bytes -TimeoutSec 120
    }
    catch {
        throw (
            "Diagnostic license seed failed at {0}. Ensure MaterialClient.Urban is running and authorized. Error: {1}" -f `
                $licenseUrl, $_.Exception.Message)
    }

    $ok = ($null -ne $resp) -and ($resp.success -eq $true)
    if (-not $ok) {
        throw "POST $licenseUrl did not return success=true."
    }

    if (-not [string]::IsNullOrWhiteSpace($RunDir)) {
        Write-UrbanUtf8NoBom -Path (Join-Path $httpDir "00-license-seed.request.json") -Content ($body | ConvertTo-Json -Depth 6)
        Write-UrbanUtf8NoBom -Path (Join-Path $httpDir "01-license-seed.response.json") -Content ($resp | ConvertTo-Json -Depth 8)
        Write-UrbanUtf8NoBom -Path (Join-Path $RunDir "license-seed-summary.json") -Content ([ordered]@{
                mode        = "api"
                baseUrl     = $BaseUrl
                seedFile    = $seed.RelPath
                success     = $ok
                finishedAt  = (Get-Date).ToString("o")
            } | ConvertTo-Json -Depth 6)
    }

    Write-Host ("[urban-license-seed] api seed complete. baseUrl={0}" -f $BaseUrl)

    return [pscustomobject]@{
        Mode         = "api"
        BaseUrl      = $BaseUrl
        LicenseUrl   = $licenseUrl
        SeedFile     = $seed.RelPath
        Success      = $ok
        Response     = $resp
    }
}

function Invoke-UrbanLicenseSeed {
    [CmdletBinding()]
    param(
        [ValidateSet("Local", "Api", "Auto")]
        [string] $Mode = "Auto",

        [string] $UrbanAppDir = "",
        [string] $DatabasePath = "",
        [string] $GraphRoot = "",
        [string] $BaseUrl = "",
        [string] $SharedRoot = "",
        [string] $SeedRelPath = "seeds/demo-license.json",
        [string] $RunDir = "",
        [switch] $SkipConfirm
    )

    if ([string]::IsNullOrWhiteSpace($SharedRoot)) {
        $SharedRoot = $PSScriptRoot
    }

    $effectiveMode = $Mode
    if ($effectiveMode -eq "Auto") {
        if (-not [string]::IsNullOrWhiteSpace($UrbanAppDir)) {
            $effectiveMode = "Local"
        }
        else {
            $effectiveMode = "Api"
        }
    }

    if ($effectiveMode -eq "Local") {
        if ([string]::IsNullOrWhiteSpace($UrbanAppDir)) {
            throw "Local license seed requires -UrbanAppDir (MaterialClient.Urban output directory)."
        }

        return Invoke-UrbanLicenseSeedLocal -UrbanAppDir $UrbanAppDir -DatabasePath $DatabasePath `
            -SharedRoot $SharedRoot -SeedRelPath $SeedRelPath -RunDir $RunDir -SkipConfirm:$SkipConfirm
    }

    if ([string]::IsNullOrWhiteSpace($BaseUrl) -and -not [string]::IsNullOrWhiteSpace($GraphRoot)) {
        $BaseUrl = Resolve-UrbanDiagnosticBaseUrl -GraphRoot $GraphRoot
    }
    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        $BaseUrl = "http://localhost:9961"
    }

    return Invoke-UrbanLicenseSeedApi -BaseUrl $BaseUrl -SharedRoot $SharedRoot -SeedRelPath $SeedRelPath `
        -RunDir $RunDir -SkipConfirm:$SkipConfirm
}
