$ErrorActionPreference = "Stop"

$ProjectFile = "project.json"
$PyProjectFile = "pyproject.toml"

if (-not (Test-Path -Path $ProjectFile -PathType Leaf)) {
    Write-Host "Error: $ProjectFile not found."
    Write-Host "Please run this script from the project root."
    exit 1
}

if (-not (Test-Path -Path $PyProjectFile -PathType Leaf)) {
    Write-Host "Error: $PyProjectFile not found."
    Write-Host "Please run this script from the project root."
    exit 1
}

# C3 project.json allows comments, so extract the version with regex.
$C3Version = $null

foreach ($Line in Get-Content $ProjectFile) {
    if ($Line -match '^\s*"version"\s*:\s*"([^"]+)"') {
        $C3Version = $Matches[1]
        break
    }
}

if ([string]::IsNullOrEmpty($C3Version)) {
    Write-Host "Error: Could not find version in $ProjectFile."
    exit 1
}

# Extract version from the [project] section of pyproject.toml.
$InProject = $false
$PyProjectVersion = $null

foreach ($Line in Get-Content $PyProjectFile) {
    if ($Line -match '^\[project\]') {
        $InProject = $true
        continue
    }

    if ($Line -match '^\[') {
        $InProject = $false
    }

    if ($InProject -and $Line -match '^\s*version\s*=\s*"([^"]+)"') {
        $PyProjectVersion = $Matches[1]
        break
    }
}

if ([string]::IsNullOrEmpty($PyProjectVersion)) {
    Write-Host "Error: Could not find [project].version in $PyProjectFile."
    exit 1
}

Write-Host "C3 project version:     $C3Version"
Write-Host "Python project version: $PyProjectVersion"

if ($C3Version -ne $PyProjectVersion) {
    Write-Host ""
    Write-Host "Version mismatch!"
    Write-Host "  project.json:   $C3Version"
    Write-Host "  pyproject.toml: $PyProjectVersion"
    exit 1
}

Write-Host ""
Write-Host "Version check passed: $C3Version"