#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental probe: MaterialClient.Urban checkpoint / finished-product LPR via diagnostic API.
.DESCRIPTION
  Runs shared seed-settings (full LPR replace), then POST /api/lpr/test-passage for 10 cases.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$CasesPath = Join-Path $GraphRoot "seeds/passage-cases.json"
$FixtureRel = "../../govsync/xiaoshan-gate/fixtures/test_pic.jpg"
$FixturePath = Join-Path $GraphRoot $FixtureRel
$SharedScript = Join-Path $GraphRoot "../../../_shared/urban/Invoke-UrbanLprSeedSettings.ps1"
$SharedScript = [System.IO.Path]::GetFullPath($SharedScript)

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Invoke-JsonPost {
    param([string] $Url, [object] $Body)
    $json = $Body | ConvertTo-Json -Depth 12 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return Invoke-RestMethod -Uri $Url -Method Post -ContentType "application/json; charset=utf-8" `
        -Body $bytes -TimeoutSec 120
}

if (-not (Test-Path -LiteralPath $SharedScript)) {
    throw "Missing shared script: $SharedScript"
}
if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing config: $ConfigPath"
}
if (-not (Test-Path -LiteralPath $CasesPath)) {
    throw "Missing cases seed: $CasesPath"
}
if (-not (Test-Path -LiteralPath $FixturePath)) {
    throw "Missing fixture image: $FixturePath"
}

. $SharedScript

Write-Host "[urban-passage-probe] experimental Invoke starting..."

$casesJson = [System.IO.File]::ReadAllText($CasesPath, [System.Text.Encoding]::UTF8)
$cases = $casesJson | ConvertFrom-Json
if ($cases.Count -ne 10) {
    throw ("Expected 10 passage cases, got {0}" -f $cases.Count)
}

$fixtureAbs = (Resolve-Path -LiteralPath $FixturePath).Path

if (-not $SkipConfirm) {
    $baseUrlPreview = Resolve-UrbanDiagnosticBaseUrl -GraphRoot $GraphRoot
    $ans = Read-Host (
        "Will REPLACE all LPR configs then POST {0}/api/lpr/test-passage x10. Type YES to continue" -f $baseUrlPreview)
    if ($ans -ne "YES") { throw "Aborted at human gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$HttpDir = Join-Path $RunDir "http"
New-Item -ItemType Directory -Force -Path $HttpDir | Out-Null

$runMeta = [ordered]@{
    graph      = "urban/urban-passage-probe"
    fixture    = $FixtureRel
    fixtureAbs = $fixtureAbs
    caseCount  = $cases.Count
    startedAt  = (Get-Date).ToString("o")
}
Write-Utf8NoBom -Path (Join-Path $RunDir "run.meta.json") -Content ($runMeta | ConvertTo-Json -Depth 5)

# L1: shared seed-settings — full replace all LPR configs before probe cases
$seedSkipConfirm = $SkipConfirm
if (-not $SkipConfirm) {
    # Human gate already confirmed above for the full probe run.
    $seedSkipConfirm = $true
}
$seedResult = Invoke-UrbanPassageLprSeedSettings -GraphRoot $GraphRoot -RunDir $RunDir -SkipConfirm:$seedSkipConfirm
$baseUrl = $seedResult.BaseUrl
$settingsGetOk = $seedResult.SettingsGetOk
$settingsSaveOk = $seedResult.SettingsSaveOk
$testPassageUrl = "$baseUrl/api/lpr/test-passage"

# L2: run 10 test-passage cases
$caseResults = @()
$passCount = 0
$failCount = 0
$idx = 0
foreach ($case in $cases) {
    $idx++
    $caseId = [string]$case.id
    $prefix = ("{0:D2}-{1}" -f $idx, $caseId)
    $body = [ordered]@{
        siteType     = [string]$case.siteType
        deviceName   = [string]$case.deviceName
        plateNumber  = [string]$case.plateNumber
        plateColor   = [string]$case.plateColor
        vehicleType  = [string]$case.vehicleType
        lprImagePath = $fixtureAbs
    }
    Write-Utf8NoBom -Path (Join-Path $HttpDir ("{0}.request.json" -f $prefix)) -Content ($body | ConvertTo-Json -Depth 6)

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $httpStatus = 200
    $resp = $null
    $err = $null
    try {
        $resp = Invoke-JsonPost -Url $testPassageUrl -Body $body
    }
    catch {
        $err = $_.Exception.Message
        $httpStatus = 0
        if ($_.Exception.Response) {
            $httpStatus = [int]$_.Exception.Response.StatusCode
        }
    }
    $sw.Stop()

    $ok = ($null -ne $resp) -and ($resp.success -eq $true) -and ($resp.published -eq $true)
    if ($ok) { $passCount++ } else { $failCount++ }

    if ($null -ne $resp) {
        Write-Utf8NoBom -Path (Join-Path $HttpDir ("{0}.response.json" -f $prefix)) -Content ($resp | ConvertTo-Json -Depth 8)
    }
    else {
        $errText = if ($err) { $err } else { "unknown error" }
        Write-Utf8NoBom -Path (Join-Path $HttpDir ("{0}.response.error.txt" -f $prefix)) -Content $errText
    }

    $caseResults += [ordered]@{
        index       = $idx
        id          = $caseId
        label       = [string]$case.label
        siteType    = [string]$case.siteType
        deviceName  = [string]$case.deviceName
        plateNumber = [string]$case.plateNumber
        httpStatus  = $httpStatus
        success     = $ok
        elapsedMs   = [int]$sw.ElapsedMilliseconds
        error       = $err
    }
}

$summary = [ordered]@{
    graph            = "urban/urban-passage-probe"
    runDir           = $RunDir
    baseUrl          = $baseUrl
    fixture          = $FixtureRel
    lprSeedMode      = "replace-all"
    lprBeforeCount   = $seedResult.BeforeLprCount
    lprAfterCount    = $seedResult.AfterLprCount
    settingsGetOk    = $settingsGetOk
    settingsSaveOk   = $settingsSaveOk
    caseTotal        = $cases.Count
    casePass         = $passCount
    caseFail         = $failCount
    allCasesAccepted = ($failCount -eq 0) -and $settingsSaveOk
    finishedAt       = (Get-Date).ToString("o")
    cases            = $caseResults
}
Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 8)

$report = @"
# urban-passage-probe run report

- Base URL: $baseUrl
- Fixture: $FixtureRel
- LPR seed: replace-all (before=$($seedResult.BeforeLprCount), after=$($seedResult.AfterLprCount))
- Cases: $($cases.Count) (pass=$passCount, fail=$failCount)
- Settings GET: $settingsGetOk
- Settings POST: $settingsSaveOk
- L2 allCasesAccepted: $($summary.allCasesAccepted)

## Cases

| # | id | siteType | device | plate | ok |
|---|-----|----------|--------|-------|-----|
"@
foreach ($r in $caseResults) {
    $report += ("| {0} | {1} | {2} | {3} | {4} | {5} |`n" -f $r.index, $r.id, $r.siteType, $r.deviceName, $r.plateNumber, $r.success)
}
$report += @"

## L3 (user)

Confirm Checkpoint / FinishedProduct tabs in MaterialClient.Urban show the injected rows.
"@
Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content $report

Write-Host ("[urban-passage-probe] done. pass={0} fail={1} runDir={2}" -f $passCount, $failCount, $RunDir)
if ($failCount -gt 0 -or -not $settingsSaveOk) {
    exit 1
}
