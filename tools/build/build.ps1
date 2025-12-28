param(
    [switch]$NoClean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Clean and build contract
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==> Cleaning build artifacts"
& "$ScriptDir\clean.ps1"

Write-Host "==> Verifying proof contract"
& "$ScriptDir\contract.ps1"

Write-Host "==> Building LaTeX PDF"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

function Add-ToPathIfExists([string]$Dir) {
    if ([string]::IsNullOrWhiteSpace($Dir)) { return }
    if (Test-Path -LiteralPath $Dir) {
        $parts = $env:PATH -split ';'
        if (-not ($parts | Where-Object { $_ -eq $Dir })) {
            $env:PATH = $Dir + ";" + $env:PATH
        }
    }
}

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool not found on PATH: $Name"
    }
}

function Get-FirstLatexErrorLine {
    param([Parameter(Mandatory = $true)][string]$LogPath)

    if (-not (Test-Path -LiteralPath $LogPath)) { return $null }

    # TeX errors are typically lines starting with "!"
    $line = Select-String -LiteralPath $LogPath -Pattern '^\!' -SimpleMatch:$false -ErrorAction SilentlyContinue |
    Select-Object -First 1

    if ($line) { return $line.Line }
    return $null
}

function Get-FirstBibtexErrorLine {
    param([Parameter(Mandatory = $true)][string]$BlgPath)

    if (-not (Test-Path -LiteralPath $BlgPath)) { return $null }

    # Common bibtex hard errors
    $patterns = @(
        "You're missing a field name",
        "I couldn't open database file",
        "I couldn't open style file",
        "Repeated entry",
        "Illegal",
        "Warning--I didn't find a database entry"
    )

    foreach ($p in $patterns) {
        $hit = Select-String -LiteralPath $BlgPath -Pattern $p -SimpleMatch -ErrorAction SilentlyContinue |
        Select-Object -First 1
        if ($hit) { return $hit.Line }
    }

    return $null
}


function New-Directory([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path 2>$null | Out-Null
}

function Resolve-ExistingPath([string]$Path, [string]$What) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing $What at: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Invoke-OrStop {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$FailMessage
    )

    $result = & $Action
    if (-not $result) {
        Write-Fail $FailMessage
        exit 1
    }
}

function Invoke-WithBibInputs {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    $had = Test-Path Env:\BIBINPUTS
    $old = $null
    if ($had) { $old = $env:BIBINPUTS }

    try {
        $env:BIBINPUTS = $Value
        & $Action
        return [int]$LASTEXITCODE
    }
    finally {
        if ($had) {
            $env:BIBINPUTS = $old
        }
        else {
            Remove-Item Env:\BIBINPUTS -ErrorAction SilentlyContinue
        }
    }
}


# -----------------------------------------------------------------------------
# Build functions
# -----------------------------------------------------------------------------

