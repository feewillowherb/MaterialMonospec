[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Database,
    [Parameter(Mandatory)][string] $LogRoot,
    [ValidateRange(1, 1000)][int] $Cycles = 100,
    [switch] $Fast
)

$ErrorActionPreference = 'Stop'
$databasePath = (Resolve-Path -LiteralPath $Database).Path
$logsPath = (Resolve-Path -LiteralPath $LogRoot).Path
$graph = Split-Path -Parent $PSScriptRoot
$pipelines = (Resolve-Path (Join-Path $graph '../../..')).Path
$repo = Split-Path -Parent $pipelines
$revision = & git -C (Join-Path $repo 'repos/MaterialClient') rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve MaterialClient revision.' }
$run = Join-Path $graph ('runs/' + (Get-Date -Format 'yyyy-MM-ddTHHmmss'))

Push-Location $pipelines
try {
    $null = & pnpm exec tsx --version
    if ($LASTEXITCODE -ne 0) {
        & pnpm install
        if ($LASTEXITCODE -ne 0) { throw 'pnpm install failed.' }
    }
    $settleOverride = if ($Fast) { '0' } else { 'default' }
    & pnpm exec tsx (Join-Path $PSScriptRoot 'probe.ts') $run $databasePath $logsPath $revision $Cycles $settleOverride
    $code = $LASTEXITCODE
}
finally { Pop-Location }
Write-Output $run
exit $code
