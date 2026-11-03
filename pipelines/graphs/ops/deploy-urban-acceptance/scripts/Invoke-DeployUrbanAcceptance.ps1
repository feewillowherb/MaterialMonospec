#Requires -Version 5.1
<#
.SYNOPSIS
  Ingest cook: deploy UrbanManagement Phase 2 (gateway + ingest/console/worker/migrator + mssql + redis)
  to the Docker VM on 5333 and verify it per role.
.DESCRIPTION
  Modes:
    deploy  mutating (requires -Apply): local dotnet publish (app, gateway, import tool) -> bundle -> scp ->
            remote release, SMB automount, config from the IIS site (read-only share; local fallback), .env,
            image, mssql/redis, database/login, import into an empty database, migrator + roles + gateway,
            checks. -ResetDatabase drops the database first (human gate).
    verify  read-only: remote checks + external http://<host>:<port>/health/ready from this machine.
  Secrets: VM-generated passwords stay in /opt/urbanmanagement/.env; the local appsettings.secret.json
  (fallback only) travels on SSH stdin and is never written to evidence.
#>
[CmdletBinding()]
param(
    [ValidateSet("deploy", "verify")]
    [string] $Mode = "verify",
    [switch] $Apply,
    [switch] $ResetDatabase,
    [switch] $SkipPublish,
    [string] $RunDir = "",
    [switch] $SkipConfirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $GraphRoot "..\..\..\..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SecretsLocal = Join-Path $GraphRoot "secrets.local.yaml"
$SharedDir = Join-Path $RepoRoot "pipelines\_shared\ops\ssh"
$SharedResolve = Join-Path $SharedDir "Resolve-SshIdentity.ps1"
$SharedUnlock = Join-Path $SharedDir "Unlock-SshIdentity.ps1"
$SharedInvoke = Join-Path $SharedDir "Invoke-SshRemote.ps1"
$SharedScp = Join-Path $SharedDir "Copy-ScpToRemote.ps1"

function Get-YamlScalar {
    param([string] $Text, [string] $Key, [int] $Indent = 0)
    $pad = " " * $Indent
    $pattern = '(?m)^' + [regex]::Escape($pad) + [regex]::Escape($Key) + ':\s*(.+)$'
    if ($Text -match $pattern) {
        $v = $Matches[1].Trim()
        if ($v -match '^(.*?)\s+#') { $v = $Matches[1].Trim() }
        if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
        if ($v.StartsWith("'") -and $v.EndsWith("'")) { $v = $v.Substring(1, $v.Length - 2) }
        return $v
    }
    return $null
}

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-OrDefault {
    param([string] $Value, [string] $Default)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $Default }
    return $Value
}

function Invoke-Native {
    param([string] $Exe, [string[]] $Arguments, [string] $LogPath)
    # Windows PowerShell turns redirected native stderr into terminating errors under "Stop".
    $ErrorActionPreference = "Continue"
    & $Exe @Arguments *> $LogPath
    if ($LASTEXITCODE -ne 0) { throw "$Exe exited $LASTEXITCODE (see $LogPath)" }
}

Write-Host "[deploy-urban-acceptance] starting mode=$Mode"

if ($Mode -eq "deploy" -and -not $Apply) {
    throw "Mode 'deploy' changes the VM (fstab, /opt/urbanmanagement, containers, database). Re-run with -Apply after an explicit human gate."
}
if ($ResetDatabase -and ($Mode -ne "deploy")) { throw "-ResetDatabase only applies to deploy." }

foreach ($p in @($ConfigPath, $SharedResolve, $SharedUnlock, $SharedInvoke, $SharedScp)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Missing file: $p" }
}
if (-not (Test-Path -LiteralPath $SecretsLocal)) { throw "Missing secrets.local.yaml (copy secrets.example.yaml)." }

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$secretsText = [System.IO.File]::ReadAllText($SecretsLocal, [System.Text.Encoding]::UTF8)
function C([string] $Key, [string] $Default) { return Get-OrDefault (Get-YamlScalar $configText $Key 2) $Default }

