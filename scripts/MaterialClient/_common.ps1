# Shared helpers for MaterialClient build/start scripts under MaterialMonospec.
# Dot-source from sibling scripts only.

$ErrorActionPreference = 'Stop'

function Get-MaterialMonospecRoot {
    # scripts/MaterialClient -> MaterialMonospec
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-MaterialClientRepoRoot {
    $root = Join-Path (Get-MaterialMonospecRoot) 'repos\MaterialClient'
    if (-not (Test-Path -LiteralPath $root)) {
        throw "MaterialClient repo not found: $root"
    }
    return (Resolve-Path -LiteralPath $root).Path
}

function Get-MaterialClientBuildOutDir {
    param(
        [Parameter(Mandatory)]
        [string] $RepoRoot
    )
    # Align with repos/MaterialClient/AGENTS.md — fixed output to avoid file locks.
    return (Join-Path $RepoRoot '.build-verify')
}

function Invoke-MaterialClientBuild {
    param(
        [Parameter(Mandatory)]
        [string] $ProjectRelativePath,

        [Parameter(Mandatory)]
        [string] $ExpectedExeName,

        [ValidateSet('Debug', 'Release')]
        [string] $Configuration = 'Debug'
    )

    $repoRoot = Get-MaterialClientRepoRoot
    $projectPath = Join-Path $repoRoot $ProjectRelativePath
    if (-not (Test-Path -LiteralPath $projectPath)) {
        throw "Project not found: $projectPath"
    }

    $outDir = Get-MaterialClientBuildOutDir -RepoRoot $repoRoot
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    Write-Host "Building $ProjectRelativePath ($Configuration) -> $outDir"
    & dotnet build $projectPath -c $Configuration -o $outDir
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed with exit code $LASTEXITCODE"
    }

    $exePath = Join-Path $outDir $ExpectedExeName
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "Build succeeded but exe missing: $exePath"
    }

    Write-Host "OK: $exePath"
    return $exePath
}

function Start-MaterialClientApp {
    param(
        [Parameter(Mandatory)]
        [string] $ProjectRelativePath,

        [Parameter(Mandatory)]
        [string] $ExeName,

        [ValidateSet('Debug', 'Release')]
        [string] $Configuration = 'Debug',

        [switch] $NoBuild,

        [switch] $Wait
    )

    $repoRoot = Get-MaterialClientRepoRoot
    $outDir = Get-MaterialClientBuildOutDir -RepoRoot $repoRoot
    $exePath = Join-Path $outDir $ExeName

    if (-not $NoBuild) {
        $exePath = Invoke-MaterialClientBuild `
            -ProjectRelativePath $ProjectRelativePath `
            -ExpectedExeName $ExeName `
            -Configuration $Configuration
    }
    elseif (-not (Test-Path -LiteralPath $exePath)) {
        throw "Exe not found (run build first or omit -NoBuild): $exePath"
    }

    Write-Host "Starting: $exePath"
    $startArgs = @{
        FilePath         = $exePath
        WorkingDirectory = $outDir
        PassThru         = $true
    }
    $proc = Start-Process @startArgs
    Write-Host "Started PID $($proc.Id)"

    if ($Wait) {
        Wait-Process -Id $proc.Id
    }

    return $proc
}
