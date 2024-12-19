# Reorganize SKENAI workspace

# Create necessary directories if they don't exist
$dirs = @(
    "docs",
    "governance/proposals",
    "contracts",
    "agents",
    "poly-dov-amm",
    "scripts",
    "shared",
    "tests",
    "brand"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force
    }
}

# Move proposals from public_proposals to governance
if (Test-Path "public_proposals/proposals") {
    Get-ChildItem "public_proposals/proposals" -File | ForEach-Object {
        Move-Item $_.FullName "governance/proposals/" -Force
    }
}

# Move docs from public_proposals to docs
if (Test-Path "public_proposals/docs") {
    Get-ChildItem "public_proposals/docs" -File | ForEach-Object {
        Move-Item $_.FullName "docs/" -Force
    }
}

# Clean up empty directories
@("books", "web3", "archive", "public_proposals") | ForEach-Object {
    if ((Test-Path $_) -and ((Get-ChildItem $_ -Force | Measure-Object).Count -eq 0)) {
        Remove-Item $_ -Force -Recurse
    }
}

Write-Host "Workspace reorganization complete!"
