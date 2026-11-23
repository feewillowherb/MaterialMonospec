# experimental
# Dry-run by default. -Apply writes the seed rows on the lab Recycle database.
[CmdletBinding()]
param(
    [switch] $Apply
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$GraphRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$PipelinesRoot = Join-Path $RepoRoot 'pipelines'
$ConfigPath = Join-Path $GraphRoot 'config.yaml'
$RunId = Get-Date -Format 'yyyy-MM-ddTHHmmss'
$RunDir = Join-Path $GraphRoot (Join-Path 'runs' $RunId)
$PrepareDir = Join-Path $RunDir 'prepare'
New-Item -ItemType Directory -Force -Path $PrepareDir | Out-Null

function Read-YamlScalar([string] $Text, [string] $Key) {
    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + ':\s*"?([^"#\r\n]+?)"?\s*(?:#.*)?$'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Write-Report([string] $Result, [string] $Reason, [hashtable] $Counts) {
    $summary = [ordered]@{
        graphId = 'recycle-web-contract-vehicle-seed'
        graphPath = 'pipelines/graphs/urban/recycle-web-contract-vehicle-seed'
        runId = $RunId
        mode = $(if ($Apply) { 'apply' } else { 'preview' })
        result = $Result
        sourceProId = $script:SourceProId
        counts = $Counts
        planned = $script:Planned
    }
    $summaryJson = $summary | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText((Join-Path $RunDir 'summary.json'), $summaryJson + "`n", [System.Text.UTF8Encoding]::new($false))
    $countLines = ($Counts.GetEnumerator() | Sort-Object Name | ForEach-Object { "- $($_.Key): $($_.Value)" }) -join "`n"
    $report = @"
# recycle-web-contract-vehicle-seed $RunId

模式：$($summary.mode)
结果：$Result
原因：$Reason

计划写入合同 $($script:Planned.contracts) 条、明细 $($script:Planned.details) 条、运输方 $($script:Planned.transporters) 条、车辆 $($script:Planned.vehicles) 条。

计数：

$countLines

等待用户验收，尚未通过。
"@
    [System.IO.File]::WriteAllText((Join-Path $RunDir 'report.md'), $report.Trim() + "`n", [System.Text.UTF8Encoding]::new($false))
    $head = ''
    try { $head = (& git -C $RepoRoot rev-parse HEAD).Trim() } catch { $head = '' }
    $manifest = @"
graphId: recycle-web-contract-vehicle-seed
graphPath: pipelines/graphs/urban/recycle-web-contract-vehicle-seed
runId: $RunId
result: $Result
gitRevision: "$head"
contractPath: pipelines/graphs/urban/recycle-web-contract-vehicle-seed/contract.yaml
artifacts:
  - prepare/plan.json
  - summary.json
  - report.md
"@
    [System.IO.File]::WriteAllText((Join-Path $RunDir 'manifest.yaml'), $manifest.Trim() + "`n", [System.Text.UTF8Encoding]::new($false))
}

$configText = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.UTF8Encoding]::new($false))
$script:SourceProId = Read-YamlScalar $configText 'sourceProId'
$fixtureRel = Read-YamlScalar $configText 'fixture'
$secretsRef = Read-YamlScalar $configText 'secretsRef'
$container = Read-YamlScalar $configText 'sqlContainer'
$database = Read-YamlScalar $configText 'database'
if ($script:SourceProId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
    throw 'config sourceProId is not a guid'
}
$secretsPath = Join-Path $GraphRoot $secretsRef
if (-not (Test-Path -LiteralPath $secretsPath)) { throw "missing secrets file: $secretsRef" }
$secretText = [System.IO.File]::ReadAllText($secretsPath, [System.Text.UTF8Encoding]::new($false))
$hostName = Read-YamlScalar $secretText 'host'
$userName = Read-YamlScalar $secretText 'user'
$password = Read-YamlScalar $secretText 'password'
$remoteWork = Read-YamlScalar $secretText 'remoteWork'
$composeDir = Read-YamlScalar $secretText 'remoteComposeDir'
$portText = Read-YamlScalar $secretText 'port'
$port = 22
if (-not [string]::IsNullOrWhiteSpace($portText)) { $port = [int]$portText }
foreach ($pair in @(
    @('host', $hostName),
    @('user', $userName),
    @('remoteWork', $remoteWork),
    @('remoteComposeDir', $composeDir))) {
    if ([string]::IsNullOrWhiteSpace($pair[1])) { throw "missing secret $($pair[0])" }
    if ($pair[1] -match '\s') { throw "secret $($pair[0]) contains spaces" }
}

