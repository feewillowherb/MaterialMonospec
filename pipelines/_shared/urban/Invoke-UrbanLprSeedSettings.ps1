#Requires -Version 5.1
<#
.SYNOPSIS
  Shared: replace all LPR rows in MaterialClient.Urban Settings via diagnostic API.
.DESCRIPTION
  GET /api/settings, set licensePlateRecognitionConfigs to seed file (full replace),
  POST /api/settings. Other Settings blocks are preserved from GET.
  Dot-source this file, then call Invoke-UrbanPassageLprSeedSettings.
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

function Invoke-UrbanJsonGet {
    param([string] $Url)
    return Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 60
}

function Invoke-UrbanJsonPost {
    param([string] $Url, [object] $Body)
    $json = $Body | ConvertTo-Json -Depth 12 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return Invoke-RestMethod -Uri $Url -Method Post -ContentType "application/json; charset=utf-8" `
        -Body $bytes -TimeoutSec 120
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

function ConvertTo-UrbanLprEnumInt {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [object] $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [decimal]) {
        return [int]$Value
    }

    $text = [string]$Value
    switch ($Name) {
        "siteType" {
            switch -Regex ($text) {
                "^(Scale|0)$" { return 0 }
                "^(Checkpoint|1)$" { return 1 }
                "^(FinishedProduct|2)$" { return 2 }
                default { throw "Unknown siteType value: $text" }
            }
        }
        "deviceType" {
            switch -Regex ($text) {
                "^(Hikvision|0)$" { return 0 }
                "^(Vzvision|1)$" { return 1 }
                "^(Huaxiazhixin|2)$" { return 2 }
                default { throw "Unknown deviceType value: $text" }
            }
        }
        "direction" {
            switch -Regex ($text) {
                "^(A|0)$" { return 0 }
                "^(B|1)$" { return 1 }
                default { throw "Unknown direction value: $text" }
            }
        }
        default { return $Value }
    }
}

function ConvertTo-UrbanLprApiRow {
    param(
        [Parameter(Mandatory = $true)]
        [object] $SeedDevice,

        [object] $TemplateRow = $null
    )

    $row = [ordered]@{}
    if ($null -ne $TemplateRow) {
        foreach ($prop in $TemplateRow.PSObject.Properties) {
            $row[$prop.Name] = $prop.Value
        }
    }

    foreach ($prop in $SeedDevice.PSObject.Properties) {
        $value = $prop.Value
        if ($prop.Name -in @("siteType", "deviceType", "direction")) {
            $value = ConvertTo-UrbanLprEnumInt -Name $prop.Name -Value $value
        }
        $row[$prop.Name] = $value
    }

    if ($row.Contains("resolvedDeviceType")) {
        $row.Remove("resolvedDeviceType")
    }

    return [pscustomobject]$row
}

function Read-UrbanLprDeviceSeed {
    param([string] $GraphRoot)
    $configPath = Join-Path $GraphRoot "config.yaml"
    $seedRel = "seeds/lpr-devices.json"

    if (Test-Path -LiteralPath $configPath) {
        $configText = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
        if ($configText -match '(?m)^  lprDevices:\s*(.+)$') {
            $candidate = $Matches[1].Trim()
            if ($candidate -match '^(.*?)\s+#') { $candidate = $Matches[1].Trim() }
            if ($candidate -match '\.json$') {
                $seedRel = $candidate
            }
        }
    }

    $seedPath = Join-Path $GraphRoot $seedRel
    if (-not (Test-Path -LiteralPath $seedPath)) {
        throw "Missing LPR device seed: $seedPath"
    }

    $json = [System.IO.File]::ReadAllText($seedPath, [System.Text.Encoding]::UTF8)
    $devices = $json | ConvertFrom-Json
    if ($null -eq $devices -or @($devices).Count -lt 1) {
        throw "LPR device seed is empty: $seedPath"
    }

    return @{
        Path    = $seedPath
        RelPath = $seedRel
        Devices = @($devices)
    }
}

function Invoke-UrbanPassageLprSeedSettings {
    <#
    .SYNOPSIS
      GET settings, replace licensePlateRecognitionConfigs entirely, POST settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $GraphRoot,

        [string] $RunDir = "",
        [string] $BaseUrl = "",
        [switch] $SkipConfirm
    )

    $GraphRoot = (Resolve-Path -LiteralPath $GraphRoot).Path
    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        $BaseUrl = Resolve-UrbanDiagnosticBaseUrl -GraphRoot $GraphRoot
    }
    else {
        $BaseUrl = $BaseUrl.Trim().TrimEnd('/')
    }

    $seed = Read-UrbanLprDeviceSeed -GraphRoot $GraphRoot
    $settingsUrl = "$BaseUrl/api/settings"

    if (-not $SkipConfirm) {
        $ans = Read-Host (
            "POST {0} will REPLACE ALL LPR configs with {1} row(s) from {2}. Type YES to continue" -f `
                $settingsUrl, $seed.Devices.Count, $seed.RelPath)
        if ($ans -ne "YES") {
            throw "Aborted at seed-settings human gate."
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RunDir)) {
        New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
        $httpDir = Join-Path $RunDir "http"
        New-Item -ItemType Directory -Force -Path $httpDir | Out-Null
    }

    try {
        $rootResp = Invoke-UrbanJsonGet -Url $BaseUrl
        $settingsResp = Invoke-UrbanJsonGet -Url $settingsUrl
    }
    catch {
        throw (
            "Diagnostic host not reachable at {0}. Start MaterialClient.Urban with MinimalWebHost:EnableOnStartup=true. Error: {1}" -f `
                $BaseUrl, $_.Exception.Message)
    }

    $settingsGetOk = ($null -ne $settingsResp) -and ($settingsResp.success -eq $true)
    if (-not $settingsGetOk) {
        throw "GET $settingsUrl did not return success=true."
    }

    $beforeCount = 0
    if ($null -ne $settingsResp.settings -and $null -ne $settingsResp.settings.licensePlateRecognitionConfigs) {
        $beforeCount = @($settingsResp.settings.licensePlateRecognitionConfigs).Count
    }

    $settingsPayload = $settingsResp.settings
    if ($null -eq $settingsPayload) {
        $settingsPayload = [ordered]@{}
    }

    $templateRow = $null
    if ($null -ne $settingsResp.settings -and $null -ne $settingsResp.settings.licensePlateRecognitionConfigs) {
        $existingRows = @($settingsResp.settings.licensePlateRecognitionConfigs)
        if ($existingRows.Count -gt 0) {
            $templateRow = $existingRows[0]
        }
    }

    $lprRows = @()
    foreach ($device in $seed.Devices) {
        $lprRows += ConvertTo-UrbanLprApiRow -SeedDevice $device -TemplateRow $templateRow
    }

    # Full replace: drop all existing LPR rows, use normalized seed only.
    $settingsPayload | Add-Member -NotePropertyName licensePlateRecognitionConfigs `
        -NotePropertyValue $lprRows -Force

    $settingsSaveResp = Invoke-UrbanJsonPost -Url $settingsUrl -Body $settingsPayload
    $settingsSaveOk = ($null -ne $settingsSaveResp) -and ($settingsSaveResp.success -eq $true)
    if (-not $settingsSaveOk) {
        throw "POST $settingsUrl failed or success!=true."
    }

    $afterCount = @($seed.Devices).Count
    if ($null -ne $settingsSaveResp.settings -and $null -ne $settingsSaveResp.settings.licensePlateRecognitionConfigs) {
        $afterCount = @($settingsSaveResp.settings.licensePlateRecognitionConfigs).Count
    }

    if (-not [string]::IsNullOrWhiteSpace($RunDir)) {
        Write-UrbanUtf8NoBom -Path (Join-Path $httpDir "00-root.json") -Content ($rootResp | ConvertTo-Json -Depth 6)
        Write-UrbanUtf8NoBom -Path (Join-Path $httpDir "01-settings-get.json") -Content ($settingsResp | ConvertTo-Json -Depth 12)
        Write-UrbanUtf8NoBom -Path (Join-Path $httpDir "02-settings-save.json") -Content ($settingsSaveResp | ConvertTo-Json -Depth 12)
        Write-UrbanUtf8NoBom -Path (Join-Path $RunDir "seed-summary.json") -Content ([ordered]@{
                mode           = "replace-all-lpr"
                baseUrl        = $BaseUrl
                seedFile       = $seed.RelPath
                beforeLprCount = $beforeCount
                afterLprCount  = $afterCount
                success        = $settingsSaveOk
                finishedAt     = (Get-Date).ToString("o")
            } | ConvertTo-Json -Depth 6)
    }

    Write-Host ("[urban-lpr-seed-settings] replaced LPR configs: before={0} after={1} baseUrl={2}" -f `
            $beforeCount, $afterCount, $BaseUrl)

    return [pscustomobject]@{
        BaseUrl          = $BaseUrl
        SettingsUrl      = $settingsUrl
        SeedFile         = $seed.RelPath
        BeforeLprCount   = $beforeCount
        AfterLprCount    = $afterCount
        SettingsGetOk    = $settingsGetOk
        SettingsSaveOk   = $settingsSaveOk
        SettingsSaveResp = $settingsSaveResp
        SettingsGetResp  = $settingsResp
    }
}
