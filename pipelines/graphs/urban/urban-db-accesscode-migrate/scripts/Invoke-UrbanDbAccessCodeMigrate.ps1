#Requires -Version 5.1
<#
.SYNOPSIS
  Experimental probe: copy production UrbanManagement.db snapshot, MigrateAsync via App start, verify AccessCode schema + smoke HTTP.
.DESCRIPTION
  Never writes back to the source snapshot. Evidence under runs/<ts>/. Marked experimental.
#>
[CmdletBinding()]
param(
    [string] $RunDir = "",
    [string] $SourceDb = "",
    [string] $BaseUrl = "",
    [switch] $SkipConfirm,
    [switch] $SkipBuild,
    [switch] $KeepRunning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../../../..")).Path
$ConfigPath = Join-Path $GraphRoot "config.yaml"
$SchemaScript = Join-Path $PSScriptRoot "verify-schema.mjs"

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-YamlScalarLocal {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*{0}\s*:\s*(.+)\s*$" -f [regex]::Escape($Key)
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { return $null }
    return ($m.Groups[1].Value.Trim().Trim('"').Trim("'"))
}

function Get-FileSha256Hex {
    param([string] $Path)
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return $hash.Hash.ToLowerInvariant()
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Missing config: $ConfigPath"
}
if (-not (Test-Path -LiteralPath $SchemaScript)) {
    throw "Missing schema script: $SchemaScript"
}

Write-Host "[urban-db-accesscode-migrate] experimental Invoke starting..."

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
$sourceRel = Get-YamlScalarLocal -Text $configText -Key "sourceDb"
if ([string]::IsNullOrWhiteSpace($sourceRel)) { $sourceRel = "_tmp/UrbanManagement.db" }
$baseUrlCfg = Get-YamlScalarLocal -Text $configText -Key "baseUrl"
if ([string]::IsNullOrWhiteSpace($baseUrlCfg)) { $baseUrlCfg = "http://127.0.0.1:44371" }
$umProjectRel = Get-YamlScalarLocal -Text $configText -Key "umProject"
if ([string]::IsNullOrWhiteSpace($umProjectRel)) {
    $umProjectRel = "repos/UrbanManagement/src/UrbanManagement.App/UrbanManagement.App.csproj"
}
$umContentRel = Get-YamlScalarLocal -Text $configText -Key "umContentRoot"
if ([string]::IsNullOrWhiteSpace($umContentRel)) {
    $umContentRel = "repos/UrbanManagement/src/UrbanManagement.App"
}
$healthGet = Get-YamlScalarLocal -Text $configText -Key "healthGet"
if ([string]::IsNullOrWhiteSpace($healthGet)) { $healthGet = "/" }
$weighingGet = Get-YamlScalarLocal -Text $configText -Key "weighingListGet"
if ([string]::IsNullOrWhiteSpace($weighingGet)) {
    $weighingGet = "/api/app/urban-weighing-record?MaxResultCount=1&SkipCount=0"
}
$expectedMigration = Get-YamlScalarLocal -Text $configText -Key "expectedRenameMigrationId"
if ([string]::IsNullOrWhiteSpace($expectedMigration)) {
    $expectedMigration = "20260902100000_RenameEntityBuildLicenseNoToAccessCode"
}
$workingDbName = Get-YamlScalarLocal -Text $configText -Key "workingDbName"
if ([string]::IsNullOrWhiteSpace($workingDbName)) { $workingDbName = "UrbanManagement.db" }

$secretsPath = Join-Path $GraphRoot "secrets.local.yaml"
$skipConfirmCfg = $false
if (Test-Path -LiteralPath $secretsPath) {
    $secretsText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.Encoding]::UTF8)
    $fromSecretsSource = Get-YamlScalarLocal -Text $secretsText -Key "sourceDb"
    if (-not [string]::IsNullOrWhiteSpace($fromSecretsSource)) { $sourceRel = $fromSecretsSource }
    $fromSecretsBase = Get-YamlScalarLocal -Text $secretsText -Key "baseUrl"
    if (-not [string]::IsNullOrWhiteSpace($fromSecretsBase)) { $baseUrlCfg = $fromSecretsBase }
    $skipVal = Get-YamlScalarLocal -Text $secretsText -Key "skipConfirm"
    if ($skipVal -eq "true") { $skipConfirmCfg = $true }
}

