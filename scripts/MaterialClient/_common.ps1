# Shared helpers for MaterialClient build/start scripts under MaterialMonospec.
# Dot-source from sibling scripts only.

$ErrorActionPreference = 'Stop'

function Initialize-MaterialClientCliEnglish {
    # Force English CLI/MSBuild/NuGet messages (avoids GBK/UTF-8 mojibake on Chinese Windows).
    $env:DOTNET_CLI_UI_LANGUAGE = 'en-US'
    $env:VSLANG = '1033'
    $env:NUGET_CLI_LANGUAGE = 'en'
    $env:PreferredUILanguages = 'en-US'

    try {
        $en = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
        [System.Globalization.CultureInfo]::DefaultThreadCurrentUICulture = $en
        [System.Globalization.CultureInfo]::DefaultThreadCurrentCulture = $en
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $en
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $en
    }
    catch {
        # Ignore culture set failures on constrained hosts.
    }

    try {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    }
    catch {
        # Non-interactive hosts may not support console encoding changes.
    }
}

# Apply as soon as helpers are loaded.
Initialize-MaterialClientCliEnglish

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
        [string] $RepoRoot,

        # Per-app subdir under .build-verify so Main/Urban/Recycle do not lock each other.
        [Parameter(Mandatory)]
        [ValidateSet('MaterialClient', 'Urban', 'Recycle')]
        [string] $App
    )
    # Align with repos/MaterialClient/AGENTS.md — stay under .build-verify.
    return (Join-Path $RepoRoot ".build-verify\$App")
}

function Stop-MaterialClientLockingProcesses {
    param(
        [Parameter(Mandatory)]
        [string] $ProcessName
    )

    $procs = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) {
        return
    }

    foreach ($p in $procs) {
        Write-Host "Stopping locking process: $($p.ProcessName) (PID $($p.Id))"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 1
}

function Invoke-MaterialClientBuild {
    param(
        [Parameter(Mandatory)]
        [string] $ProjectRelativePath,

        [Parameter(Mandatory)]
        [ValidateSet('MaterialClient', 'Urban', 'Recycle')]
        [string] $App,

        [Parameter(Mandatory)]
        [string] $ExpectedExeName,

        [ValidateSet('Debug', 'Release')]
        [string] $Configuration = 'Debug',

        # Kill processes named like the exe (without .exe) before build.
        [switch] $StopRunning,

        # NuGet audit advisories often stay in OS UI language on Chinese Windows; off by default.
        [switch] $ShowNuGetAudit
    )

    $repoRoot = Get-MaterialClientRepoRoot
    $projectPath = Join-Path $repoRoot $ProjectRelativePath
    if (-not (Test-Path -LiteralPath $projectPath)) {
        throw "Project not found: $projectPath"
    }

    $outDir = Get-MaterialClientBuildOutDir -RepoRoot $repoRoot -App $App
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $procName = [System.IO.Path]::GetFileNameWithoutExtension($ExpectedExeName)
    if ($StopRunning) {
        Stop-MaterialClientLockingProcesses -ProcessName $procName
    }

    Write-Host "Building $ProjectRelativePath ($Configuration) -> $outDir"
    Initialize-MaterialClientCliEnglish

    $dotnetArgs = @(
        'build', $projectPath,
        '-c', $Configuration,
        '-o', $outDir
    )
    if (-not $ShowNuGetAudit) {
        # Avoid Chinese NuGet audit text that ignores CLI language on many Chinese Windows installs.
        $dotnetArgs += '-p:NuGetAudit=false'
    }

    # Pipe to Out-Host so build logs are not captured as function return values.
    & dotnet @dotnetArgs | Out-Host
    $buildExit = $LASTEXITCODE
    if ($buildExit -ne 0) {
        throw @"
dotnet build failed with exit code $buildExit

Common cause: MSB3027 file lock on `.build-verify\$App\*.dll` by a running client.
Close that app, or re-run with -StopRunning.
"@
    }

    $exePath = Join-Path $outDir $ExpectedExeName
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "Build succeeded but exe missing: $exePath"
    }

    Write-Host "OK: $exePath"
    # Ensure callers receive a single string path (not mixed pipeline objects).
    Write-Output -InputObject ([string]$exePath)
}

function Start-MaterialClientApp {
    param(
        [Parameter(Mandatory)]
        [string] $ProjectRelativePath,

        [Parameter(Mandatory)]
        [ValidateSet('MaterialClient', 'Urban', 'Recycle')]
        [string] $App,

        [Parameter(Mandatory)]
        [string] $ExeName,

        [ValidateSet('Debug', 'Release')]
        [string] $Configuration = 'Debug',

        [switch] $NoBuild,

        [switch] $StopRunning,

        [switch] $ShowNuGetAudit,

        [switch] $Wait
    )

    $repoRoot = Get-MaterialClientRepoRoot
    $outDir = Get-MaterialClientBuildOutDir -RepoRoot $repoRoot -App $App
    $exePath = Join-Path $outDir $ExeName

    if (-not $NoBuild) {
        $built = Invoke-MaterialClientBuild `
            -ProjectRelativePath $ProjectRelativePath `
            -App $App `
            -ExpectedExeName $ExeName `
            -Configuration $Configuration `
            -StopRunning:$StopRunning `
            -ShowNuGetAudit:$ShowNuGetAudit
        # Defensive: if anything leaked into the pipeline, take the last string.
        $exePath = @($built) | Where-Object { $_ -is [string] -and $_ } | Select-Object -Last 1
        if (-not $exePath) {
            throw "Build did not return an exe path."
        }
        $outDir = Split-Path -Parent $exePath
    }
    elseif (-not (Test-Path -LiteralPath $exePath)) {
        throw "Exe not found (run build first or omit -NoBuild): $exePath"
    }

    Write-Host "Starting: $exePath"
    $proc = Start-Process -FilePath ([string]$exePath) -WorkingDirectory ([string]$outDir) -PassThru
    Write-Host "Started PID $($proc.Id)"

    if ($Wait) {
        Wait-Process -Id $proc.Id
    }

    return $proc
}
