#Requires -Version 5.1
<#
.SYNOPSIS
  Pack MaterialClient.Urban Velopack Full+Delta release and upload to 138 gateway /updates/urban feed.
.DESCRIPTION
  experimental cook for graphs/ops/publish-urban-ota-lab-138.
  pack (default) builds Velopack artifacts locally (creating delta.nupkg when prior release exists in ReleaseDir).
  upload -Apply uploads release files to 138 via shared SSH/SCP helpers and verifies /updates/urban/releases.win.json.
  verify only checks HTTP endpoints on 138.
#>
[CmdletBinding()]
param(
    [ValidateSet("pack", "upload", "verify")]
    [string] $Mode = "pack",

    [ValidatePattern('^(\d+\.\d+\.\d+([-.][0-9A-Za-z.]+)?)?$')]
    [string] $Version = "",

    [string] $ReleaseDir = "",

    [switch] $Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphDir = Split-Path -Parent $PSScriptRoot

function Resolve-RepoRoot {
    $dir = $PSScriptRoot
    while ($true) {
        if ((Test-Path (Join-Path $dir ".hagicode")) -and (Test-Path (Join-Path $dir "pipelines"))) {
            return $dir
        }
        $parent = Split-Path -Parent $dir
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) {
            throw "Cannot resolve MaterialMonospec repo root from $PSScriptRoot"
        }
        $dir = $parent
    }
}

function Read-FlatYaml([string] $Path) {
    $map = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^([A-Za-z0-9_]+):\s*(.*)$') {
            $value = $Matches[2].Trim()
            if ($value -match '\s+#') {
                $value = ($value -split '\s+#', 2)[0].Trim()
            }
            if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $map[$Matches[1]] = $value
        }
    }
    return $map
}

