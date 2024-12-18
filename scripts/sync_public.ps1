# PowerShell script to sync public proposals

# Configuration
$PUBLIC_REPO="SKENAI-public"
$PRIVATE_REPO="SKENAI"
$PUBLIC_PATHS=@(
    "governance/proposals/*.md",
    "governance/COMPENDIUM.md"
)

# Create public directory if it doesn't exist
$PUBLIC_DIR="public_proposals"
if (-not (Test-Path $PUBLIC_DIR)) {
    New-Item -ItemType Directory -Path $PUBLIC_DIR
}

# Copy public files
foreach ($path in $PUBLIC_PATHS) {
    Copy-Item $path $PUBLIC_DIR -Force
}

# Copy the public README
Copy-Item "governance/proposals/PUBLIC_README.md" "$PUBLIC_DIR/README.md" -Force

# Git commands for syncing
Write-Host "Ready to sync with public repository"
Write-Host "Please run these commands manually:"
Write-Host "cd $PUBLIC_DIR"
Write-Host "git init"
Write-Host "git add ."
Write-Host 'git commit -m "Update public proposals"'
Write-Host "git remote add origin https://github.com/shibakery/$PUBLIC_REPO.git"
Write-Host "git push -u origin main --force"