if (-not [string]::IsNullOrWhiteSpace($SourceDb)) { $sourceRel = $SourceDb }
if (-not [string]::IsNullOrWhiteSpace($BaseUrl)) { $baseUrlCfg = $BaseUrl }
if ($SkipConfirm) { $skipConfirmCfg = $true }

$baseUrl = $baseUrlCfg.Trim().TrimEnd('/')
$SourceDbPath = if ([System.IO.Path]::IsPathRooted($sourceRel)) {
    $sourceRel
} else {
    Join-Path $RepoRoot $sourceRel
}
$UmProject = Join-Path $RepoRoot $umProjectRel
$UmContentRoot = Join-Path $RepoRoot $umContentRel

if (-not (Test-Path -LiteralPath $SourceDbPath)) {
    throw "Missing source DB (human gate missing-source-db): $SourceDbPath"
}
if (-not (Test-Path -LiteralPath $UmProject)) {
    throw "Missing UM project: $UmProject"
}

if (-not $skipConfirmCfg) {
    $ans = Read-Host (
        "Will COPY '{0}' to runs/<ts>/working only (never write back), start UrbanManagement.App at {1}, MigrateAsync + schema verify. Type YES to continue" -f $SourceDbPath, $baseUrl)
    if ($ans -ne "YES") { throw "Aborted at human gate." }
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $stamp = Get-Date -Format "yyyy-MM-ddTHHmmss"
    $RunDir = Join-Path (Join-Path $GraphRoot "runs") $stamp
}
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
$PrepareDir = Join-Path $RunDir "prepare"
$SchemaDir = Join-Path $RunDir "schema"
$LogsDir = Join-Path $RunDir "logs"
$HttpDir = Join-Path $RunDir "http"
$WorkingDir = Join-Path $RunDir "working"
New-Item -ItemType Directory -Force -Path $PrepareDir, $SchemaDir, $LogsDir, $HttpDir, $WorkingDir | Out-Null

$sourceHashBefore = Get-FileSha256Hex -Path $SourceDbPath
Write-Utf8NoBom (Join-Path $PrepareDir "source-hash-before.txt") $sourceHashBefore

$WorkingDb = Join-Path $WorkingDir $workingDbName
Copy-Item -LiteralPath $SourceDbPath -Destination $WorkingDb -Force
$workingHash = Get-FileSha256Hex -Path $WorkingDb
$copyMeta = @{
    sourceDb         = $SourceDbPath
    workingDb        = $WorkingDb
    sourceHashBefore = $sourceHashBefore
    workingHash      = $workingHash
    copiedAt         = (Get-Date).ToString("o")
} | ConvertTo-Json -Depth 4
Write-Utf8NoBom (Join-Path $PrepareDir "copy-meta.json") $copyMeta

$PreSchema = Join-Path $SchemaDir "pre-schema.json"
& node $SchemaScript --db $WorkingDb --mode pre --out $PreSchema --expected-migration $expectedMigration
if ($LASTEXITCODE -ne 0) {
    throw "pre-schema verify failed (exit $LASTEXITCODE)."
}

if (-not $SkipBuild) {
    Write-Host "[urban-db-accesscode-migrate] building UrbanManagement.App..."
    $buildLog = Join-Path $LogsDir "dotnet-build.log"
    & dotnet build $UmProject -c Debug *>&1 | Tee-Object -FilePath $buildLog | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed. See $buildLog"
    }
}

# Absolute SQLite path; forward slashes avoid escape issues in env string
$workingDbUri = ($WorkingDb -replace '\\', '/')
$conn = "Data Source=$workingDbUri"
$stdoutLog = Join-Path $LogsDir "um-stdout.log"
$stderrLog = Join-Path $LogsDir "um-stderr.log"

$env:ConnectionStrings__Default = $conn
$env:ASPNETCORE_URLS = $baseUrl
$env:BasePlatformSync__Enabled = "false"
$env:BackgroundServices__Polling = "false"
$env:ASPNETCORE_ENVIRONMENT = "Development"