$identityName = C "identityFileName" "docker-linux-ed25519"
$stableHost = C "stableHostAddress" "191.12.234.212"
$uploadsShare = C "uploadsShare" "um-uploads"
$wwwrootShare = C "wwwrootShare" "wwwroot"
$iisSiteDir = C "iisSiteDir" "UrbanManagement"
$credPath = C "credentialsPath" "/etc/um-uploads.cred"
$legacyRoot = C "legacyStorageRoot" "C:/wwwroot/UrbanManagement/Uploads"
$publicPort = C "publicPort" "5333"
$mssqlMemMb = C "mssqlMemoryLimitMb" "1280"
$memMinMb = C "memMinAvailableMb" "500"
$urbanRepo = Join-Path $RepoRoot ((C "urbanRepoRel" "repos/UrbanManagement") -replace '/', '\')
$sourceDb = Join-Path $RepoRoot ((C "importSourceRel" "_tmp/UrbanManagement_test.upgraded.db") -replace '/', '\')
$stageRoot = Join-Path $RepoRoot ((C "stageRootRel" "_tmp/deploy-urban") -replace '/', '\')
$remoteScript = Join-Path $GraphRoot ((C "remoteScriptRel" "scripts/remote-urban-deploy.sh") -replace '/', '\')

$hostVal = Get-YamlScalar $secretsText "host" 0
$userVal = Get-YamlScalar $secretsText "user" 0
$portVal = 0
[void][int]::TryParse((Get-OrDefault (Get-YamlScalar $secretsText "port" 0) (C "defaultPort" "2222")), [ref]$portVal)
$passVal = Get-YamlScalar $secretsText "identityPassphrase" 0
if ([string]::IsNullOrWhiteSpace($hostVal) -or [string]::IsNullOrWhiteSpace($userVal)) {
    throw "Missing SSH target. Set secrets.local.yaml host/user."
}
if ($Mode -eq "deploy" -and -not (Test-Path -LiteralPath $sourceDb)) { throw "Import source not found: $sourceDb" }

if (-not $SkipConfirm) {
    Write-Host "[deploy-urban-acceptance] target=${userVal}@${hostVal}:$portVal mode=$Mode apply=$Apply reset=$ResetDatabase"
    $ans = Read-Host "Continue? [y/N]"
    if ($ans -notmatch '^(y|yes)$') { throw "Aborted by user." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $RunDir = Join-Path $GraphRoot ("runs\" + (Get-Date -Format "yyyy-MM-ddTHHmmss"))
}
if (Test-Path -LiteralPath $RunDir) { throw "Run dir already exists (runs/ are append-only): $RunDir" }
$runId = Split-Path -Leaf $RunDir
$prepareDir = Join-Path $RunDir "prepare"
$sshDir = Join-Path $RunDir "ssh"
New-Item -ItemType Directory -Force -Path $prepareDir, $sshDir | Out-Null
Write-Host "[deploy-urban-acceptance] runDir=$RunDir"

$batchPath = $null
$identityForSsh = $identityName
$stageDir = Join-Path $stageRoot $runId
try {
    if (-not [string]::IsNullOrWhiteSpace($passVal)) {
        $unlocked = & $SharedUnlock -Passphrase $passVal -RepoRoot $RepoRoot -IdentityFileName $identityName -PassThru
        $identityForSsh = [string]$unlocked.identityFileName
        $batchPath = [string]$unlocked.identityFile
    }
    else {
        [void](& $SharedResolve -RepoRoot $RepoRoot -IdentityFileName $identityName -HardenAcl -PassThru)
    }
    $sshCommon = @{ HostName = $hostVal; User = $userVal; Port = $portVal; RepoRoot = $RepoRoot; IdentityFileName = $identityForSsh }

    $build = [ordered]@{ skipped = $true }
    if ($Mode -eq "deploy") {
        $commit = (& git -C $urbanRepo rev-parse --short HEAD).Trim()
        $branch = (& git -C $urbanRepo rev-parse --abbrev-ref HEAD).Trim()
        $dirty = [bool](& git -C $urbanRepo status --porcelain)
        $bundle = Join-Path $stageDir "bundle.tgz"
        if (-not $SkipPublish) {
            New-Item -ItemType Directory -Force -Path (Join-Path $stageDir "ctx") | Out-Null
            $ctx = Join-Path $stageDir "ctx"
            $started = Get-Date
            Write-Host "[deploy-urban-acceptance] dotnet publish (app, gateway, import tool)"
            Invoke-Native "dotnet" @("publish", (Join-Path $urbanRepo "src\UrbanManagement.App\UrbanManagement.App.csproj"), "-c", "Release", "-o", (Join-Path $ctx "app"), "--nologo", "-v", "q") (Join-Path $prepareDir "publish-app.log")
            Invoke-Native "dotnet" @("publish", (Join-Path $urbanRepo "src\UrbanManagement.Gateway\UrbanManagement.Gateway.csproj"), "-c", "Release", "-o", (Join-Path $ctx "gateway"), "--nologo", "-v", "q") (Join-Path $prepareDir "publish-gateway.log")
            Invoke-Native "dotnet" @("publish", (Join-Path $urbanRepo "tools\UrbanManagement.DataImport\UrbanManagement.DataImport.csproj"), "-c", "Release", "-o", (Join-Path $ctx "tools\import"), "--nologo", "-v", "q") (Join-Path $prepareDir "publish-import.log")
            foreach ($f in @("Dockerfile", "compose.yaml", ".env.example")) {
                Copy-Item -LiteralPath (Join-Path $urbanRepo "deploy\docker\$f") -Destination (Join-Path $ctx $f)
            }
            New-Item -ItemType Directory -Force -Path (Join-Path $ctx "ops") | Out-Null
            foreach ($script in Get-ChildItem -LiteralPath (Join-Path $urbanRepo "deploy\docker\ops") -Filter "*.sh") {
                $text = [IO.File]::ReadAllText($script.FullName).Replace("`r`n", "`n")
                [IO.File]::WriteAllText((Join-Path $ctx "ops\$($script.Name)"), $text, (New-Object Text.UTF8Encoding($false)))
            }
            Invoke-Native "tar.exe" @("-czf", $bundle, "-C", $ctx, "app", "gateway", "tools", "ops", "Dockerfile", "compose.yaml", ".env.example") (Join-Path $prepareDir "tar.log")
            $build = [ordered]@{
                skipped = $false; urbanCommit = $commit; urbanBranch = $branch; urbanDirty = $dirty
                bundleBytes = (Get-Item -LiteralPath $bundle).Length; publishSeconds = [int]((Get-Date) - $started).TotalSeconds
                secretJsonInBundle = Test-Path -LiteralPath (Join-Path $ctx "app\appsettings.secret.json")
            }
        }
        elseif (-not (Test-Path -LiteralPath $bundle)) { throw "-SkipPublish needs an existing bundle: $bundle" }
        Write-Utf8NoBom -Path (Join-Path $prepareDir "build.json") -Content ($build | ConvertTo-Json)

        [void](& $SharedInvoke @sshCommon -RemoteCommand "mkdir -p /tmp/um-deploy/$runId" -EvidenceDir (Join-Path $RunDir "ssh-stage") -SkipDestructiveCheck)
        & $SharedScp @sshCommon -LocalPath @($bundle, $sourceDb) -RemoteDir "/tmp/um-deploy/$runId" -EvidenceDir (Join-Path $RunDir "scp")
        [void](& $SharedInvoke @sshCommon -RemoteCommand "mv /tmp/um-deploy/$runId/$(Split-Path -Leaf $sourceDb) /tmp/um-deploy/$runId/source.db" -EvidenceDir (Join-Path $RunDir "ssh-stage-rename") -SkipDestructiveCheck)
    }

    $localSecret = Join-Path $urbanRepo "src\UrbanManagement.App\appsettings.secret.json"
    $stdinText = "`n"
    if ($Mode -eq "deploy" -and (Test-Path -LiteralPath $localSecret)) {
        $stdinText = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($localSecret)) + "`n"
    }
    $body = [System.IO.File]::ReadAllText($remoteScript, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n" -replace "`r", "`n"
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($body))
    $reset = $(if ($ResetDatabase) { "yes" } else { "no" })
    $remoteCommand = "bash <(echo $b64 | base64 -d) $Mode $runId $stableHost $uploadsShare $wwwrootShare $credPath $reset '$legacyRoot' $publicPort $iisSiteDir $mssqlMemMb $memMinMb"

    $probeError = $null
    $result = $null
    try {
        $result = & $SharedInvoke @sshCommon -RemoteCommand $remoteCommand -EvidenceDir $sshDir -ConnectTimeoutSeconds 20 -SkipDestructiveCheck -StdinText $stdinText
    }
    catch { $probeError = $_.Exception.Message }
    finally { $stdinText = $null }

    $stdout = ""
    if ($result) { $stdout = [string]$result.stdout }
    elseif (Test-Path (Join-Path $sshDir "stdout.txt")) { $stdout = [System.IO.File]::ReadAllText((Join-Path $sshDir "stdout.txt")) }
    $exitCode = 1
    if (Test-Path (Join-Path $sshDir "meta.json")) {
        $exitCode = [int]((Get-Content (Join-Path $sshDir "meta.json") -Raw | ConvertFrom-Json).exitCode)
    }

    $marks = [ordered]@{}
    foreach ($line in ($stdout -split "\r?\n")) {
        if ($line -match '^@@ ([A-Z0-9_]+)=(.*)$') { $marks[$Matches[1]] = $Matches[2].Trim() }
    }
    function M([string] $k) { if ($marks.Contains($k)) { return [string]$marks[$k] } return "" }

    $externalUrl = "http://${stableHost}:$publicPort/health/ready"
    $external = "unreachable"
    try {
        # A system proxy would answer for the host (e.g. 502) and hide whether the port is really reachable.
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy
        $resp = Invoke-WebRequest -Uri $externalUrl -UseBasicParsing -TimeoutSec 8
        $external = [string]$resp.StatusCode
    }
    catch {
        if ($_.Exception.Response) { $external = [string][int]$_.Exception.Response.StatusCode } else { $external = "unreachable" }
    }
    $marks["EXTERNAL_READY_HTTP"] = $external

    $rationale = @()
    $gate = $null
    $resultText = "fail"
    function N([string] $k) { $v = 0; [void][int]::TryParse((M $k), [ref]$v); return $v }
    $remoteOk = (M "DONE") -eq "yes" -and (M "READY_HTTP") -eq "200" -and (M "LIVE_HTTP") -eq "200" -and (M "GW_HEALTH_HTTP") -eq "200"
    $rolesOk = (M "ROLE_INGEST_READY") -eq "200" -and (M "ROLE_CONSOLE_READY") -eq "200" -and (M "ROLE_WORKER_READY") -eq "200" -and
        (M "MIGRATOR_EXIT") -eq "0" -and (N "LOG_MIGRATOR_MIGRATED") -ge 1 -and (M "UM_APP_PRESENT") -eq "0"
    $routingOk = (M "GW_TUS_OPTIONS_HTTP") -eq "204" -and -not [string]::IsNullOrWhiteSpace((M "GW_TUS_VERSION")) -and
        (M "GW_HUB_HTTP") -eq "400" -and (M "GW_NEGOTIATE_HTTP") -eq "200" -and (M "ROLE_INGEST_HUB") -eq "404" -and (M "ROLE_CONSOLE_HUB") -eq "400"
    $workersOk = (N "LOG_INGEST_WORKERS_SKIPPED") -ge 1 -and (N "LOG_CONSOLE_WORKERS_SKIPPED") -ge 1 -and (N "LOG_WORKER_SNAPSHOT_REGISTERED") -ge 1 -and
        ((N "LOG_INGEST_GOVSYNC_REGISTERED") + (N "LOG_CONSOLE_GOVSYNC_REGISTERED") + (N "LOG_WORKER_GOVSYNC_REGISTERED")) -eq 0
    $backplaneOk = (N "BACKPLANE_CHANNELS") -ge 1
    $backupOk = (M "BACKUP_SIDECAR") -eq "running" -and -not [string]::IsNullOrWhiteSpace((M "BACKUP_SCHEDULE"))
    $smb = @("smb2", "cifs")
    $containerOk = (M "ROLE_INGEST_UPLOADS_FS") -in $smb -and (M "ROLE_CONSOLE_UPLOADS_FS") -in $smb -and (M "ROLE_WORKER_UPLOADS_FS") -in $smb -and
        (M "CONTAINER_TUS_WRITABLE") -eq "yes" -and (M "CONTAINER_SECRET_JSON") -eq "absent" -and (M "UPLOADS_FSTYPE") -eq "cifs"
    $importOk = $Mode -eq "verify" -or (M "IMPORT") -in @("done", "skipped-nonempty")
    $memOk = (M "MEM_OK") -eq "yes"
    $stackOk = $remoteOk -and $rolesOk -and $routingOk -and $workersOk -and $backplaneOk -and $backupOk -and $containerOk -and $importOk
    if (-not $marks.Count) {
        $resultText = "blocked"
        $rationale += "SSH execution failed (exitCode=$exitCode): $probeError"
    }
    elseif ($stackOk) {
        if (-not $memOk) {
            $resultText = "blocked"; $gate = "vm-memory-below-threshold"
            $rationale += "Stack is healthy but VM available memory $(M 'MEM_AVAILABLE_MB') MB < $(M 'MEM_MIN_MB') MB (D14): VM expansion is a human decision."
        }
        elseif ($external -eq "200") { $resultText = "pass" }
        else {
            $resultText = "blocked"; $gate = "host-portproxy-required"
            $rationale += "Stack is healthy inside the VM, but $externalUrl from this machine is ${external}: host portproxy / firewall for $publicPort is a human step."
        }
    }
    else {
        if (M "FAILED_AT") { $rationale += "Remote step failed at $(M 'FAILED_AT')." }
        if (-not $remoteOk) { $rationale += "Gateway health: ready=$(M 'READY_HTTP') live=$(M 'LIVE_HTTP') gateway=$(M 'GW_HEALTH_HTTP') done=$(M 'DONE')." }
        if (-not $rolesOk) { $rationale += "Roles: ingest=$(M 'ROLE_INGEST_READY') console=$(M 'ROLE_CONSOLE_READY') worker=$(M 'ROLE_WORKER_READY') migrator exit=$(M 'MIGRATOR_EXIT') migrated=$(M 'LOG_MIGRATOR_MIGRATED') um-app present=$(M 'UM_APP_PRESENT')." }
        if (-not $routingOk) { $rationale += "Routing: tus OPTIONS=$(M 'GW_TUS_OPTIONS_HTTP') Tus-Version=$(M 'GW_TUS_VERSION') hub=$(M 'GW_HUB_HTTP') negotiate=$(M 'GW_NEGOTIATE_HTTP') ingest hub=$(M 'ROLE_INGEST_HUB') console hub=$(M 'ROLE_CONSOLE_HUB')." }
        if (-not $workersOk) { $rationale += "Workers: ingest skipped=$(M 'LOG_INGEST_WORKERS_SKIPPED') console skipped=$(M 'LOG_CONSOLE_WORKERS_SKIPPED') worker snapshot=$(M 'LOG_WORKER_SNAPSHOT_REGISTERED') govsync ingest/console/worker=$(M 'LOG_INGEST_GOVSYNC_REGISTERED')/$(M 'LOG_CONSOLE_GOVSYNC_REGISTERED')/$(M 'LOG_WORKER_GOVSYNC_REGISTERED')." }
        if (-not $backplaneOk) { $rationale += "SignalR backplane: Redis channels UM:signalr*=$(M 'BACKPLANE_CHANNELS')." }
        if (-not $backupOk) { $rationale += "Backup sidecar: state=$(M 'BACKUP_SIDECAR') schedule=$(M 'BACKUP_SCHEDULE')." }
        if (-not $containerOk) { $rationale += "Container checks: uploads fs ingest/console/worker=$(M 'ROLE_INGEST_UPLOADS_FS')/$(M 'ROLE_CONSOLE_UPLOADS_FS')/$(M 'ROLE_WORKER_UPLOADS_FS') host fs=$(M 'UPLOADS_FSTYPE') tus writable=$(M 'CONTAINER_TUS_WRITABLE') secret json=$(M 'CONTAINER_SECRET_JSON')." }
        if (-not $importOk) { $rationale += "Import: $(M 'IMPORT') exit=$(M 'IMPORT_EXIT') result=$(M 'IMPORT_RESULT')." }
    }
    $rationale += "Config source=$(M 'CONFIG_SOURCE') (IIS files: $(M 'IIS_FILES'); mount error: $(M 'IIS_MOUNT_ERROR')); Windows-path keys: $(M 'PROD_WINDOWS_PATH_KEYS')."
    $rationale += "Import=$(M 'IMPORT') rows=$(M 'IMPORT_SOURCE_ROWS') tables=$(M 'IMPORT_TABLES') blocking=$(M 'IMPORT_BLOCKING') checks failed=$(M 'IMPORT_CHECKS_FAILED')/$(M 'IMPORT_CHECKS') missing attachments=$(M 'IMPORT_MISSING_ATTACHMENTS'); DB rows now=$(M 'DB_USER_ROWS')."
    $rationale += "Logs: $(M 'LOG_ERRORS') error lines across roles. Memory available=$(M 'MEM_AVAILABLE_MB') MB (min $(M 'MEM_MIN_MB')); MSSQL cap=$(M 'MSSQL_MEMORY_LIMIT_MB') MB; $(M 'DOCKER_MEM')."

    $parse = [ordered]@{ stage = $Mode; analyzedBy = "agent"; result = $resultText; gate = $gate; markers = $marks; rationale = $rationale }
    Write-Utf8NoBom -Path (Join-Path $prepareDir "deploy-$Mode-parse.json") -Content ($parse | ConvertTo-Json -Depth 6)

    $p0 = [bool](Get-Command ssh -ErrorAction SilentlyContinue)
    $p1 = $exitCode -eq 0
    $p2 = $p1 -and $stackOk -and $memOk
    $summary = [ordered]@{
        graphId = "deploy-urban-acceptance"; graphPath = "pipelines/graphs/ops/deploy-urban-acceptance"
        runId = $runId; result = $resultText; mode = $Mode; resetDatabase = [bool]$ResetDatabase
        host = $hostVal; user = $userVal; port = $portVal; exitCode = $exitCode
        levels = [ordered]@{ P0 = $p0; P1 = $p1; P2 = $p2; P3 = "user-only" }
        gate = $gate; externalReady = $external; build = $build; error = $probeError
    }
    Write-Utf8NoBom -Path (Join-Path $RunDir "summary.json") -Content ($summary | ConvertTo-Json -Depth 6)

    $markMd = ($marks.Keys | ForEach-Object { "| $_ | $($marks[$_]) |" }) -join "`n"
    $ratMd = ($rationale | ForEach-Object { "- $_" }) -join "`n"
    Write-Utf8NoBom -Path (Join-Path $RunDir "report.md") -Content @"
# deploy-urban-acceptance report ($Mode) — Agent analysis

- run: ``$runId`` · mode: ``$Mode`` · result: ``$resultText``$(if ($gate) { " · gate: ``$gate``" })
- target: ``${userVal}@${hostVal}:$portVal`` · external: ``$externalUrl`` → ``$external``
- P0/P1/P2: $p0 / $p1 / $p2

## Rationale (Agent)

$ratMd

## Markers

| key | value |
|-----|-------|
$markMd

证据：``ssh/`` ``scp/`` ``prepare/``。Pipeline 结果不是产品 APPROVED；P3 由用户确认。
"@
    Write-Utf8NoBom -Path (Join-Path $RunDir "acceptance.md") -Content @"
# Acceptance — deploy-urban-acceptance (run $runId, mode $Mode)

| 项 | 值 |
|----|----|
| P0 | $(if ($p0) { "pass" } else { "fail" }) |
| P1 | $(if ($p1) { "pass" } else { "fail" }) |
| P2 | $(if ($p2) { "pass" } else { "fail" }) |
| 外部 ``$publicPort`` | $external |
| P3（用户采纳） | pending |
"@

    Write-Host "[deploy-urban-acceptance] result=$resultText$(if ($gate) { " gate=$gate" }) external=$external"
    if ($resultText -eq "pass") { exit 0 } else { exit 1 }
}
finally {
    if ($batchPath -and (Test-Path -LiteralPath $batchPath)) {
        & icacls.exe $batchPath /grant:r "${env:USERNAME}:(F)" | Out-Null
        Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
        Write-Host "[deploy-urban-acceptance] removed temp batch identity"
    }
}
