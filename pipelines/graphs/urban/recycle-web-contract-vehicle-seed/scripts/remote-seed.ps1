# experimental
# Runs the uploaded preview or apply SQL inside the lab SQL container.
# The SA password is expanded only inside the container. This script does not print it.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
function Read-Required([string] $name) {
    $path = Join-Path $dir ($base + '.' + $name)
    if (-not (Test-Path -LiteralPath $path)) { throw "missing $name" }
    return ([System.IO.File]::ReadAllText($path)).Trim()
}
$proId = Read-Required 'proid.txt'
$mode = Read-Required 'mode.txt'
$container = Read-Required 'container.txt'
$database = Read-Required 'database.txt'
$composeDir = Read-Required 'compose-dir.txt'
if ($proId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { throw 'bad-proid' }
if ($mode -ne 'preview' -and $mode -ne 'apply') { throw 'bad-mode' }
if ($container -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,80}$') { throw 'bad-container' }
if ($database -notmatch '^[A-Za-z0-9_]{1,64}$') { throw 'bad-database' }
$composePath = Join-Path $composeDir 'compose.yaml'
if (-not (Test-Path -LiteralPath $composePath)) { throw 'compose-missing' }
$boundLines = @(Select-String -LiteralPath $composePath -Pattern 'RecyclePersistence__BoundSourceProId' | ForEach-Object { $_.Line })
if ($boundLines.Count -lt 1) { throw 'bound-missing' }
foreach ($line in $boundLines) {
    if ($line -notmatch [regex]::Escape($proId)) { throw 'bound-mismatch' }
}
$sqlName = if ($mode -eq 'apply') { 'apply.sql' } else { 'preview.sql' }
$sqlPath = Join-Path $dir ($base + '.' + $sqlName)
if (-not (Test-Path -LiteralPath $sqlPath)) { throw 'sql-missing' }
$remoteSql = '/tmp/recycle-web-contract-vehicle-seed.sql'
docker cp $sqlPath "${container}:${remoteSql}" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'sql-copy-failed' }
$bash = "SQLCMDPASSWORD=`"`$MSSQL_SA_PASSWORD`" /opt/mssql-tools18/bin/sqlcmd -b -C -S localhost -U sa -d $database -h -1 -W -f 65001 -i $remoteSql"
$output = docker exec $container bash -lc $bash | Out-String
$code = $LASTEXITCODE
docker exec -u root $container bash -lc "rm -f $remoteSql" | Out-Null
if ($code -ne 0) {
    $safe = @($output -split "`n" | Where-Object { $_ -match 'bound-5020-count|contract-conflict|vehicle-conflict|contract-update|vehicle-update' } | Select-Object -First 4)
    foreach ($line in $safe) { Write-Output $line.Trim() }
    throw 'sql-failed'
}
$keys = @('gov5020', 'contractMatch', 'contractConflict', 'vehicleMatch', 'vehicleConflict', 'detailCount', 'transporterCount')
foreach ($key in $keys) {
    $match = [regex]::Match($output, "(?m)^\s*${key}=(\d+)\s*$")
    if (-not $match.Success) { throw "count-missing $key" }
    Write-Output ("$key=" + $match.Groups[1].Value)
}
if ($mode -eq 'apply') { Write-Output 'applied=1' } else { Write-Output 'applied=0' }
