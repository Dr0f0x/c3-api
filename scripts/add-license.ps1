param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Directory
)

$header = "// SPDX-License-Identifier: MIT`r`n// Copyright (c) 2026 Dr0f0x`r`n`r`n"
$directoryInfo = Get-Item -LiteralPath $Directory -ErrorAction Stop

if (-not $directoryInfo.PSIsContainer) {
    throw "The path must be a directory: $Directory"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Get-ChildItem -LiteralPath $directoryInfo.FullName -Recurse -Filter *.c3 -File | ForEach-Object {
    $file = $_.FullName
    $content = [System.IO.File]::ReadAllText($file)

    # Remove existing short license header if present
    $content = $content -replace '^// SPDX-License-Identifier: MIT\r?\n// Copyright \(c\) 2026 Dr0f0x\r?\n\r?\n?', ''

    # Remove accidental empty lines before the module and at EOF.
    $content = $content.TrimStart("`r", "`n")
    $content = $content.TrimEnd("`r", "`n")

    [System.IO.File]::WriteAllText($file, $header + $content, $utf8NoBom)

    Write-Host "Updated $file"
}