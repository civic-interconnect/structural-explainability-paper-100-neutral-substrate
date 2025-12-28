param(
    [switch]$NoClean
)

# WHY: Extract Title/Abstract/Keywords (front matter) and the paper contract text for review.
# OBS: Pure text parsing (no LaTeX execution). Safe on Windows/macOS/Linux.
# Output:
#   artifacts/contracts/contracts.md
#
# Usage:
#   ./tools/build/contracts.ps1
#   ./tools/build/contracts.ps1 -NoClean

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }

function New-Directory([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path 2>$null | Out-Null
}

function Read-TextFileUtf8([string]$Path) {
    # WHY: Avoid ANSI default surprises.
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function ConvertTo-LfNewlines([string]$Text) {
    # Convert CRLF/CR -> LF for consistent regex.
    return ($Text -replace "`r`n", "`n") -replace "`r", "`n"
}

function Get-FirstMatchValue([string]$Text, [string]$Pattern) {
    $m = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m.Success -and $m.Groups.Count -ge 2) {
        return $m.Groups[1].Value.Trim()
    }
    return $null
}

function Remove-TeXComments([string]$Text) {
    # Remove comments that start with % not preceded by backslash.
    $lines = (ConvertTo-LfNewlines $Text) -split "`n"
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        $l = [regex]::Replace($line, '(?<!\\)%.*$', '')
        [void]$out.Add($l)
    }
    return (($out -join "`n").Trim())
}

function Get-LaTeXCommandBody([string]$Text, [string]$CommandName) {
    # Extract \title{...}, \keywords{...}, etc.
    # NOTE: Not a full brace parser; pragmatic best-effort pull.
    $pattern = '\\' + $CommandName + '\s*\{(.*?)\}'
    return Get-FirstMatchValue -Text $Text -Pattern $pattern
}

function Get-LaTeXEnvironmentBody([string]$Text, [string]$EnvName) {
    $pattern = '\\begin\{' + $EnvName + '\}(.*?)\\end\{' + $EnvName + '\}'
    return Get-FirstMatchValue -Text $Text -Pattern $pattern
}

function Get-InputValues([string]$Text) {
    $pattern = '\\input\{([^}]+)\}'
    $rxMatches = [regex]::Matches($Text, $pattern)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($m in $rxMatches) {
        $val = $m.Groups[1].Value.Trim()
        if ($val) { [void]$out.Add($val) }
    }
    return $out
}

function Resolve-InputToTexPath([string]$PaperDir, [string]$InputValue) {
    $candidate = $InputValue
    if (-not $candidate.ToLowerInvariant().EndsWith('.tex')) {
        $candidate = $candidate + '.tex'
    }
    $path = Join-Path $PaperDir $candidate
    if (Test-Path -LiteralPath $path) {
        return (Resolve-Path -LiteralPath $path).Path
    }
    return $null
}

function Get-FrontMatter([string]$MainTexText) {
    # WHY: Avoid matching commented-out \title/\keywords etc.
    $t = Remove-TeXComments $MainTexText

    $title = Get-LaTeXCommandBody -Text $t -CommandName 'title'
    $abstract = Get-LaTeXEnvironmentBody -Text $t -EnvName 'abstract'

    $keywordsEnv = Get-LaTeXEnvironmentBody -Text $t -EnvName 'keywords'
    $keywordsCmd = Get-LaTeXCommandBody -Text $t -CommandName 'keywords'
    $keywords = $keywordsEnv
    if (-not $keywords) { $keywords = $keywordsCmd }

    return [pscustomobject]@{
        Title    = $title
        Abstract = $abstract
        Keywords = $keywords
    }
}

function Get-Contract([string]$PaperDir, [string]$MainTexText) {
    # Prefer an explicit \input{...contract...} reference.
    $inputs = Get-InputValues -Text $MainTexText
    $contractPath = $null

    foreach ($i in $inputs) {
        if ($i -match 'contract') {
            $resolved = Resolve-InputToTexPath -PaperDir $PaperDir -InputValue $i
            if ($resolved) { $contractPath = $resolved; break }
        }
    }

    # Fallback: first *contract*.tex in the folder.
    if (-not $contractPath) {
        $fallback = Get-ChildItem -LiteralPath $PaperDir -Filter '*contract*.tex' -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        Select-Object -First 1
        if ($fallback) { $contractPath = $fallback.FullName }
    }

    if (-not $contractPath) {
        return [pscustomobject]@{ Path = $null; Text = $null }
    }

    $t = ConvertTo-LfNewlines (Read-TextFileUtf8 -Path $contractPath)
    return [pscustomobject]@{ Path = $contractPath; Text = $t }
}

