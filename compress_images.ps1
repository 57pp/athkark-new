# PowerShell script to compress Quran images
Write-Host "Starting Quran image compression..." -ForegroundColor Green

# Get all .webp files from the source directory
$sourceFiles = Get-ChildItem "assets\mushaf\page\*.webp"
Write-Host "Found $($sourceFiles.Count) files" -ForegroundColor Yellow

# Process each file
foreach ($file in $sourceFiles) {
    $outputPath = "assets\quran_compressed\$($file.Name)"
    Write-Host "Compressing $($file.Name)..." -ForegroundColor Cyan
    
    # Use ImageMagick to compress
    & magick "$($file.FullName)" -quality 70 -resize 50% "$outputPath"
    
    if (Test-Path $outputPath) {
        Write-Host "Successfully compressed $($file.Name)" -ForegroundColor Green
    } else {
        Write-Host "Failed to compress $($file.Name)" -ForegroundColor Red
    }
}

Write-Host "All images compressed successfully!" -ForegroundColor Green