function Build-Paper {
    param(
        [Parameter(Mandatory = $true)][string]$PaperDir,
        [Parameter(Mandatory = $true)][string]$TexFile,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    Write-Ok ""
    Write-Ok "Building $Name..."

    Push-Location $PaperDir
    try {
        # ---------------------------------------------------------------------
        # Preconditions
        # ---------------------------------------------------------------------

        $texPath = Join-Path (Get-Location) $TexFile
        if (-not (Test-Path -LiteralPath $texPath)) {
            Write-Fail "TeX file not found: $texPath"
            return $false
        }

        New-Directory "build"

        # Resolve latexmk explicitly (no aliases, no ambiguity)
        $latexmkCmd = Get-Command latexmk -ErrorAction Stop
        Write-Info ("Using latexmk: {0}" -f $latexmkCmd.Source)

        # ---------------------------------------------------------------------
        # Build
        # ---------------------------------------------------------------------


        & $latexmkCmd.Source `
            -pdf `
            -bibtex `
            -interaction=nonstopmode `
            -halt-on-error `
            -auxdir=build `
            -outdir=build `
            $TexFile

        $exitCode = [int]$LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-Fail ("FAILED: {0} (latexmk exit code {1})" -f $Name, $exitCode)
            Write-Fail ("See log: {0}\build\*.log" -f $PaperDir)
            Write-Fail ("See blg: {0}\build\*.blg" -f $PaperDir)
            return $false
        }

        # Copy standard PDF to repo root (parallel to annotated build behavior)
        $texBaseName = [System.IO.Path]::GetFileNameWithoutExtension($TexFile)
        $pdfPath = Join-Path (Join-Path (Get-Location) "build") ("{0}.pdf" -f $texBaseName)

        if (-not (Test-Path -LiteralPath $pdfPath)) {
            Write-Fail ("FAILED: {0} - expected PDF not found: {1}" -f $Name, $pdfPath)
            return $false
        }

        Copy-Item -LiteralPath $pdfPath -Destination (Join-Path $RepoRoot ("{0}.pdf" -f $texBaseName)) -Force

        Write-Ok "OK: $Name"
        return $true

    }
    catch {
        Write-Fail "FAILED: $Name (exception)"
        Write-Fail $_.Exception.Message
        return $false
    }
    finally {
        Remove-Item Env:\BIBINPUTS -ErrorAction SilentlyContinue
        Pop-Location
    }
}


function Build-Paper-Annotated {
    param(
        [Parameter(Mandatory = $true)][string]$PaperDir,
        [Parameter(Mandatory = $true)][string]$TexFile,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    Write-Ok ""
    Write-Ok "Building $Name (Annotated)..."

    $texBaseName = [System.IO.Path]::GetFileNameWithoutExtension($TexFile)
    $jobName = "${texBaseName}_annotated"
    $outDir = "build_annotated"

    function Invoke-Checked {
        param(
            [Parameter(Mandatory = $true)][string]$Step,
            [Parameter(Mandatory = $true)][scriptblock]$Action
        )

        Write-Info $Step
        & $Action
        $code = [int]$LASTEXITCODE
        if ($code -ne 0) {
            throw ("{0} failed (exit code {1})" -f $Step, $code)
        }
    }

    Push-Location $PaperDir
    try {
        $texPath = Join-Path (Get-Location) $TexFile
        if (-not (Test-Path -LiteralPath $texPath)) {
            Write-Fail "TeX file not found: $texPath"
            return $false
        }

        $pdflatexCmd = Get-Command pdflatex -ErrorAction Stop
        $bibtexCmd = Get-Command bibtex -ErrorAction Stop
        Write-Info ("Using pdflatex: {0}" -f $pdflatexCmd.Source)
        Write-Info ("Using bibtex:  {0}" -f $bibtexCmd.Source)

        New-Directory $outDir

        $auxPath = Join-Path (Join-Path (Get-Location) $outDir) ("{0}.aux" -f $jobName)
        $blgPath = Join-Path (Join-Path (Get-Location) $outDir) ("{0}.blg" -f $jobName)
        $logPath = Join-Path (Join-Path (Get-Location) $outDir) ("{0}.log" -f $jobName)
        $pdfPath = Join-Path (Join-Path (Get-Location) $outDir) ("{0}.pdf" -f $jobName)

        # Pass 1: write .aux etc.
        Invoke-Checked "pdflatex pass 1 (job=$jobName)" {
            & $pdflatexCmd.Source `
                -interaction=nonstopmode `
                -halt-on-error `
                "-jobname=$jobName" `
                "-output-directory=$outDir" `
                "\def\ANNOTATED{}\input{$TexFile}"
        }

        if (-not (Test-Path -LiteralPath $auxPath)) {
            Write-Fail "FAILED: $Name (Annotated) - missing aux file: $auxPath"
            return $false
        }

        # BibTeX: run in the output directory so it sees jobName.aux
        Push-Location $outDir
        try {
            $had = Test-Path Env:\BIBINPUTS
            $old = $null
            if ($had) { $old = $env:BIBINPUTS }

            try {
                # Allow \bibliography{bibliography/bibliography} to resolve from build_annotated/
                # by searching the paper root (..) as well as the current directory (.).
                $env:BIBINPUTS = ".;..;"
                Invoke-Checked "bibtex ($jobName)" {
                    & $bibtexCmd.Source $jobName
                }
            }
            finally {
                if ($had) { $env:BIBINPUTS = $old } else { Remove-Item Env:\BIBINPUTS -ErrorAction SilentlyContinue }
            }
        }
        finally {
            Pop-Location
        }


        # Pass 2/3: resolve citations/refs
        Invoke-Checked "pdflatex pass 2 (job=$jobName)" {
            & $pdflatexCmd.Source `
                -interaction=nonstopmode `
                -halt-on-error `
                "-jobname=$jobName" `
                "-output-directory=$outDir" `
                "\def\ANNOTATED{}\input{$TexFile}"
        }

        Invoke-Checked "pdflatex pass 3 (job=$jobName)" {
            & $pdflatexCmd.Source `
                -interaction=nonstopmode `
                -halt-on-error `
                "-jobname=$jobName" `
                "-output-directory=$outDir" `
                "\def\ANNOTATED{}\input{$TexFile}"
        }

        if (-not (Test-Path -LiteralPath $pdfPath)) {
            Write-Fail "FAILED: $Name (Annotated) - expected PDF not found: $pdfPath"
            return $false
        }

        Copy-Item -LiteralPath $pdfPath -Destination (Join-Path $RepoRoot ("{0}.pdf" -f $jobName)) -Force

        Write-Ok "OK: $Name (Annotated)"
        return $true
    }
    catch {
        Write-Fail "FAILED: $Name (Annotated)"
        Write-Fail $_.Exception.Message

        if (Test-Path -LiteralPath $logPath) {
            $first = Get-FirstLatexErrorLine -LogPath $logPath
            if ($first) {
                Write-Fail ("First TeX error: {0}" -f $first)
            }
        }

        if (Test-Path -LiteralPath $blgPath) {
            $bibFirst = Get-FirstBibtexErrorLine -BlgPath $blgPath
            if ($bibFirst) {
                Write-Fail ("First BibTeX issue: {0}" -f $bibFirst)
            }
        }

        return $false
    }
    finally {
        Pop-Location
    }
}