function Write-Utf8([string] $Path, [string] $Text) {
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

$repoRoot = Resolve-RepoRoot
$runId = Get-Date -Format "yyyy-MM-ddTHHmmss"
$runDir = Join-Path $GraphDir ("runs\" + $runId)
$prepareDir = Join-Path $runDir "prepare"
New-Item -ItemType Directory -Force -Path $prepareDir | Out-Null

$resolvedReleaseDir = if ([string]::IsNullOrWhiteSpace($ReleaseDir)) {
    Join-Path $repoRoot "repos\MaterialClient\.build-verify\urban-releases-2.0"
} elseif ([System.IO.Path]::IsPathRooted($ReleaseDir)) {
    $ReleaseDir
} else {
    Join-Path $repoRoot $ReleaseDir
}

if ($Mode -eq "upload" -and -not $Apply) {
    throw "upload writes to host 138. Re-run with -Mode upload -Apply after the upload-approval gate."
}

$gatewayBaseUrl = "http://192.168.3.138:5333"
$secrets = $null
if ($Mode -eq "upload") {
    $secretsPath = Join-Path $GraphDir "secrets.local.yaml"
    if (-not (Test-Path -LiteralPath $secretsPath)) {
        throw "Missing secrets.local.yaml. Copy secrets.example.yaml and fill host, user, remoteUpdatesDir."
    }
    $secrets = Read-FlatYaml $secretsPath
    foreach ($key in @("host", "user", "remoteUpdatesDir")) {
        if (-not $secrets.Contains($key) -or [string]::IsNullOrWhiteSpace([string]$secrets[$key])) {
            throw "secrets.local.yaml missing $key"
        }
    }
    if (-not $secrets.Contains("port") -or [string]::IsNullOrWhiteSpace([string]$secrets["port"])) {
        $secrets["port"] = "22"
    }
    if ($secrets.Contains("gatewayBaseUrl") -and -not [string]::IsNullOrWhiteSpace([string]$secrets["gatewayBaseUrl"])) {
        $gatewayBaseUrl = ([string]$secrets["gatewayBaseUrl"]).TrimEnd('/')
    }
}

$achieved = "P0"
$deltaFiles = @()
$uploadedFiles = @()
$feedStatus = $null
$feedCacheControl = $null
$feedHasVersion = $false
$feedHasDelta = $false

if ($Mode -eq "pack") {
    if ([string]::IsNullOrWhiteSpace($Version)) {
        throw "Version is required in pack mode (e.g. -Version 2.0.1)."
    }

    $packScript = Join-Path $repoRoot "repos\MaterialClient\scripts\pack-urban-ota.ps1"
    Write-Host "[publish-urban-ota-lab-138] Packing MaterialClient.Urban v$Version into $resolvedReleaseDir..." -ForegroundColor Cyan
    & $packScript -Version $Version -OutputDir $resolvedReleaseDir
    if ($LASTEXITCODE -ne 0) {
        throw "pack-urban-ota.ps1 exited with $LASTEXITCODE"
    }

    $deltaFiles = @(Get-ChildItem -Path $resolvedReleaseDir -Filter "*-delta.nupkg" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    $allFiles = @(Get-ChildItem -Path $resolvedReleaseDir -File | Select-Object Name, Length, LastWriteTime)
    Write-Utf8 (Join-Path $prepareDir "release-files.json") ($allFiles | ConvertTo-Json -Depth 4)
    $achieved = if ($deltaFiles.Count -gt 0) { "P1" } else { "P0" }
}

if ($Mode -eq "upload") {
    if (-not (Test-Path -LiteralPath $resolvedReleaseDir)) {
        throw "Release directory not found: $resolvedReleaseDir"
    }

    $filesToUpload = @(Get-ChildItem -Path $resolvedReleaseDir -File | Where-Object {
        $_.Name -in @("releases.win.json", "RELEASES", "assets.win.json") -or
        $_.Extension -in @(".nupkg", ".exe")
    })
    if ($filesToUpload.Count -eq 0) {
        throw "No Velopack release artifacts found in $resolvedReleaseDir"
    }

    $deltaFiles = @($filesToUpload | Where-Object { $_.Name -like "*-delta.nupkg" } | Select-Object -ExpandProperty Name)
    $ssh = Join-Path $repoRoot "pipelines\_shared\ops\ssh\Invoke-SshRemote.ps1"
    $scp = Join-Path $repoRoot "pipelines\_shared\ops\ssh\Copy-ScpToRemote.ps1"
    $remoteUrbanDir = (([string]$secrets["remoteUpdatesDir"]).TrimEnd('\', '/') + "/urban")

    $mkdirPs = "New-Item -ItemType Directory -Force -Path '$remoteUrbanDir' | Out-Null"
    $mkdirEnc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($mkdirPs))
    $mkdirCmd = "powershell -NoProfile -EncodedCommand $mkdirEnc"
    $sshArgs = @{
        HostName              = [string]$secrets["host"]
        User                  = [string]$secrets["user"]
        Port                  = [int]$secrets["port"]
        RemoteCommand         = $mkdirCmd
        RepoRoot              = $repoRoot
        ConnectTimeoutSeconds = 30
        EvidenceDir           = Join-Path $runDir "ssh"
    }
    if ($secrets.Contains("password") -and -not [string]::IsNullOrWhiteSpace([string]$secrets["password"])) {
        $sshArgs.Password = [string]$secrets["password"]
    }
    & $ssh @sshArgs | Out-Null

    $scpArgs = @{
        HostName    = [string]$secrets["host"]
        User        = [string]$secrets["user"]
        Port        = [int]$secrets["port"]
        LocalPath   = @($filesToUpload | Select-Object -ExpandProperty FullName)
        RemoteDir   = ($remoteUrbanDir -replace '\\', '/')
        RepoRoot    = $repoRoot
        EvidenceDir = Join-Path $runDir "scp"
    }
    if ($secrets.Contains("password") -and -not [string]::IsNullOrWhiteSpace([string]$secrets["password"])) {
        $scpArgs.Password = [string]$secrets["password"]
    }
    & $scp @scpArgs
    $uploadedFiles = @($filesToUpload | Select-Object -ExpandProperty Name)
    $achieved = "P1"
}

if ($Mode -eq "upload" -or $Mode -eq "verify") {
    $releasesUrl = "$gatewayBaseUrl/updates/urban/releases.win.json"
    $resp = Invoke-WebRequest -Uri $releasesUrl -UseBasicParsing -TimeoutSec 15
    $feedStatus = [int]$resp.StatusCode
    $feedCacheControl = [string]$resp.Headers["Cache-Control"]
    Write-Utf8 (Join-Path $prepareDir "releases.win.json") $resp.Content

    $parsed = $resp.Content | ConvertFrom-Json
    $assets = @($parsed.Assets)
    $feedHasDelta = @($assets | Where-Object { $_.Type -eq "Delta" }).Count -gt 0
    $feedHasVersion = if ([string]::IsNullOrWhiteSpace($Version)) {
        $assets.Count -gt 0
    } else {
        @($assets | Where-Object { $_.Version -eq $Version }).Count -gt 0
    }

    $relResp = Invoke-WebRequest -Uri "$gatewayBaseUrl/updates/urban/RELEASES" -UseBasicParsing -TimeoutSec 15
    Write-Utf8 (Join-Path $prepareDir "RELEASES") $relResp.Content

    if ($feedStatus -eq 200 -and $relResp.StatusCode -eq 200 -and $feedHasVersion) {
        $achieved = "P2"
    }
}

$summary = [ordered]@{
    graphId          = "publish-urban-ota-lab-138"
    runId            = $runId
    mode             = $Mode
    version          = $Version
    achievedLevel    = $achieved
    p3Acceptance     = "pending"
    deltaFiles       = $deltaFiles
    uploadedFiles    = $uploadedFiles
    feedStatus       = $feedStatus
    feedCacheControl = $feedCacheControl
    feedHasVersion   = $feedHasVersion
    feedHasDelta     = $feedHasDelta
}
Write-Utf8 (Join-Path $runDir "summary.json") ($summary | ConvertTo-Json -Depth 5)

$reportLines = @(
    "# publish-urban-ota-lab-138 Run Report ($runId)",
    "",
    "- Mode: ``$Mode``",
    "- Version: ``$Version``",
    "- Achieved Level: **$achieved** (P3 pending user acceptance)",
    "- Delta files: $(if ($deltaFiles.Count -gt 0) { $deltaFiles -join ', ' } else { 'none' })",
    "- Feed HTTP Status: $feedStatus ($feedCacheControl)",
    "- Feed Contains Target Version: $feedHasVersion | Contains Delta: $feedHasDelta"
)
Write-Utf8 (Join-Path $runDir "report.md") ($reportLines -join "`n")

Write-Host "[publish-urban-ota-lab-138] Done ($Mode). Achieved=$achieved, RunDir=pipelines/graphs/ops/publish-urban-ota-lab-138/runs/$runId" -ForegroundColor Green
