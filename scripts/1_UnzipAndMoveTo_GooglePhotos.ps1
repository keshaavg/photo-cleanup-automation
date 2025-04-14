# Filename : 1_UnzipAndMoveTo_GooglePhotos.ps1
# Script: UnzipAndMoveTo_GooglePhotos.ps1
# Description: Extracts all ZIP files from Downloads folder into C:\Photo_Cleanup\From_Google_Photos
#              and deletes the ZIP files afterward.

# Set your download folder and destination folder
$downloadsFolder = "$env:USERPROFILE\Downloads"
$destinationFolder = "C:\Photo_Cleanup\From_Google_Photos"

# Create destination folder if it doesn't exist
if (!(Test-Path $destinationFolder)) {
    New-Item -ItemType Directory -Path $destinationFolder | Out-Null
}

# Get all ZIP files in the Downloads folder
$zipFiles = Get-ChildItem -Path $downloadsFolder -Filter *.zip

foreach ($zip in $zipFiles) {
    Write-Host "Extracting $($zip.Name)..."

    # Extract the ZIP to destination
    Expand-Archive -Path $zip.FullName -DestinationPath $destinationFolder -Force

    # Delete the ZIP file
    Remove-Item -Path $zip.FullName -Force

    Write-Host "Done: $($zip.Name)"
}



# Show progress while processing
$files = Get-ChildItem -Recurse -File -Path $sourceFolder
$total = $files.Count
$counter = 0
foreach ($file in $files) {
    $counter++
    Write-Progress -Activity "Moving files..." -Status "$counter of $total processed" -PercentComplete (($counter / $total) * 100)
    # Your existing move logic goes here
}
