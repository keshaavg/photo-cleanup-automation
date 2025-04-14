# Filename: Filter-Orphan-Metadata.ps1

# --- Configuration ---
$baseFolder = "C:\Photo_Cleanup\Organized"
$metadataFolder = Join-Path $baseFolder "metadata"
$reviewFolder = Join-Path $metadataFolder "Review"
$imagesPath = Join-Path $baseFolder "Images"
$videosPath = Join-Path $baseFolder "Videos"

# --- Function: Ensure a folder exists ---
function Ensure-Folder {
    param ($path)
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

# --- Function: Build a set of media filenames (with extensions) ---
function Get-Media-Filenames {
    param ($imagesPath, $videosPath)
    $files = Get-ChildItem -Path $imagesPath, $videosPath -Recurse -File |
        Where-Object { $_.Extension -match '\.(jpg|jpeg|png|heic|bmp|tiff|mp4|mov|mkv|avi)$' }
    return $files.Name | Sort-Object -Unique
}

# --- Function: Extract title from JSON metadata file ---
function Get-JsonTitle {
    param ($filePath)
    try {
        $json = Get-Content $filePath -Raw | ConvertFrom-Json
        return $json.title
    } catch {
        return $null
    }
}

# --- Function: Process metadata and move orphans ---
function Process-Metadata {
    param (
        [string]$metadataFolder,
        [string]$reviewFolder,
        [string[]]$mediaFilenames
    )

    $jsonFiles = Get-ChildItem -Path $metadataFolder -Filter *.json -File
    $total = $jsonFiles.Count
    $counter = 0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($jsonFile in $jsonFiles) {
        $title = Get-JsonTitle -filePath $jsonFile.FullName

        if (-not ($mediaFilenames -contains $title)) {
            $destination = Join-Path $reviewFolder $jsonFile.Name
            Move-Item -Path $jsonFile.FullName -Destination $destination -Force
        }

        $counter++
        $elapsed = $stopwatch.Elapsed
        $avg = if ($counter -gt 0) { $elapsed.TotalSeconds / $counter } else { 0 }
        $remaining = [TimeSpan]::FromSeconds($avg * ($total - $counter))

        Write-Progress -Activity "Filtering metadata files..." `
                       -Status "$counter of $total - Estimated time left: $([int]$remaining.TotalMinutes)m $($remaining.Seconds)s" `
                       -PercentComplete (($counter / $total) * 100)
    }

    $stopwatch.Stop()
    Write-Host "`nFiltering complete. Orphan metadata moved to: $reviewFolder"
}

# --- Main Execution ---
Ensure-Folder -path $reviewFolder
$mediaFilenames = Get-Media-Filenames -imagesPath $imagesPath -videosPath $videosPath
Process-Metadata -metadataFolder $metadataFolder -reviewFolder $reviewFolder -mediaFilenames $mediaFilenames
