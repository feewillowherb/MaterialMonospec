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
$uploadsHost = "C:\wwwroot\UrbanManagement\Uploads"
New-Item -ItemType Directory -Force -Path $uploadsHost | Out-Null
$composeText = [System.IO.File]::ReadAllText($compose)
if ($composeText -notmatch '(?m)^  um-recycle:') { Finish "BUILD_FAILED compose_missing_um_recycle" 1 }
$newline = if ($composeText.Contains("`r`n")) { "`r`n" } else { "`n" }
$anchor = "x-uploads: &uploads${newline}  type: bind${newline}  source: C:/wwwroot/UrbanManagement/Uploads${newline}  target: /app/Uploads${newline}"
$updated = [regex]::Replace($composeText, '(?m)^x-uploads: &uploads\r?\n(?:[ ]{2}.*\r?\n)*', $anchor, 1)
if ($updated -notmatch 'source: C:/wwwroot/UrbanManagement/Uploads') { Finish "BUILD_FAILED uploads_anchor_missing" 1 }
$recycle = [regex]::Match($updated, '(?ms)^  um-recycle:\r?\n.*?(?=^  [A-Za-z0-9-]+:)')
if (-not $recycle.Success) { Finish "BUILD_FAILED recycle_block_missing" 1 }
$recycleBlock = $recycle.Value
if ($recycleBlock -notmatch '(?m)^      - \*uploads\s*$') {
    if ($recycleBlock -notmatch '(?m)^    volumes:\s*$') { Finish "BUILD_FAILED recycle_volumes_missing" 1 }
    $recycleBlock = [regex]::Replace($recycleBlock, '(?m)^    volumes:\r?\n', "    volumes:${newline}      - *uploads${newline}", 1)
    $updated = $updated.Remove($recycle.Index, $recycle.Length).Insert($recycle.Index, $recycleBlock)
}
$recycleCheck = [regex]::Match($updated, '(?ms)^  um-recycle:\r?\n.*?(?=^  [A-Za-z0-9-]+:)')
if (-not $recycleCheck.Success -or $recycleCheck.Value -notmatch '(?m)^      - \*uploads\s*$') {
    Finish "BUILD_FAILED recycle_uploads_missing" 1
}
$backup = $compose + ".before-uploads-bind"
if (-not (Test-Path -LiteralPath $backup)) {
    [System.IO.File]::Copy($compose, $backup)
}
[System.IO.File]::WriteAllText($compose, $updated, [System.Text.UTF8Encoding]::new($false))
Write-Log "uploads_bound C:/wwwroot/UrbanManagement/Uploads"

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
$mountRaw = docker inspect urbanmanagement-um-recycle-1 --format "{{range .Mounts}}{{.Type}} {{.Destination}} {{.Source}}{{println}}{{end}}"
$mountText = ([string]$mountRaw).Trim().Replace('\', '/')
$uploadsLine = ($mountText -split "`n" | Where-Object { $_ -match '(?i)\s/app/Uploads\s' } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($uploadsLine) -or $uploadsLine -notmatch '(?i)^bind\s+/app/Uploads\s+' -or $uploadsLine -notmatch '(?i)wwwroot/UrbanManagement/Uploads') {
    Write-Log ("uploads_mount " + $mountText)
    Finish "BUILD_FAILED uploads_not_windows_disk" 1
}
Write-Log "uploads_on_windows yes"
Finish "BUILD_DONE" 0