Write-Host "[urban-db-accesscode-migrate] starting App:"
Write-Host "  ConnectionStrings__Default=$conn"
Write-Host "  ASPNETCORE_URLS=$baseUrl"
Write-Host "  BasePlatformSync__Enabled=false; BackgroundServices__Polling=false"

# PS 5.1 / .NET Framework: use Arguments + EnvironmentVariables (not ArgumentList/Environment)
$env:ConnectionStrings__Default = $conn
$env:ASPNETCORE_URLS = $baseUrl
$env:BasePlatformSync__Enabled = "false"
$env:BackgroundServices__Polling = "false"
$env:ASPNETCORE_ENVIRONMENT = "Development"

$projArg = $UmProject
$proc = Start-Process -FilePath "dotnet" `
    -ArgumentList @("run", "--project", $projArg, "--no-build") `
    -WorkingDirectory $UmContentRoot `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru `
    -WindowStyle Hidden

function Read-LogShared {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    try {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $sr = New-Object System.IO.StreamReader($fs)
            try { return $sr.ReadToEnd() } finally { $sr.Dispose() }
        }
        finally { $fs.Dispose() }
    }
    catch {
        return ""
    }
}

$ready = $false
$migrateOk = $false
$migrateFail = $false
$lastHttpError = $null
$deadline = (Get-Date).AddMinutes(4)

Write-Host "[urban-db-accesscode-migrate] waiting for HTTP + migrate log (PID $($proc.Id))..."
while ((Get-Date) -lt $deadline) {
    if ($proc.HasExited) {
        break
    }
    $soFar = (Read-LogShared $stdoutLog) + "`n" + (Read-LogShared $stderrLog)
    if ($soFar -match "Database migration completed successfully") {
        $migrateOk = $true
    }
    if ($soFar -match "Database migration failed") {
        $migrateFail = $true
    }
    try {
        $null = Invoke-WebRequest -Uri "$baseUrl$healthGet" -Method Get -TimeoutSec 3 -UseBasicParsing
        $ready = $true
        if ($migrateOk -or $migrateFail) { break }
    }
    catch {
        $lastHttpError = $_.Exception.Message
    }
    Start-Sleep -Seconds 2
}

$l0App = $ready -and $migrateOk -and (-not $migrateFail) -and (-not $proc.HasExited)

# HTTP smoke while App still holds DB (schema verify after stop to avoid SQLite lock)
function Save-HttpEvidence {
    param([string] $Name, [string] $Uri)
    $outFile = Join-Path $HttpDir "$Name.json"
    try {
        $resp = Invoke-WebRequest -Uri $Uri -Method Get -TimeoutSec 30 -UseBasicParsing
        $body = $resp.Content
        if ($body.Length -gt 20000) { $body = $body.Substring(0, 20000) + "...[truncated]" }
        $payload = @{
            uri        = $Uri
            statusCode = [int]$resp.StatusCode
            body       = $body
            ok         = ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300)
        } | ConvertTo-Json -Depth 6
        Write-Utf8NoBom $outFile $payload
        return $payload | ConvertFrom-Json
    }
    catch {
        $payload = @{
            uri        = $Uri
            statusCode = $null
            body       = $null
            ok         = $false
            error      = $_.Exception.Message
        } | ConvertTo-Json -Depth 6
        Write-Utf8NoBom $outFile $payload
        return $payload | ConvertFrom-Json
    }
}

$rootEvidence = Save-HttpEvidence -Name "health-root" -Uri "$baseUrl$healthGet"
$listEvidence = Save-HttpEvidence -Name "weighing-list" -Uri "$baseUrl$weighingGet"
$l2List = [bool]$listEvidence.ok

if (-not $KeepRunning) {
    try {
        if (-not $proc.HasExited) {
            Write-Host "[urban-db-accesscode-migrate] stopping PID $($proc.Id) before schema verify..."
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'UrbanManagement|dotnet' -and $_.CommandLine -match 'UrbanManagement\.App' } |
                ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            Start-Sleep -Seconds 2
        }
    }
    catch {
        Write-Warning "Failed to stop process: $($_.Exception.Message)"
    }
}
else {
    Write-Host "[urban-db-accesscode-migrate] KeepRunning set; schema verify may fail under SQLite write lock."
}

