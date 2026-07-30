$header = "// SPDX-License-Identifier: MIT`r`n// Copyright (c) 2026 Dr0f0x`r`n`r`n"

Get-ChildItem -Recurse -Filter *.c3 | ForEach-Object {
    $file = $_.FullName
    $content = Get-Content $file -Raw

    # Remove existing short license header if present
    $content = $content -replace '^// SPDX-License-Identifier: MIT\r?\n// Copyright \(c\) 2026 Dr0f0x\r?\n\r?\n?', ''

    # Remove only accidental empty lines before module
    $content = $content.TrimStart("`r", "`n")

    Set-Content `
        -Path $file `
        -Value ($header + $content) `
        -Encoding utf8

    Write-Host "Updated $file"
}