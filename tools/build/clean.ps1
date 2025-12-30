# tools/build/clean.ps1
# WHY: Clean build artifacts
# Delete build/ and build_annotated/ directories

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Remove-DirectoryIfExists([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Write-Info "Removing directory: $Path"
        Remove-Item -LiteralPath $Path -Recurse -Force
        Write-Ok "Removed directory: $Path"
    } else {
        Write-Warn "Directory does not exist, skipping: $Path"
    }
}
# Clean build/ directory
Remove-DirectoryIfExists -Path "build"
# Clean build_annotated/ directory
Remove-DirectoryIfExists -Path "build_annotated"
Write-Ok "Clean completed."
