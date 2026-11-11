# experimental
$ErrorActionPreference = 'Stop'
$graphRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $graphRoot '..\..\..\..')
$runId = Get-Date -Format 'yyyy-MM-ddTHHmmss'
$runDir = Join-Path $graphRoot "runs\$runId"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$proj = Join-Path $graphRoot 'src\UrbanBusyWeighingSim.csproj'
$fixture = Join-Path $graphRoot 'fixtures\scenarios.json'
$git = ''
try {
    $git = (git -C $repoRoot rev-parse --short HEAD).Trim()
} catch {
    $git = ''
}
dotnet run --project $proj --configuration Release -- --run $runDir --fixture $fixture --git $git
if ($LASTEXITCODE -ne 0) {
    Write-Error "urban-busy-weighing-sim failed: pipelines/graphs/materialclient/urban-busy-weighing-sim/runs/$runId"
}
Write-Output "pipelines/graphs/materialclient/urban-busy-weighing-sim/runs/$runId"
