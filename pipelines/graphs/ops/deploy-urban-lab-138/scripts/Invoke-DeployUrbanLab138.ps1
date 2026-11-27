#Requires -Version 5.1
<#
.SYNOPSIS
  Publish UrbanManagement lab images and, with -Apply, deploy them to host 138.
.DESCRIPTION
  experimental cook for graphs/ops/deploy-urban-lab-138.
  publish (default) only writes a bundle under this run.
  deploy -Apply uploads that bundle and builds one slim image per service on the lab host.
  verify only reads health endpoints and does not build.
#>
[CmdletBinding()]
param(
    [ValidateSet("publish", "deploy", "verify")]
    [string] $Mode = "publish",
    [switch] $Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphDir = Split-Path -Parent $PSScriptRoot
$Services = @("Gateway", "Ingest", "Attachment", "Realtime", "Admin", "Recycle", "Worker", "Migrator")
$ComposeServices = @("um-ingest", "um-ingest-2", "um-attachment", "um-realtime", "um-admin", "um-worker", "um-gateway", "um-recycle")
$ImageTag = "lab"
$GatewayPort = 5333
$RecyclePort = 5334
$BuildTimeoutMinutes = 45

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

function ConvertTo-EncodedCommand([string] $Script) {
    return [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($Script))
}

function Join-Win([string] $Root, [string] $Child) {
    return $Root.TrimEnd('\', '/') + '\' + $Child
}

$repoRoot = Resolve-RepoRoot
$runId = Get-Date -Format "yyyy-MM-ddTHHmmss"
$runDir = Join-Path $GraphDir ("runs\" + $runId)
$prepare = Join-Path $runDir "prepare"
New-Item -ItemType Directory -Force -Path $prepare | Out-Null
$urbanLink = Get-Item -LiteralPath (Join-Path $repoRoot "repos\UrbanManagement")
$urban = $urbanLink.FullName
if ($urbanLink.Target) {
    $target = @($urbanLink.Target)[0]
    if (-not [System.IO.Path]::IsPathRooted($target)) {
        $target = Join-Path (Split-Path -Parent $urbanLink.FullName) $target
    }
    $urban = $target
}
$ssh = Join-Path $repoRoot "pipelines\_shared\ops\ssh\Invoke-SshRemote.ps1"
$scp = Join-Path $repoRoot "pipelines\_shared\ops\ssh\Copy-ScpToRemote.ps1"

if ($Mode -eq "deploy" -and -not $Apply) {
    throw "deploy writes the lab host. Re-run with -Mode deploy -Apply after the deploy-approval gate."
}

$secrets = $null
if ($Mode -ne "publish") {
    $secretsPath = Join-Path $GraphDir "secrets.local.yaml"
    if (-not (Test-Path -LiteralPath $secretsPath)) {
        throw "Missing secrets.local.yaml. Copy secrets.example.yaml and fill host, user, remoteWork, remoteComposeDir."
    }
    $secrets = Read-FlatYaml $secretsPath
    foreach ($key in @("host", "user", "remoteWork", "remoteComposeDir")) {
        if (-not $secrets.Contains($key) -or [string]::IsNullOrWhiteSpace([string]$secrets[$key])) {
            throw "secrets.local.yaml missing $key"
        }
    }
    if (-not $secrets.Contains("port") -or [string]::IsNullOrWhiteSpace([string]$secrets["port"])) {
        $secrets["port"] = "22"
    }
}

function Invoke-LabSsh {
    param([string] $Command, [string] $EvidenceName)
    $invokeArgs = @{
        HostName              = [string]$secrets["host"]
        User                  = [string]$secrets["user"]
        Port                  = [int]$secrets["port"]
        RemoteCommand         = $Command
        RepoRoot              = $repoRoot
        ConnectTimeoutSeconds = 30
    }
    if (-not [string]::IsNullOrWhiteSpace($EvidenceName)) {
        $invokeArgs.EvidenceDir = Join-Path $runDir $EvidenceName
    }
    if ($secrets.Contains("password") -and -not [string]::IsNullOrWhiteSpace([string]$secrets["password"])) {
        $invokeArgs.Password = [string]$secrets["password"]
    }
    return (& $ssh @invokeArgs)
}

function Invoke-LabScp {
    param([string[]] $Paths)
    $copyArgs = @{
        HostName      = [string]$secrets["host"]
        User          = [string]$secrets["user"]
        Port          = [int]$secrets["port"]
        LocalPath     = $Paths
        RemoteDir     = ([string]$secrets["remoteWork"] -replace '\\', '/')
        RepoRoot      = $repoRoot
        EvidenceDir   = Join-Path $runDir "scp"
    }
    if ($secrets.Contains("password") -and -not [string]::IsNullOrWhiteSpace([string]$secrets["password"])) {
        $copyArgs.Password = [string]$secrets["password"]
    }
    & $scp @copyArgs
}

$bundlePath = $null
if ($Mode -ne "verify") {
    $stage = Join-Path $prepare "stage"
    New-Item -ItemType Directory -Force -Path (Join-Path $stage "services") | Out-Null
    $adminClient = Join-Path $urban "src\UrbanManagement.Admin\client"
    if (Test-Path (Join-Path $adminClient "package.json")) {
        Write-Host "[lab-138] npm run build (Admin client)"
        Push-Location -LiteralPath $adminClient
        try {
            & npm run build
            if ($LASTEXITCODE -ne 0) { throw "Admin client build failed: $LASTEXITCODE" }
        }
        finally {
            Pop-Location
        }
    }
    $client = Join-Path $urban "src\UrbanManagement.Recycle\client"
    if (Test-Path (Join-Path $client "package.json")) {
        Write-Host "[lab-138] npm run build (Recycle client)"
        Push-Location -LiteralPath $client
        try {
            & npm run build
            if ($LASTEXITCODE -ne 0) { throw "Recycle client build failed: $LASTEXITCODE" }
        }
        finally {
            Pop-Location
        }
    }
    foreach ($service in $Services) {
        $proj = Join-Path $urban ("src\UrbanManagement.{0}\UrbanManagement.{0}.csproj" -f $service)
        $out = Join-Path $stage ("services\" + $service)
        Write-Host "[lab-138] publish $service"
        & dotnet publish $proj -c Release -o $out
        if ($LASTEXITCODE -ne 0) { throw "publish $service failed: $LASTEXITCODE" }
    }
    Copy-Item -LiteralPath (Join-Path $urban "deploy\docker\Dockerfile") -Destination (Join-Path $stage "Dockerfile")
    $entrypointPath = Join-Path $urban "deploy\docker\docker-entrypoint.sh"
    if (Test-Path -LiteralPath $entrypointPath) {
        Copy-Item -LiteralPath $entrypointPath -Destination (Join-Path $stage "docker-entrypoint.sh")
    }
    $bundlePath = Join-Path $prepare "bundle.tgz"
    if (Test-Path -LiteralPath $bundlePath) { Remove-Item -LiteralPath $bundlePath -Force }
    & tar.exe -czf $bundlePath -C $stage .
    if ($LASTEXITCODE -ne 0) { throw "tar failed: $LASTEXITCODE" }
    $bundle = Get-Item -LiteralPath $bundlePath
    Write-Utf8 (Join-Path $prepare "build.json") (($bundle | Select-Object Name, Length | ConvertTo-Json) + "`n")
}

$result = "unknown"
$detail = "local bundle only"
$remoteWork = $null
if ($Mode -eq "deploy" -and $Apply) {
    $remoteWork = [string]$secrets["remoteWork"]
    $ready = "New-Item -ItemType Directory -Force -Path '$remoteWork' | Out-Null; Write-Output 'remote_ready'"
    Invoke-LabSsh -Command ("powershell -NoProfile -EncodedCommand " + (ConvertTo-EncodedCommand $ready)) -EvidenceName "ssh-ready" | Out-Null
}

if ($Mode -eq "deploy" -and $Apply) {
    $remoteBundle = Join-Win $remoteWork "bundle.tgz"
    $remoteScript = Join-Win $remoteWork "remote-lab-138-build.ps1"
    $remoteConfig = Join-Win $remoteWork "remote-lab-138.config.json"
    $remoteLog = Join-Win $remoteWork "build.log"
    $remoteResult = Join-Win $remoteWork "build.result"
    $remoteSrc = Join-Win $remoteWork "src"
    $generated = [ordered]@{
        bundlePath      = $remoteBundle
        srcDir          = $remoteSrc
        logPath         = $remoteLog
        resultPath      = $remoteResult
        composeDir      = [string]$secrets["remoteComposeDir"]
        imageTag        = $ImageTag
        dockerConfigDir = $(if ($secrets.Contains("dockerConfigDir")) { [string]$secrets["dockerConfigDir"] } else { "" })
        services        = $Services
        composeServices = $ComposeServices
    }
    $configFile = Join-Path $prepare "remote-lab-138.config.json"
    Write-Utf8 $configFile (($generated | ConvertTo-Json -Depth 4) + "`n")
    Invoke-LabScp -Paths @(
        $bundlePath,
        (Join-Path $PSScriptRoot "remote-lab-138-build.ps1"),
        $configFile
    )
    $launch = @"
if (Test-Path -LiteralPath '$remoteResult') { Remove-Item -LiteralPath '$remoteResult' -Force }
`$cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File $remoteScript -ConfigPath $remoteConfig'
`$created = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = `$cmd }
Write-Output ('return=' + `$created.ReturnValue)
Write-Output ('pid=' + `$created.ProcessId)
"@
    Invoke-LabSsh -Command ("powershell -NoProfile -EncodedCommand " + (ConvertTo-EncodedCommand $launch)) -EvidenceName "ssh-launch" | Out-Null
    $deadline = (Get-Date).AddMinutes($BuildTimeoutMinutes)
    $state = "RUNNING"
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 20
        $poll = @"
if (Test-Path -LiteralPath '$remoteResult') { Get-Content -LiteralPath '$remoteResult' -Raw } else { Write-Output 'RUNNING' }
"@
        $polled = Invoke-LabSsh -Command ("powershell -NoProfile -EncodedCommand " + (ConvertTo-EncodedCommand $poll))
        $state = ([string]$polled.stdout).Trim()
        Write-Host "[lab-138] remote $state"
        if ($state -like "BUILD_DONE*" -or $state -like "BUILD_FAILED*") { break }
    }
    $tail = @"
if (Test-Path -LiteralPath '$remoteLog') { Get-Content -LiteralPath '$remoteLog' -Tail 40 }
"@
    $logged = Invoke-LabSsh -Command ("powershell -NoProfile -EncodedCommand " + (ConvertTo-EncodedCommand $tail)) -EvidenceName "ssh-log"
    Write-Utf8 (Join-Path $prepare "remote-log-tail.txt") ([string]$logged.stdout)
    if ($state -notlike "BUILD_DONE*") {
        $result = "fail"
        $detail = "remote build ended as $state"
    }
}

function Read-Health([string] $Url) {
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 20
        return [ordered]@{ url = $Url; status = [int]$response.StatusCode }
    }
    catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return [ordered]@{ url = $Url; status = $status }
    }
}

$health = @()
if ($Mode -eq "verify" -or ($Mode -eq "deploy" -and $Apply -and $result -ne "fail")) {
    $health += Read-Health ("http://{0}:{1}/health/ready" -f $secrets["host"], $GatewayPort)
    $health += Read-Health ("http://{0}:{1}/health/live" -f $secrets["host"], $RecyclePort)
    Write-Utf8 (Join-Path $prepare "health.json") (($health | ConvertTo-Json) + "`n")
    $ready = @($health | Where-Object { $_.status -eq 200 }).Count -eq 2
    if ($Mode -eq "verify") {
        $result = $(if ($ready) { "pass" } else { "fail" })
        $detail = "verify health"
    }
    elseif ($ready) {
        $result = "pass"
        $detail = "images built and both health endpoints returned 200"
    }
    else {
        $result = "fail"
        $detail = "build finished but a health endpoint was not 200"
    }
}

$revision = ""
try { $revision = (& git -C $repoRoot rev-parse HEAD).Trim() } catch { $revision = "" }
$summary = [ordered]@{
    graphId    = "deploy-urban-lab-138"
    graphPath  = "pipelines/graphs/ops/deploy-urban-lab-138"
    runId      = $runId
    mode       = $Mode
    result     = $result
    detail     = $detail
    gitRevision = $revision
    imageTag   = $ImageTag
}
Write-Utf8 (Join-Path $runDir "summary.json") (($summary | ConvertTo-Json) + "`n")
Write-Utf8 (Join-Path $runDir "manifest.yaml") @"
graphId: deploy-urban-lab-138
graphPath: pipelines/graphs/ops/deploy-urban-lab-138
runId: $runId
result: $result
gitRevision: "$revision"
contractPath: pipelines/graphs/ops/deploy-urban-lab-138/contract.yaml
artifacts:
  - prepare/
  - summary.json
  - report.md
"@
Write-Utf8 (Join-Path $runDir "report.md") @"
# deploy-urban-lab-138 $runId

模式：$Mode  
结果：$result  
$detail

等待用户验收，尚未通过。请回复 pass / fail，并写明对象与原因。Agent 不判定 P3。
"@
Write-Utf8 (Join-Path $runDir "acceptance.md") @"
# Acceptance — deploy-urban-lab-138

Status: **pending**

| 项 | 值 |
|----|----|
| run | $runId |
| P0 | pending |
| P1 | pending |
| P2 | pending |
| P3 | pending（仅用户） |
| 对象 | lab host 138 / UrbanManagement images tag $ImageTag |
| 原因 | |
"@
Write-Host "[lab-138] run=$runId result=$result"
if ($result -eq "fail") { exit 1 }