# Schema verify after stop (preferred)
$PostSchema = Join-Path $SchemaDir "post-schema.json"
$schemaOk = $false
$schemaExit = 1
$schemaError = $null
for ($i = 0; $i -lt 10; $i++) {
    try {
        & node $SchemaScript --db $WorkingDb --mode post --out $PostSchema --expected-migration $expectedMigration
        $schemaExit = $LASTEXITCODE
        if ($schemaExit -eq 0) {
            $schemaOk = $true
            break
        }
    }
    catch {
        $schemaError = $_.Exception.Message
    }
    Start-Sleep -Seconds 1
}

$preObj = $null
$postObj = $null
$rowCountOk = $false
try {
    $preObj = Get-Content -LiteralPath $PreSchema -Raw | ConvertFrom-Json
    if (Test-Path -LiteralPath $PostSchema) {
        $postObj = Get-Content -LiteralPath $PostSchema -Raw | ConvertFrom-Json
    }
    if ($null -ne $preObj -and $null -ne $postObj) {
        $preN = $preObj.tables.UrbanWeighingRecords.rowCount
        $postN = $postObj.tables.UrbanWeighingRecords.rowCount
        $rowCountOk = ($null -ne $preN -and $null -ne $postN -and $preN -eq $postN)
    }
}
catch {
    $rowCountOk = $false
}

$l1 = $schemaOk -and $rowCountOk

$renameApplied = $false
if ($null -ne $postObj -and $null -ne $postObj.checks) {
    $renameApplied = [bool]$postObj.checks.renameMigrationApplied
}
$l2 = $renameApplied -and $l2List

# Source integrity
$sourceHashAfter = Get-FileSha256Hex -Path $SourceDbPath
$sourceUntouched = ($sourceHashBefore -eq $sourceHashAfter)
Write-Utf8NoBom (Join-Path $PrepareDir "source-hash-after.txt") $sourceHashAfter

$summary = [ordered]@{
    graph              = "urban-db-accesscode-migrate"
    runDir             = $RunDir
    sourceDb           = $SourceDbPath
    workingDb          = $WorkingDb
    baseUrl            = $baseUrl
    sourceUntouched    = $sourceUntouched
    processId          = $proc.Id
    processExited      = $proc.HasExited
    migrateOk          = $migrateOk
    migrateFail        = $migrateFail
    httpReady          = $ready
    lastHttpError      = $lastHttpError
    schemaOk           = $schemaOk
    schemaExit         = $schemaExit
    schemaError        = $schemaError
    rowCountOk         = $rowCountOk
    renameApplied      = $renameApplied
    levels             = @{
        L0 = ($l0App -and $sourceUntouched)
        L1 = $l1
        L2 = $l2
        L3 = "pending-user"
    }
    note               = "等待用户验收，尚未通过。"
} | ConvertTo-Json -Depth 8
Write-Utf8NoBom (Join-Path $RunDir "summary.json") $summary

$report = @"
# urban-db-accesscode-migrate report

- run: ``$RunDir``
- source: ``$SourceDbPath`` (untouched=$sourceUntouched)
- working: ``$WorkingDb``
- baseUrl: ``$baseUrl``
- migrateOk: $migrateOk / migrateFail: $migrateFail
- schemaOk: $schemaOk / rowCountOk: $rowCountOk / renameApplied: $renameApplied
- HTTP / : $($rootEvidence.ok) / weighing-list: $($listEvidence.ok)

| Level | Result |
|-------|--------|
| L0 | $($l0App -and $sourceUntouched) |
| L1 | $l1 |
| L2 | $l2 |
| L3 | pending（仅用户） |

等待用户验收，尚未通过。
请验收：pass / fail + 对象与原因。
"@
Write-Utf8NoBom (Join-Path $RunDir "report.md") $report

Write-Host $report

if (-not $sourceUntouched) {
    throw "Source DB hash changed — abort. Investigate immediately."
}

$exit = 0
if (-not ($l0App -and $sourceUntouched -and $l1 -and $l2)) {
    $exit = 1
}
Write-Host "[urban-db-accesscode-migrate] done exit=$exit"
exit $exit
