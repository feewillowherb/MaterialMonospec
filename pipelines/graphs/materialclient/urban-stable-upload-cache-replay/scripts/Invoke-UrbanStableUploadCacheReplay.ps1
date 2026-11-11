# experimental
$ErrorActionPreference = 'Stop'
$graphRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $graphRoot '..\..\..\..')
$runId = Get-Date -Format 'yyyy-MM-ddTHHmmss'
$runDir = Join-Path $graphRoot "runs\$runId"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$proj = Join-Path $graphRoot 'src\UrbanStableUploadCacheReplay.csproj'
$fixture = Join-Path $graphRoot 'fixtures\scenarios.json'
$git = ''
try {
    $git = (git -C $repoRoot rev-parse --short HEAD).Trim()
} catch {
    $git = ''
}
dotnet run --project $proj --configuration Release -- --run $runDir --fixture $fixture --git $git
if ($LASTEXITCODE -ne 0) {
    Write-Error "urban-stable-upload-cache-replay failed: pipelines/graphs/materialclient/urban-stable-upload-cache-replay/runs/$runId"
}
Write-Output "pipelines/graphs/materialclient/urban-stable-upload-cache-replay/runs/$runId"
