# tools/check/check.ps1
# Publication hygiene checks for P1 (Accountable Entities)
# WHY: Ensures paper01 adheres to scope constraints (no drift into other papers)
# OBS: Scans LaTeX sources for terms that often indicate ontological / scope drift
# REQ: Keep paths explicit at the top so repo moves are easy to update later

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# EXPLICIT PATHS (edit these when the repo layout changes)
# =============================================================================

# Repo root: tools\check\check.ps1 -> repo root is two levels up
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..") | Select-Object -ExpandProperty Path

$FoundationsDir = Join-Path $RepoRoot "foundations"

# Current paper location (matches the build script you just updated)
$Paper01Dir = Join-Path $FoundationsDir "paper01"

# =============================================================================
# VALIDATE INPUTS EARLY
# =============================================================================

if (-not (Test-Path -LiteralPath $FoundationsDir)) {
    throw "Missing foundations directory at: $FoundationsDir"
}
if (-not (Test-Path -LiteralPath $Paper01Dir)) {
    throw "Missing paper01 directory at: $Paper01Dir"
}

$Files = Get-ChildItem -Path $Paper01Dir -Recurse -Include *.tex -File -ErrorAction Stop
if (-not $Files -or $Files.Count -eq 0) {
    throw "No .tex files found under: $Paper01Dir"
}

# =============================================================================
# DRIFT TERMS
# =============================================================================

$ForbiddenGroups = @{
    "Category theory (P2 territory)"               = @(
        "morphism",
        "functor",
        "natural transformation",
        "composition",
        "bicategory",
        "2-morphism"
    )
    "Exchange semantics (P2 territory)"            = @(
        "exchange pattern",
        "admissibility",
        "canonicalization",
        "normalization"
    )
    "Explanation semantics (P3 territory)"         = @(
        "explanation",
        "explanatory",
        "vertical domain",
        "fibered",
        "CTag",
        "spine"
    )
    "Causal or normative language (ontology risk)" = @(
        "causes",
        "leads to",
        "results in",
        "determines",
        "effective",
        "efficient"
    )
}

Write-Host ""
Write-Host "=== P1 Ontology Drift Scan ==="
Write-Host "Paper directory: $Paper01Dir"
Write-Host ""

foreach ($group in $ForbiddenGroups.Keys) {
    Write-Host ">> $group"
    foreach ($term in $ForbiddenGroups[$group]) {
        # Escape any regex-special chars in term, then wrap with \b boundaries.
        # Note: \b boundaries are imperfect for multi-word phrases, but we keep the
        # old behavior for now (as requested). We can refactor later.
        $escaped = [regex]::Escape($term)
        $pattern = "\b$escaped\b"

        foreach ($file in $Files) {
            $searchResults = Select-String -Path $file.FullName -Pattern $pattern -CaseSensitive:$false -ErrorAction SilentlyContinue
            foreach ($m in $searchResults) {
                Write-Host "  $($file.Name):$($m.LineNumber)  '$term'"
            }
        }
    }
    Write-Host ""
}

Write-Host "Scan complete."
Write-Host ""
