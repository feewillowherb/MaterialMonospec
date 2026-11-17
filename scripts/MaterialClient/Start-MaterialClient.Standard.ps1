<#
.SYNOPSIS
  Build (unless -NoBuild) and start MaterialClient.exe (Standard host) from .build-verify/MaterialClient

.DESCRIPTION
  Standard only (HostProduct.Standard). SolidWaste uses Start-MaterialClient.SolidWaste.ps1.
  Do not point this host at a SolidWaste-identity database.

.PARAMETER EnableDiagnosticHost
  Set MinimalWebHost__EnableOnStartup=true so http://localhost:9960 serves
  /api/scale/weight and /api/lpr/test-plate (needed by FEV / diagnostic probes).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Standard.ps1
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Standard.ps1 -NoBuild
  powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Standard.ps1 -EnableDiagnosticHost -StopRunning
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
        $env:MinimalWebHost__Urls = "http://localhost:9960"
    }
    Write-Host "MinimalWebHost__EnableOnStartup=$($env:MinimalWebHost__EnableOnStartup)"
    Write-Host "MinimalWebHost__Urls=$($env:MinimalWebHost__Urls)"
}

Start-MaterialClientApp `
    -ProjectRelativePath 'src\MaterialClient\MaterialClient.csproj' `
    -App 'MaterialClient' `
    -ExeName 'MaterialClient.exe' `
    -Configuration $Configuration `
    -NoBuild:$NoBuild `
    -StopRunning:$StopRunning `
    -ShowNuGetAudit:$ShowNuGetAudit `
    -Wait:$Wait | Out-Null
