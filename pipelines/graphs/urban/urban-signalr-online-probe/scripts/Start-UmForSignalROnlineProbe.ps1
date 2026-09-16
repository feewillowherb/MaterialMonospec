#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental: start UrbanManagement for urban-signalr-online-probe (no BasePlatform).
.DESCRIPTION
  Builds (optional) and starts UrbanManagement.App with BasePlatformSync / Gov polling off,
  and UrbanAuth JWT issuer fallback local. Does not start FdSoft.BasePlatform.
#>
[CmdletBinding()]
param(
    [string] $UmBaseUrl = "",
    [string] $UmProject = "",
    [string] $UmContentRoot = "",
    [string] $Configuration = "Debug",
    [switch] $SkipBuild,
    [switch] $NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../../../..")).Path
$GraphRoot = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $GraphRoot "config.yaml"

function Get-YamlScalarLocal {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*{0}\s*:\s*(.+)\s*$" -f [regex]::Escape($Key)
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { return $null }
    return ($m.Groups[1].Value.Trim().Trim('"').Trim("'"))
}

$configText = ""
if (Test-Path -LiteralPath $ConfigPath) {
    $configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
}

if ([string]::IsNullOrWhiteSpace($UmBaseUrl)) {
    $UmBaseUrl = Get-YamlScalarLocal -Text $configText -Key "umBaseUrl"
    if ([string]::IsNullOrWhiteSpace($UmBaseUrl)) { $UmBaseUrl = "http://127.0.0.1:44371" }
}
$UmBaseUrl = $UmBaseUrl.Trim().TrimEnd('/')

$secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
if (Test-Path -LiteralPath $secretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
    $fromSecrets = Get-YamlScalarLocal -Text $secretsText -Key "umBaseUrl"
    if (-not [string]::IsNullOrWhiteSpace($fromSecrets)) {
        $UmBaseUrl = $fromSecrets.Trim().TrimEnd('/')
    }
}

if ([string]::IsNullOrWhiteSpace($UmProject)) {
    $UmProject = Join-Path $RepoRoot "repos/UrbanManagement/src/UrbanManagement.App/UrbanManagement.App.csproj"
}
if ([string]::IsNullOrWhiteSpace($UmContentRoot)) {
    $UmContentRoot = Join-Path $RepoRoot "repos/UrbanManagement/src/UrbanManagement.App"
}

if (-not (Test-Path -LiteralPath $UmProject)) {
    throw "UM project not found: $UmProject"
}
if (-not (Test-Path -LiteralPath $UmContentRoot)) {
    throw "UM content root not found: $UmContentRoot"
}

if (-not $SkipBuild) {
    Write-Host "[urban-signalr-online-probe] building UrbanManagement.App ($Configuration)..."
    & dotnet build $UmProject -c $Configuration | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build UrbanManagement.App failed."
    }
}

if ($NoLaunch) {
    Write-Host "[urban-signalr-online-probe] UM prepare complete; -NoLaunch set."
    return
}

# If something already answers on the URL, do not start another instance.
try {
    $null = Invoke-WebRequest -Uri "$UmBaseUrl/" -Method Get -TimeoutSec 3 -UseBasicParsing
    Write-Warning "UM already reachable at $UmBaseUrl; not starting another instance."
    return
}
catch {
    # expected when not running
}

$logsDir = Join-Path $GraphRoot "scripts/.um-logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
$stdoutLog = Join-Path $logsDir "um-stdout.log"
$stderrLog = Join-Path $logsDir "um-stderr.log"

$env:ASPNETCORE_URLS = $UmBaseUrl
$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:BasePlatformSync__Enabled = "false"
$env:BackgroundServices__Polling = "false"
$env:UrbanAuth__UseBasePlatformJwtIssuer = "false"

Write-Host "[urban-signalr-online-probe] starting UM:"
Write-Host "  ASPNETCORE_URLS=$($env:ASPNETCORE_URLS)"
Write-Host "  BasePlatformSync__Enabled=false"
Write-Host "  BackgroundServices__Polling=false"
Write-Host "  UrbanAuth__UseBasePlatformJwtIssuer=false"

$proc = Start-Process -FilePath "dotnet" `
    -ArgumentList @("run", "--project", $UmProject, "--no-build", "-c", $Configuration) `
    -WorkingDirectory $UmContentRoot `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru `
    -WindowStyle Hidden

Write-Host "[urban-signalr-online-probe] UM started PID=$($proc.Id). Logs: $logsDir"
Write-Host "[urban-signalr-online-probe] Wait until $UmBaseUrl/ responds, then continue Invoke."
