$ErrorActionPreference = "Stop"

# scripts/ -> project root
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Set-Location $ProjectRoot

Write-Host "Generating C3 documentation..."
Write-Host "Project root: $ProjectRoot"

$Sources = Get-ChildItem -Path "./src" -Recurse -Filter *.c3 -File |
    ForEach-Object { $_.FullName }

if (-not $Sources) {
    Write-Host "Error: No .c3 files found in src."
    exit 1
}

& c3c docgen @Sources --emit-stdlib=no

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: c3c docgen failed."
    exit $LASTEXITCODE
}

Write-Host "Documentation generated successfully."