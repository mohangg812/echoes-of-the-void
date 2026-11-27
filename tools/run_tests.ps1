param(
    [string]$GodotPath = "godot"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "==> 1. Validating campaign JSON levels (Python)..." -ForegroundColor Cyan
python tools/validate_levels.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Get-Command $GodotPath -ErrorAction SilentlyContinue)) {
    Write-Warning "Godot CLI ('$GodotPath') not found in PATH. Skipping headless Godot tests."
    exit 0
}

Write-Host "==> 2. Running Godot unit & integration tests..." -ForegroundColor Cyan
& $GodotPath --headless --path . --script res://tests/unit_tests.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> 3. Running Godot smoke tests (all 7 campaign levels)..." -ForegroundColor Cyan
& $GodotPath --headless --path . --script res://tests/smoke.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> All local checks passed!" -ForegroundColor Green