$fixturePath = Join-Path $RepoRoot ($fixtureRel -replace '/', '\')
$toolPath = Join-Path $GraphRoot 'scripts\plan-seed.ts'
Push-Location $PipelinesRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $PipelinesRoot 'node_modules\tsx'))) {
        & pnpm install
        if ($LASTEXITCODE -ne 0) { throw 'pnpm install failed' }
    }
    & pnpm exec tsx $toolPath --fixture $fixturePath --proId $script:SourceProId --outDir $PrepareDir
    if ($LASTEXITCODE -ne 0) { throw 'plan failed' }
}
finally {
    Pop-Location
}
$plan = Get-Content -LiteralPath (Join-Path $PrepareDir 'plan.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:Planned = @{
    contracts = [int]$plan.planned.contracts
    vehicles = [int]$plan.planned.vehicles
    details = [int]$plan.planned.details
    transporters = [int]$plan.planned.transporters
}

$stage = Join-Path $RunDir 'upload'
New-Item -ItemType Directory -Force -Path $stage | Out-Null
$bundle = 'recycle-seed-' + $RunId
Copy-Item -LiteralPath (Join-Path $PrepareDir 'seed.preview.sql') -Destination (Join-Path $stage ($bundle + '.preview.sql'))
Copy-Item -LiteralPath (Join-Path $PrepareDir 'seed.apply.sql') -Destination (Join-Path $stage ($bundle + '.apply.sql'))
Copy-Item -LiteralPath (Join-Path $GraphRoot 'scripts\remote-seed.ps1') -Destination (Join-Path $stage ($bundle + '.ps1'))
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText((Join-Path $stage ($bundle + '.proid.txt')), $script:SourceProId, $utf8)
[System.IO.File]::WriteAllText((Join-Path $stage ($bundle + '.mode.txt')), $(if ($Apply) { 'apply' } else { 'preview' }), $utf8)
[System.IO.File]::WriteAllText((Join-Path $stage ($bundle + '.container.txt')), $container, $utf8)
[System.IO.File]::WriteAllText((Join-Path $stage ($bundle + '.database.txt')), $database, $utf8)
[System.IO.File]::WriteAllText((Join-Path $stage ($bundle + '.compose-dir.txt')), $composeDir, $utf8)

$ssh = Join-Path $RepoRoot 'pipelines\_shared\ops\ssh\Invoke-SshRemote.ps1'
$scp = Join-Path $RepoRoot 'pipelines\_shared\ops\ssh\Copy-ScpToRemote.ps1'
$sshCommon = @{
    HostName = $hostName
    User = $userName
    Password = $password
    Port = $port
    RepoRoot = $RepoRoot
    EvidenceDir = (Join-Path $RunDir 'ssh')
}
$files = Get-ChildItem -LiteralPath $stage -File | ForEach-Object { $_.FullName }
try {
& $scp @sshCommon -LocalPath $files -RemoteDir $remoteWork | Out-Null
$remote = & $ssh @sshCommon -RemoteCommand ("powershell -NoProfile -File " + $remoteWork.TrimEnd('\') + '\' + $bundle + '.ps1')
$counts = @{}
foreach ($line in ($remote.stdout -split "`n")) {
    if ($line -match '^(gov5020|contractMatch|contractConflict|vehicleMatch|vehicleConflict|detailCount|transporterCount|applied)=(\d+)\s*$') {
        $counts[$Matches[1]] = [int]$Matches[2]
    }
}
$required = @('gov5020', 'contractMatch', 'contractConflict', 'vehicleMatch', 'vehicleConflict', 'detailCount', 'transporterCount', 'applied')
foreach ($key in $required) {
    if (-not $counts.ContainsKey($key)) { throw "remote count missing: $key" }
}
$result = 'pass'
$reason = '预览计数已返回，没有写入。'
if ([int]$counts['gov5020'] -ne 1 -or [int]$counts['contractConflict'] -ne 0 -or [int]$counts['vehicleConflict'] -ne 0) {
    $result = 'blocked'
    $reason = '绑定的 5020 项目不是一条，或种子键已被其它行占用。'
}
elseif ($Apply) {
    $ok = [int]$counts['applied'] -eq 1 `
        -and [int]$counts['contractMatch'] -eq $script:Planned.contracts `
        -and [int]$counts['vehicleMatch'] -eq $script:Planned.vehicles `
        -and [int]$counts['detailCount'] -eq $script:Planned.details `
        -and [int]$counts['transporterCount'] -eq $script:Planned.transporters
    if ($ok) {
        $reason = '种子合同和车辆已写入绑定项目。'
    } else {
        $result = 'fail'
        $reason = '写入后的行数与计划不一致。'
    }
}
Write-Report $result $reason $counts
Write-Output ("result=" + $result + " run=" + $RunId)
if ($result -ne 'pass') { exit 2 }
} catch {
    if (-not (Test-Path -LiteralPath (Join-Path $RunDir 'report.md'))) {
        Write-Report 'fail' '远程执行没有返回完整计数。' @{}
    }
    throw
}
