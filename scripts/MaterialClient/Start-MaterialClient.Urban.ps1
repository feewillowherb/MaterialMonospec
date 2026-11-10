<#
.SYNOPSIS
  Build (unless -NoBuild) and start MaterialClient.Urban.exe from .build-verify/Urban

.PARAMETER EnableDiagnosticHost
  Set MinimalWebHost__EnableOnStartup=true so http://localhost:9933 serves
  /api/scale/weight and /api/lpr/test-plate (needed by _tmp/diagnostic-inject).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Urban.ps1 -EnableDiagnosticHost -StopRunning
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',

    [switch] $NoBuild,

    [switch] $StopRunning,

    [switch] $ShowNuGetAudit,

    [switch] $Wait,

    [switch] $EnableDiagnosticHost
)

. (Join-Path $PSScriptRoot '_common.ps1')

if ($EnableDiagnosticHost) {
    $env:MinimalWebHost__EnableOnStartup = "true"
    if ([string]::IsNullOrWhiteSpace($env:MinimalWebHost__Urls)) {
        $env:MinimalWebHost__Urls = "http://localhost:9933"
    }
    Write-Host "MinimalWebHost__EnableOnStartup=$($env:MinimalWebHost__EnableOnStartup)"
    Write-Host "MinimalWebHost__Urls=$($env:MinimalWebHost__Urls)"
}

Start-MaterialClientApp `
    -ProjectRelativePath 'src\MaterialClient.Urban\MaterialClient.Urban.csproj' `
    -App 'Urban' `
    -ExeName 'MaterialClient.Urban.exe' `
    -Configuration $Configuration `
    -NoBuild:$NoBuild `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit `
    -Wait:$Wait | Out-Null

