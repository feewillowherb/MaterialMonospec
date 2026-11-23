#Requires -Version 5.1
<#
.SYNOPSIS
  On lab host 138: extract one publish bundle, build one image per service, recreate the stack.
.DESCRIPTION
  experimental. Uploaded by Invoke-DeployUrbanLab138.ps1. No secrets in this file.
  Each docker build sends only that service directory. Worker uses target "service"
  because this bundle does not include tools/import.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ConfigPath
)

$ErrorActionPreference = "Stop"
$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$log = [string]$config.logPath
$resultPath = [string]$config.resultPath

function Write-Log([string] $message) {
    $line = (Get-Date -Format "HH:mm:ss") + " " + $message
    [System.IO.File]::AppendAllText($log, $line + "`n", [System.Text.UTF8Encoding]::new($false))
    Write-Output $line
}

function Finish([string] $token, [int] $code) {
    Write-Log $token
    [System.IO.File]::WriteAllText($resultPath, $token, [System.Text.UTF8Encoding]::new($false))
    exit $code
}

if (-not [string]::IsNullOrWhiteSpace([string]$config.dockerConfigDir)) {
    $env:DOCKER_CONFIG = [string]$config.dockerConfigDir
}
$env:UM_TAG = [string]$config.imageTag

[System.IO.File]::WriteAllText($log, "slim_build_start`n", [System.Text.UTF8Encoding]::new($false))
$src = [string]$config.srcDir
if (Test-Path -LiteralPath $src) {
    Remove-Item -LiteralPath $src -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $src | Out-Null
tar.exe -xzf ([string]$config.bundlePath) -C $src
if ($LASTEXITCODE -ne 0) { Finish "BUILD_FAILED extract" 1 }
$recycleDll = Join-Path $src "services\Recycle\UrbanManagement.Recycle.dll"
if (-not (Test-Path -LiteralPath $recycleDll)) { Finish "BUILD_FAILED missing_recycle_dll" 1 }
Write-Log "extracted"

foreach ($service in @($config.services)) {
    $name = [string]$service
    $ignore = @("services/*", ("!services/" + $name))
    Set-Content -LiteralPath (Join-Path $src ".dockerignore") -Value $ignore -Encoding ascii
    $image = "urbanmanagement-" + $name.ToLowerInvariant() + ":" + [string]$config.imageTag
    Write-Log ("building " + $image)
    cmd /c "docker build --progress=plain --target service --build-arg SERVICE=$name -t $image `"$src`" >> `"$log`" 2>&1"
    if ($LASTEXITCODE -ne 0) { Finish ("BUILD_FAILED " + $name) 1 }
    Write-Log ("built " + $image)
}
Write-Log "images_built"

$compose = Join-Path ([string]$config.composeDir) "compose.yaml"
if (-not (Test-Path -LiteralPath $compose)) { Finish "BUILD_FAILED compose_missing" 1 }
$composeText = Get-Content -LiteralPath $compose -Raw
if ($composeText -notmatch '(?m)^  um-recycle:') { Finish "BUILD_FAILED compose_missing_um_recycle" 1 }

cmd /c "docker rm -f urbanmanagement-um-xiaoshanresource-1 >> `"$log`" 2>&1"
Write-Log "xiaoshan_container_removed_if_present"

$composeDir = [string]$config.composeDir
cmd /c "docker compose --project-directory `"$composeDir`" up -d --force-recreate --no-deps um-migrator >> `"$log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Finish "BUILD_FAILED migrator" 1 }
Write-Log "migrator_started"

$serviceArgs = (@($config.composeServices) -join " ")
cmd /c "docker compose --project-directory `"$composeDir`" up -d --force-recreate $serviceArgs >> `"$log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Finish "BUILD_FAILED compose_up" 1 }
Write-Log "compose_up"
cmd /c "docker ps --format `"{{.Names}} {{.Image}} {{.Status}} {{.Ports}}`" >> `"$log`" 2>&1"
Finish "BUILD_DONE" 0
