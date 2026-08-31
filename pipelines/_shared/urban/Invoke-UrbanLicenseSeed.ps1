#Requires -Version 5.1
<#
.SYNOPSIS
  Shared: seed MaterialClient.Urban demo license before or during diagnostic runs.
.DESCRIPTION
  Local mode (default): writes license.urban and upserts LicenseInfo in MaterialClient.db.
  Api mode: POST /api/license/seed when the diagnostic host is already running.

  Fixed demo license: seeds/demo-license.json (杭州凡东科技演示项目 / XNXS20260611001).
  JWT machineCode must match the test machine, or startup authorization will still fail.
#>

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

function Resolve-UrbanLicenseToolProject {
    param([string] $SharedRoot)
    $toolProject = Join-Path $SharedRoot "tools/UpsertLicenseInfo/UpsertLicenseInfo.csproj"
    if (-not (Test-Path -LiteralPath $toolProject)) {
        throw "Missing UpsertLicenseInfo tool project: $toolProject"
    }

    return (Resolve-Path -LiteralPath $toolProject).Path
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

    if ([string]::IsNullOrWhiteSpace($DatabasePath)) {
        $DatabasePath = Join-Path $UrbanAppDir "MaterialClient.db"
    }
    else {
        $DatabasePath = (Resolve-Path -LiteralPath $DatabasePath).Path
    }

    $licenseFilePath = Join-Path $UrbanAppDir "license.urban"
    $toolProject = Resolve-UrbanLicenseToolProject -SharedRoot $SharedRoot

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

    $toolOutput = & dotnet run --project $toolProject -- $DatabasePath $seed.Path 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("UpsertLicenseInfo failed (exit {0}): {1}" -f $LASTEXITCODE, ($toolOutput -join [Environment]::NewLine))
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
                machineCode    = [string]$seed.License.machineCode
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
        MachineCode    = [string]$seed.License.machineCode
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
