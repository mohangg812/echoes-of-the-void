param(
    [string]$GodotPath = "godot",
    [string]$OutFile = "export/EchoesOfTheVoid.exe"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

if (-not (Get-Command $GodotPath -ErrorAction SilentlyContinue)) {
    Write-Error "Godot CLI ('$GodotPath') not found. Pass -GodotPath C:\path\to\Godot_console.exe"
    exit 1
}

$OutDir = Split-Path -Parent $OutFile
if ($OutDir -and -not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

Write-Host "==> Exporting Windows Desktop build to $OutFile..." -ForegroundColor Cyan
& $GodotPath --headless --path . --export-release "Windows Desktop" $OutFile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Build complete: $OutFile" -ForegroundColor Green
Get-Item $OutFile | Format-List Name, Length, LastWriteTime
