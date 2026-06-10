# validate-agents-implementation.ps1
# Mechanical AGENTS.md checks for files touched by an OpenSpec change.
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/validate-agents-implementation.ps1 `
#     -ChangeName "add-foo" `
#     -FileListPath ".cursor/.opsx-verify-add-foo-files.txt" `
#     -Repos "MaterialClient,UrbanManagement"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ChangeName,

    [Parameter(Mandatory = $true)]
    [string]$FileListPath,

    [string]$Repos = "MaterialClient,UrbanManagement"
)

$ErrorActionPreference = "Stop"
$script:Violations = [System.Collections.Generic.List[object]]::new()

function Add-Violation {
    param(
        [string]$RuleId,
        [string]$Severity,
        [string]$File,
        [string]$Message
    )
    $script:Violations.Add([pscustomobject]@{
            RuleId   = $RuleId
            Severity = $Severity
            File     = $File
            Message  = $Message
        })
}

function Get-RepoRoot {
    $dir = $PSScriptRoot
    while ($dir) {
        $hasMonospecs = Test-Path (Join-Path $dir "monospecs.yaml")
        $hasAgents = Test-Path (Join-Path $dir "AGENTS.md")
        $hasOpenspec = Test-Path (Join-Path $dir "openspec")
        if ($hasMonospecs -or ($hasAgents -and $hasOpenspec)) { return $dir }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    throw "Could not locate monorepo root (expected monospecs.yaml or AGENTS.md + openspec/ above $PSScriptRoot)."
}

function Read-LinesFromFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Warning "File list not found: $Path"
        return @()
    }
    Get-Content -Path $Path -Encoding UTF8 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
}

function Test-IsMaterialClientPath {
    param([string]$RelativePath)
    $normalized = $RelativePath -replace '\\', '/'
    return $normalized -match '(?i)^repos/MaterialClient/'
}

function Test-IsUrbanPath {
    param([string]$RelativePath)
    $normalized = $RelativePath -replace '\\', '/'
    return $normalized -match '(?i)^repos/UrbanManagement/'
}

function Get-ResolvedPath {
    param(
        [string]$Root,
        [string]$RelativePath
    )
    $full = Join-Path $Root $RelativePath
    if (Test-Path -LiteralPath $full) { return $full }
    return $null
}

# --- OS-001: OpenSpec under sub-repos ---
function Test-OpenSpecInSubRepos {
    param([string[]]$Files)
    foreach ($f in $Files) {
        $n = $f -replace '\\', '/'
        if ($n -match '(?i)^repos/[^/]+/openspec/') {
            Add-Violation -RuleId "OS-001" -Severity "error" -File $f `
                -Message "OpenSpec artifacts must live only under monorepo openspec/, not in sub-repos."
        }
    }
}

# --- CS-001: tuple usage in C# ---
function Test-CSharpTupleUsage {
    param(
        [string]$Root,
        [string[]]$Files
    )
    $patterns = @(
        @{ Regex = '\bValueTuple\s*<'; Message = "ValueTuple type usage" }
        @{ Regex = '\bSystem\.Tuple\s*<'; Message = "System.Tuple type usage" }
        @{ Regex = '\((?:[\w.?]+,\s*)+[\w.?]+\)\s*\w+\s*='; Message = "Possible tuple deconstruction assignment" }
        @{ Regex = ':\s*\([^)]+\)\s*=>'; Message = "Possible tuple in lambda return" }
        @{ Regex = '(?:Task|ValueTask)\s*<\s*\([^)>]+\)\s*>'; Message = "Possible tuple inside Task<> return" }
        @{ Regex = '\)\s*\([^)]*,\s*[^)]+\)'; Message = "Possible tuple cast or conversion (review manually)" }
    )

    foreach ($f in $Files) {
        if ($f -notmatch '\.cs$') { continue }
        $full = Get-ResolvedPath -Root $Root -RelativePath $f
        if (-not $full) { continue }

        $lines = Get-Content -LiteralPath $full -Encoding UTF8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\s*//') { continue }
            foreach ($p in $patterns) {
                if ($line -match $p.Regex) {
                    Add-Violation -RuleId "CS-001" -Severity "error" -File "${f}:$($i + 1)" `
                        -Message "$($p.Message): $($line.Trim())"
                    break
                }
            }
        }
    }
}

# --- ARCH-001: ViewModel repository access ---
function Test-ViewModelRepositoryAccess {
    param(
        [string]$Root,
        [string[]]$Files
    )
    $repoPatterns = @(
        'IRepository\s*<'
        '\.GetListAsync\s*\('
        '\.InsertAsync\s*\('
        '\.UpdateAsync\s*\('
        '\.DeleteAsync\s*\('
    )

    foreach ($f in $Files) {
        if ($f -notmatch '(?i)ViewModel.*\.cs$') { continue }
        $full = Get-ResolvedPath -Root $Root -RelativePath $f
        if (-not $full) { continue }
        $text = Get-Content -LiteralPath $full -Raw -Encoding UTF8
        foreach ($pat in $repoPatterns) {
            if ($text -match $pat) {
                Add-Violation -RuleId "ARCH-001" -Severity "error" -File $f `
                    -Message "ViewModel must not use Repository directly (pattern: $pat)."
                break
            }
        }
    }
}

# --- ARCH-002: Service write methods without [UnitOfWork] (heuristic) ---
function Test-ServiceUnitOfWorkHeuristic {
    param(
        [string]$Root,
        [string[]]$Files
    )
    $writePatterns = '\.(InsertAsync|UpdateAsync|DeleteAsync)\s*\('

    foreach ($f in $Files) {
        if ($f -notmatch '(?i)Service.*\.cs$') { continue }
        $full = Get-ResolvedPath -Root $Root -RelativePath $f
        if (-not $full) { continue }
        if ($full -notmatch 'Service\.cs$') { continue }

        $lines = Get-Content -LiteralPath $full -Encoding UTF8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -notmatch $writePatterns) { continue }

            $hasUow = $false
            for ($j = $i; $j -ge [Math]::Max(0, $i - 15); $j--) {
                if ($lines[$j] -match '\[UnitOfWork\]') { $hasUow = $true; break }
                if ($lines[$j] -match '^\s*(public|private|protected|internal)\s+') { break }
            }
            if (-not $hasUow) {
                Add-Violation -RuleId "ARCH-002" -Severity "warning" -File "${f}:$($i + 1)" `
                    -Message "Service write call without nearby [UnitOfWork] (verify manually)."
            }
        }
    }
}

