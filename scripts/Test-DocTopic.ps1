param(
    [switch]$UpdateBaseline
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$docsRoot = Join-Path $repoRoot "docs"
$baselinePath = Join-Path $PSScriptRoot "doc-topic-baseline.txt"

function Test-TopicFolder {
    param([string]$FolderPath)
    $missing = @()
    $topicFile = Join-Path $FolderPath "topic.yaml"
    $entry = Get-ChildItem -Path $FolderPath -Filter "00-*.md" -File -ErrorAction SilentlyContinue
    if (-not $entry) {
        $missing += "missing 00-*.md"
    }
    if (-not (Test-Path $topicFile)) {
        $missing += "missing topic.yaml"
        return $missing
    }
    $text = Get-Content -Path $topicFile -Raw
    foreach ($key in @("topic:", "created:", "updated:")) {
        if ($text -notmatch "(?m)^$([regex]::Escape($key))") {
            $missing += "topic.yaml missing $key"
        }
    }
    return $missing
}

$dated = Get-ChildItem -Path $docsRoot -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}-' }
$violations = @()
foreach ($dir in $dated) {
    $problems = Test-TopicFolder -FolderPath $dir.FullName
    if ($problems.Count -gt 0) {
        $violations += [pscustomobject]@{
            Name = $dir.Name
            Problems = ($problems -join "; ")
        }
    }
}

if ($UpdateBaseline) {
    $violations.Name | Sort-Object | Set-Content -Path $baselinePath -Encoding utf8
    Write-Output "Wrote $($violations.Count) baseline entries to $baselinePath"
    exit 0
}

$baseline = @()
if (Test-Path $baselinePath) {
    $baseline = Get-Content -Path $baselinePath | Where-Object { $_ -and -not $_.StartsWith("#") }
}

$failed = $violations | Where-Object { $baseline -notcontains $_.Name }
if ($failed) {
    Write-Output "Dated topics missing the current contract:"
    $failed | ForEach-Object { Write-Output ("- {0}: {1}" -f $_.Name, $_.Problems) }
    exit 1
}

Write-Output "Doc topics match the contract ($($baseline.Count) legacy folders exempt)."
exit 0