# -----------------------------------------------------------------------------
# Preflight: PATH + required tools
# -----------------------------------------------------------------------------

Add-ToPathIfExists (Join-Path $env:LOCALAPPDATA "Programs\MiKTeX\miktex\bin\x64")
Add-ToPathIfExists "C:\Program Files\MiKTeX\miktex\bin\x64"
Add-ToPathIfExists "C:\Program Files\MiKTeX\miktex\bin"

Assert-Command "pdflatex"
Assert-Command "bibtex"
Assert-Command "latexmk"

# -----------------------------------------------------------------------------
# Preflight: required repo layout
# -----------------------------------------------------------------------------

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$PaperDir = $RepoRoot
$PaperTex = "se100_the_ontological_neutrality_theorem.tex"
$null = Resolve-ExistingPath (Join-Path $PaperDir $PaperTex) "paper TeX file"


# -----------------------------------------------------------------------------
# Cleanup (optional)
# -----------------------------------------------------------------------------

if (-not $NoClean) {
    Write-Info "Cleaning build artifacts..."
    Get-ChildItem -Path $RepoRoot -Recurse -Include *.aux, *.bbl, *.blg, *.fdb_latexmk, *.fls, *.log, *.synctex.gz -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# Build Standard + Annotated (fail-fast)
# -----------------------------------------------------------------------------

Invoke-OrStop { Build-Paper -PaperDir $PaperDir -TexFile $PaperTex -Name "Paper 00: Neutral Ontology" -RepoRoot $RepoRoot } `
    "Stopping: Paper 00 standard build failed."

Invoke-OrStop { Build-Paper-Annotated -PaperDir $PaperDir -TexFile $PaperTex -Name "Paper 00: Neutral Ontology" -RepoRoot $RepoRoot } `
    "Stopping: Paper 00 annotated build failed."

Write-Ok ""
Write-Ok "ALL BUILDS SUCCEEDED (standard + annotated)."
exit 0