function Find-MainTex([string]$PaperDir) {
    # Prefer 00P*.tex, else *_theorem*.tex, else first *.tex.
    $main = Get-ChildItem -LiteralPath $PaperDir -Filter '00P*.tex' -File -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object -First 1
    if (-not $main) {
        $main = Get-ChildItem -LiteralPath $PaperDir -Filter '*theorem*.tex' -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        Select-Object -First 1
    }
    if (-not $main) {
        $main = Get-ChildItem -LiteralPath $PaperDir -Filter '*.tex' -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        Select-Object -First 1
    }
    return $main
}

function Write-Utf8File([string]$Path, [string]$Content) {
    $dir = Split-Path -Parent $Path
    if ($dir) { New-Directory $dir }
    $c = ConvertTo-LfNewlines $Content
    [System.IO.File]::WriteAllText($Path, $c, (New-Object System.Text.UTF8Encoding($false)))
}

# =============================================================================
# Locate repo + output paths
# =============================================================================

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..') | Select-Object -ExpandProperty Path

$ArtifactsDir = Join-Path $RepoRoot 'artifacts'
$OutDir = Join-Path $ArtifactsDir 'contracts'
$OutPath = Join-Path $OutDir 'contracts.md'

if (-not $NoClean) {
    if (Test-Path -LiteralPath $OutDir) {
        Write-Info 'Cleaning contracts artifacts...'
        Remove-Item -LiteralPath $OutDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

New-Directory $OutDir

# =============================================================================
# Find main TeX in repo root (no paper folder layout)
# =============================================================================

$paperDir = $RepoRoot
$paperName = Split-Path -Leaf $paperDir

$main = Find-MainTex -PaperDir $paperDir
if (-not $main) {
    throw ('No .tex files found in repo root: {0}' -f $RepoRoot)
}

$mainPath = $main.FullName
$mainText = ConvertTo-LfNewlines (Read-TextFileUtf8 -Path $mainPath)

$fm = Get-FrontMatter -MainTexText $mainText
$contract = Get-Contract -PaperDir $paperDir -MainTexText $mainText

# =============================================================================
# Render Markdown
# =============================================================================

$fence = '```'   # IMPORTANT: single quotes so PowerShell does not treat backticks as escapes.

$doc = New-Object System.Collections.Generic.List[string]
[void]$doc.Add('# AUTOGENERATED Paper contract snapshot: DO NOT EDIT')
[void]$doc.Add('')
[void]$doc.Add(('Generated: {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
[void]$doc.Add('')
[void]$doc.Add(('## {0}' -f $paperName))
[void]$doc.Add('')
[void]$doc.Add(('- Main TeX: {0}' -f (Split-Path -Leaf $mainPath)))
[void]$doc.Add('')

[void]$doc.Add('### Title')
[void]$doc.Add('')
if ($fm.Title) {
    [void]$doc.Add($fence)
    [void]$doc.Add((Remove-TeXComments $fm.Title))
    [void]$doc.Add($fence)
}
else {
    [void]$doc.Add('_Not found_')
}
[void]$doc.Add('')

[void]$doc.Add('### Abstract')
[void]$doc.Add('')
if ($fm.Abstract) {
    [void]$doc.Add($fence)
    [void]$doc.Add((Remove-TeXComments $fm.Abstract))
    [void]$doc.Add($fence)
}
else {
    [void]$doc.Add('_Not found_')
}
[void]$doc.Add('')

if ($fm.Keywords) {
    [void]$doc.Add('### Keywords')
    [void]$doc.Add('')
    [void]$doc.Add($fence)
    [void]$doc.Add((Remove-TeXComments $fm.Keywords))
    [void]$doc.Add($fence)
    [void]$doc.Add('')
}

[void]$doc.Add('### Contract')
[void]$doc.Add('')
if ($contract.Path -and $contract.Text) {
    [void]$doc.Add(('- Contract file: {0}' -f (Split-Path -Leaf $contract.Path)))
    [void]$doc.Add('')
    [void]$doc.Add($fence)
    [void]$doc.Add((Remove-TeXComments $contract.Text))
    [void]$doc.Add($fence)
}
else {
    [void]$doc.Add('_Not found_')
}
[void]$doc.Add('')

Write-Utf8File -Path $OutPath -Content ($doc -join "`n")
Write-Ok ('Wrote: {0}' -f $OutPath)