# --- MC-001 / MC-002: MaterialClient rules ---
function Test-MaterialClientRules {
    param(
        [string]$Root,
        [string[]]$Files
    )
    foreach ($f in $Files) {
        if (-not (Test-IsMaterialClientPath $f)) { continue }
        $full = Get-ResolvedPath -Root $Root -RelativePath $f
        if (-not $full) { continue }
        $text = Get-Content -LiteralPath $full -Raw -Encoding UTF8

        if ($f -match '(?i)ViewModel.*\.cs$' -and $text -match 'public\s+event\s+') {
            Add-Violation -RuleId "MC-001" -Severity "error" -File $f `
                -Message "ViewModel must use MessageBus, not public events."
        }

        if ($text -match 'CommunityToolkit\.Mvvm') {
            Add-Violation -RuleId "MC-002" -Severity "error" -File $f `
                -Message "Use ReactiveUI for bindings, not CommunityToolkit.Mvvm."
        }
    }
}

# --- DOC-001: tuple syntax in change design/tasks ---
function Test-ChangeDocTupleSyntax {
    param(
        [string]$Root,
        [string]$ChangeName
    )
    $changeDir = Join-Path $Root "openspec/changes/$ChangeName"
    if (-not (Test-Path $changeDir)) { return }

    $docFiles = @(
        (Join-Path $changeDir "design.md")
        (Join-Path $changeDir "tasks.md")
    )

    $docPatterns = @(
        '\(string\s*,'
        '\(int\s*,'
        '\bValueTuple\b'
        'Task\s*<\s*\('
    )

    foreach ($doc in $docFiles) {
        if (-not (Test-Path $doc)) { continue }
        $rel = $doc.Substring($Root.Length).TrimStart('\', '/')
        $lines = Get-Content -LiteralPath $doc -Encoding UTF8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($pat in $docPatterns) {
                if ($lines[$i] -match $pat) {
                    Add-Violation -RuleId "DOC-001" -Severity "warning" -File "${rel}:$($i + 1)" `
                        -Message "Possible tuple in OpenSpec doc; prefer named record in sketches."
                    break
                }
            }
        }
    }
}

# --- Main ---
$root = Get-RepoRoot
$files = Read-LinesFromFile -Path (Join-Path $root $FileListPath)
if ($files.Count -eq 0) {
    $alt = Join-Path $root $FileListPath
    if (Test-Path $alt) { $files = Read-LinesFromFile -Path $alt }
}

$repoList = $Repos -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$scopedFiles = @($files)
if ($repoList.Count -gt 0) {
    $scopedFiles = $files | Where-Object {
        $n = $_ -replace '\\', '/'
        if ($n -match '(?i)^openspec/') { return $true }
        if ($n -match '(?i)^scripts/') { return $true }
        foreach ($r in $repoList) {
            if ($n -match "(?i)^repos/$r/") { return $true }
        }
        $false
    }
}

Write-Host "AGENTS mechanical validation"
Write-Host "  Change:     $ChangeName"
Write-Host "  Files:      $($scopedFiles.Count) in scope"
Write-Host "  Checklist:  docs/agents-compliance-checklist.md"
Write-Host ""

Test-OpenSpecInSubRepos -Files $scopedFiles
Test-CSharpTupleUsage -Root $root -Files $scopedFiles
Test-ViewModelRepositoryAccess -Root $root -Files $scopedFiles
Test-ServiceUnitOfWorkHeuristic -Root $root -Files $scopedFiles
Test-MaterialClientRules -Root $root -Files $scopedFiles
Test-ChangeDocTupleSyntax -Root $root -ChangeName $ChangeName

if ($Violations.Count -eq 0) {
    Write-Host "RESULT: PASS (0 mechanical violations)"
    exit 0
}

$errors = @($Violations | Where-Object { $_.Severity -eq 'error' })
$warnings = @($Violations | Where-Object { $_.Severity -eq 'warning' })

Write-Host "RESULT: FAIL ($($errors.Count) error(s), $($warnings.Count) warning(s))"
Write-Host ""
Write-Host "| Rule ID | Severity | File | Message |"
Write-Host "|---------|----------|------|---------|"
foreach ($v in $Violations) {
    $msg = ($v.Message -replace '\|', '/')
    $file = ($v.File -replace '\|', '/')
    Write-Host "| $($v.RuleId) | $($v.Severity) | $file | $msg |"
}

if ($errors.Count -gt 0) { exit 1 }
exit 0
