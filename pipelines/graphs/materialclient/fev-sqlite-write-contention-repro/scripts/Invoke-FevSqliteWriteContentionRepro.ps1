[CmdletBinding()]
param(
    [string] $SeedDatabase = 'repos/MaterialClient/.build-verify/MaterialClient.SolidWaste/MaterialClient.db',
    [string] $BaseUrl = 'http://localhost:9933',
    [int] $LockSeconds = 45,
    [int] $SettleMs = 12000,
    [int] $ObservationTimeoutSeconds = 75
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$graph = Join-Path $root 'pipelines/graphs/materialclient/fev-sqlite-write-contention-repro'
$runId = Get-Date -Format 'yyyy-MM-ddTHHmmss'
$runDir = Join-Path $graph "runs/$runId"
if (Test-Path -LiteralPath $runDir) { throw "Run already exists; refusing to overwrite: $runId" }
$workingDir = Join-Path $runDir 'working'
$database = Join-Path $workingDir 'MaterialClient.db'
$seedPath = if ([System.IO.Path]::IsPathRooted($SeedDatabase)) { $SeedDatabase } else { Join-Path $root $SeedDatabase }
$project = Join-Path $graph 'src/FevSqliteWriteContention.csproj'
$clientStarter = Join-Path $root 'scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1'
$logRoot = Join-Path (Join-Path $root 'repos/MaterialClient/.build-verify/MaterialClient.SolidWaste') 'Logs'

Write-Host "Run: $runId"
Write-Host 'Confirm that this is a safe test environment and the SolidWaste database is configured for TestMode.'
$confirmation = Read-Host 'Type TEST to continue'
if ($confirmation -cne 'TEST') { throw 'Human safety gate not confirmed; no database or API changes were made.' }

New-Item -ItemType Directory -Path $workingDir -Force | Out-Null
Push-Location $root
try {
    dotnet run --project $project -- backup $seedPath $database
    if ($LASTEXITCODE -ne 0) { throw 'Working database backup failed.' }
}
finally { Pop-Location }

$clientProcesses = @(Get-Process -Name 'MaterialClient.SolidWaste' -ErrorAction SilentlyContinue)
if ($clientProcesses.Count -gt 0) {
    throw 'MaterialClient.SolidWaste is already running. This Graph will not stop or retarget an existing client. Close it yourself, then rerun.'
}

$previousConnection = $env:ConnectionStrings__Default
$previousHostEnabled = $env:MinimalWebHost__EnableOnStartup
$previousHostUrls = $env:MinimalWebHost__Urls
try {
    $env:ConnectionStrings__Default = "Data Source=$database"
    $env:MinimalWebHost__EnableOnStartup = 'true'
    $env:MinimalWebHost__Urls = $BaseUrl
    $launchStarted = Get-Date
    & $clientStarter -NoBuild -EnableDiagnosticHost
}
finally {
    $env:ConnectionStrings__Default = $previousConnection
    $env:MinimalWebHost__EnableOnStartup = $previousHostEnabled
    $env:MinimalWebHost__Urls = $previousHostUrls
}

Write-Host 'The client is running. If an authorization or login prompt appears, enter it yourself; this Graph will not interact with the UI.'
$apiReady = $false
$serviceReady = $false
Write-Host 'Waiting for the diagnostic API and attended weighing service. Complete any authorization/login prompt in the app; no UI actions will be automated.'
$nextNotice = (Get-Date).AddMinutes(1)
while ($true) {
    try {
        $null = Invoke-RestMethod -Method Get -Uri ($BaseUrl.TrimEnd('/') + '/') -TimeoutSec 2
        $apiReady = $true
    } catch { }
    if (Test-Path -LiteralPath $logRoot) {
        $latestLog = Get-ChildItem -LiteralPath $logRoot -Filter '*.log' -Recurse -File -ErrorAction SilentlyContinue | Where-Object LastWriteTime -GE $launchStarted | Sort-Object LastWriteTime -Descending | Select-Object -First 3
        if ($latestLog -and (Select-String -Path $latestLog.FullName -Pattern 'Started monitoring truck scale weight changes' -Quiet -ErrorAction SilentlyContinue)) { $serviceReady = $true }
    }
    if ($apiReady -and $serviceReady) { break }
    if ((Get-Date) -ge $nextNotice) {
        Write-Host 'Still waiting for the user session and weighing service to become ready. Press Ctrl+C to cancel.'
        $nextNotice = (Get-Date).AddMinutes(1)
    }
    Start-Sleep -Seconds 2
}

Push-Location $root
try {
    dotnet run --project $project -- probe $database $BaseUrl $runDir $logRoot $LockSeconds $SettleMs $ObservationTimeoutSeconds
    $probeExitCode = $LASTEXITCODE
}
finally { Pop-Location }

Write-Host "Evidence written to $runDir"
Write-Host 'Close the SolidWaste client manually when finished; this Graph will not manipulate its UI or stop the process.'
exit $probeExitCode
