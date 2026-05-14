#!/usr/bin/env pwsh
# validate-monospecs.ps1 - Validate monospecs.yaml configuration file
# Usage: ./scripts/validate-config.ps1 [-ConfigPath <path>]

param(
    [string]$ConfigPath = "monospecs.yaml"
)

$errorList = @()
$warningList = @()

# Check file exists
if (-not (Test-Path $ConfigPath)) {
    Write-Host "[FAIL] Config file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$content = Get-Content $ConfigPath -Raw

# 1. Check for tab indentation
$lines = Get-Content $ConfigPath
$hasTab = $false
foreach ($line in $lines) {
    if ($line -match '^\t') {
        $hasTab = $true
        break
    }
}
if ($hasTab) {
    $errorList += "YAML should not use tab indentation, use spaces instead"
}

# 2. Check required fields
$requiredFields = @("version", "repo_dir", "commit_when_archive", "repositories")
foreach ($field in $requiredFields) {
    if ($content -notmatch "(?m)^${field}:") {
        $errorList += "Missing required field: $field"
    }
}

# 3. Check version format
if ($content -match 'version:\s*([\S]+)') {
    $version = $Matches[1]
    if ($version -notmatch '^".*"$') {
        $warningList += "version should be a quoted string, current: $version"
    }
}

# 4. Check repository paths
$repoPattern = '(?m)^\s+- path:\s+(\S+)'
$repoMatches = [regex]::Matches($content, $repoPattern)
$validTypes = @("Desktop", "WebServer", "Library", "Mobile", "Service", "Other")

foreach ($m in $repoMatches) {
    $repoPath = $m.Groups[1].Value

    # Check relative path format
    if ($repoPath -notmatch '^repos/') {
        $errorList += "Repository path should use repos/<name> format: $repoPath"
    }

    # Check absolute path
    if ($repoPath -match '^[A-Z]:\\' -or $repoPath -match '^/') {
        $errorList += "Should not use absolute path: $repoPath"
    }
}

# 5. Check type values
$typePattern = '(?m)^\s+type:\s+(\S+)'
$typeMatches = [regex]::Matches($content, $typePattern)
foreach ($m in $typeMatches) {
    $typeVal = $m.Groups[1].Value
    if ($validTypes -notcontains $typeVal) {
        $errorList += "Invalid type value: $typeVal (valid: $($validTypes -join ', '))"
    }
}

# 6. Check required fields per repository block
$repoBlockPattern = '(?ms)\s+- path:.*?(?=\s+- path:|$)'
$repoBlocks = [regex]::Matches($content, $repoBlockPattern)
$requiredRepoFields = @("path", "url", "displayName", "type")

foreach ($block in $repoBlocks) {
    $blockText = $block.Value
    foreach ($field in $requiredRepoFields) {
        if ($blockText -notmatch "(?m)\s+${field}:") {
            $warningList += "Repository config missing field: $field"
        }
    }
}

# Output results
Write-Host ""
Write-Host "=== monospecs.yaml Configuration Validation ===" -ForegroundColor Cyan
Write-Host "File: $ConfigPath"
Write-Host ""

if ($errorList.Count -eq 0 -and $warningList.Count -eq 0) {
    Write-Host "[PASS] Configuration validation passed" -ForegroundColor Green
    exit 0
}

if ($errorList.Count -gt 0) {
    Write-Host "Errors ($($errorList.Count)):" -ForegroundColor Red
    foreach ($err in $errorList) {
        Write-Host "  [X] $err" -ForegroundColor Red
    }
}

if ($warningList.Count -gt 0) {
    Write-Host "Warnings ($($warningList.Count)):" -ForegroundColor Yellow
    foreach ($warn in $warningList) {
        Write-Host "  [!] $warn" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($errorList.Count -gt 0) {
    Write-Host "[FAIL] Validation failed" -ForegroundColor Red
    exit 1
} else {
    Write-Host "[PASS] Validation passed with $($warningList.Count) warning(s)" -ForegroundColor Yellow
    exit 0
}
