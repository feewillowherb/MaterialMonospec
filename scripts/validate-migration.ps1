#!/usr/bin/env pwsh
# validate-migration.ps1 - Validate migration completeness
# Usage: ./scripts/validate-migration.ps1

$root = $PSScriptRoot | Split-Path -Parent
Set-Location $root

$totalChecks = 0
$passedChecks = 0
$failedChecks = 0

function Check-Condition {
    param([string]$Name, [bool]$Condition, [string]$Detail = "")
    $script:totalChecks++
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:passedChecks++
    } else {
        $msg = if ($Detail) { " - $Detail" } else { "" }
        Write-Host "  [FAIL] $Name$msg" -ForegroundColor Red
        $script:failedChecks++
    }
}

Write-Host ""
Write-Host "=== Migration Validation ===" -ForegroundColor Cyan
Write-Host "Root: $root"
Write-Host ""

# 1. Directory structure
Write-Host "--- Directory Structure ---" -ForegroundColor Yellow
Check-Condition "openspec/ exists" (Test-Path "openspec")
Check-Condition "openspec/specs/ exists" (Test-Path "openspec/specs")
Check-Condition "openspec/changes/ exists" (Test-Path "openspec/changes")
Check-Condition "openspec/changes/archive/ exists" (Test-Path "openspec/changes/archive")
Check-Condition "repos/ exists" (Test-Path "repos")

# 2. Configuration
Write-Host "--- Configuration ---" -ForegroundColor Yellow
Check-Condition "monospecs.yaml exists" (Test-Path "monospecs.yaml")
Check-Condition ".gitignore exists" (Test-Path ".gitignore")

if (Test-Path "monospecs.yaml") {
    $config = Get-Content "monospecs.yaml" -Raw
    Check-Condition "version field present" ($config -match 'version:')
    Check-Condition "commit_when_archive set to true" ($config -match 'commit_when_archive:\s*true')
}

# 3. Specs
Write-Host "--- Specs ---" -ForegroundColor Yellow
$specDirs = Get-ChildItem "openspec/specs" -Directory -ErrorAction SilentlyContinue
$specCount = if ($specDirs) { $specDirs.Count } else { 0 }
Check-Condition "Specs count >= 50 (found: $specCount)" ($specCount -ge 50)

$specsWithMd = 0
if ($specDirs) {
    foreach ($dir in $specDirs) {
        if (Test-Path "$($dir.FullName)/spec.md") {
            $specsWithMd++
        }
    }
}
Check-Condition "All specs have spec.md ($specsWithMd/$specCount)" ($specsWithMd -eq $specCount)

# 4. Archived changes
Write-Host "--- Archived Changes ---" -ForegroundColor Yellow
$archiveDirs = Get-ChildItem "openspec/changes/archive" -Directory -ErrorAction SilentlyContinue
$archiveCount = if ($archiveDirs) { $archiveDirs.Count } else { 0 }
Check-Condition "Archived changes >= 70 (found: $archiveCount)" ($archiveCount -ge 70)

# 5. Repository junctions
Write-Host "--- Repository Junctions ---" -ForegroundColor Yellow
Check-Condition "repos/MaterialClient accessible" (Test-Path "repos/MaterialClient")
Check-Condition "repos/UrbanManagement accessible" (Test-Path "repos/UrbanManagement")

# 6. Sub-repo cleanup
Write-Host "--- Sub-repo Cleanup ---" -ForegroundColor Yellow
Check-Condition "MaterialClient/openspec/ removed" (-not (Test-Path "../MaterialClient/openspec"))
Check-Condition "UrbanManagement/openspec/ removed" (-not (Test-Path "../UrbanManagement/openspec"))

# 7. Documentation
Write-Host "--- Documentation ---" -ForegroundColor Yellow
Check-Condition "AGENTS.md exists" (Test-Path "AGENTS.md")
Check-Condition "PROPOSAL_DESIGN_GUIDELINES.md exists" (Test-Path "PROPOSAL_DESIGN_GUIDELINES.md")
Check-Condition "docs/ directory exists" (Test-Path "docs")

# 8. Tools
Write-Host "--- Tools ---" -ForegroundColor Yellow
Check-Condition "scripts/validate-config.ps1 exists" (Test-Path "scripts/validate-config.ps1")
Check-Condition "scripts/validate-migration.ps1 exists" (Test-Path "scripts/validate-migration.ps1")

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Total: $totalChecks checks"
Write-Host "Passed: $passedChecks" -ForegroundColor Green
if ($failedChecks -gt 0) {
    Write-Host "Failed: $failedChecks" -ForegroundColor Red
    Write-Host ""
    Write-Host "[FAIL] Migration validation failed" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Failed: 0" -ForegroundColor Green
    Write-Host ""
    Write-Host "[PASS] Migration validation passed" -ForegroundColor Green
    exit 0
}
