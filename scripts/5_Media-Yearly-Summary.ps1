# Filename: Media-Yearly-Summary.ps1

# --- Configuration ---
$baseFolder = "C:\Photo_Cleanup\Organized"
$imagesPath = Join-Path $baseFolder "Images"
$videosPath = Join-Path $baseFolder "Videos"
$metadataPath = Join-Path $baseFolder "metadata"

# --- Function: Get year from folder path ---
function Get-YearFromPath {
    param ($path)
    return [System.IO.Path]::GetFileName($path)
}

# --- Function: Count files by year in a root folder ---
function Count-FilesByYear {
    param (
        [string]$folderPath,
        [string[]]$extensions
    )
    $result = @{}

    if (!(Test-Path $folderPath)) { return $result }

    Get-ChildItem -Path $folderPath -Directory | ForEach-Object {
        $year = Get-YearFromPath $_.FullName
        $files = Get-ChildItem -Path $_.FullName -File -Recurse |
            Where-Object { $_.Extension -in $extensions }
        $result[$year] = $files.Count
    }

    return $result
}

# --- Function: Parse title from metadata and get year ---
function Get-MetadataCountsByYear {
    param ($metadataFolder)
    $jsonFiles = Get-ChildItem -Path $metadataFolder -File -Filter *.json
    $counts = @{}
    $total = $jsonFiles.Count
    $counter = 0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($jsonFile in $jsonFiles) {
        try {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $title = $json.title

            if ($title -match '(\d{4})[-_]?\d{2}[-_]?\d{2}') {
                $year = $matches[1]
                if (-not $counts.ContainsKey($year)) {
                    $counts[$year] = 0
                }
                $counts[$year]++
            }
        } catch {
            # Skip invalid JSON
        }

        $counter++
        $elapsed = $stopwatch.Elapsed
        $avg = if ($counter -gt 0) { $elapsed.TotalSeconds / $counter } else { 0 }
        $remaining = [TimeSpan]::FromSeconds($avg * ($total - $counter))

        Write-Progress -Activity "Processing metadata files..." `
                       -Status "$counter of $total - Estimated time left: $([int]$remaining.TotalMinutes)m $($remaining.Seconds)s" `
                       -PercentComplete (($counter / $total) * 100)
    }

    $stopwatch.Stop()
    return $counts
}

# --- Function: Merge and display summary ---
function Show-MediaSummary {
    param (
        [hashtable]$photoCounts,
        [hashtable]$videoCounts,
        [hashtable]$metadataCounts
    )

    $years = ($photoCounts.Keys + $videoCounts.Keys + $metadataCounts.Keys) | Sort-Object -Unique
    $summary = foreach ($year in $years) {
        [PSCustomObject]@{
            Year           = $year
            Photos         = $photoCounts[$year]     | ForEach-Object { $_ } | Default 0
            Videos         = $videoCounts[$year]     | ForEach-Object { $_ } | Default 0
            MetadataFiles  = $metadataCounts[$year]  | ForEach-Object { $_ } | Default 0
        }
    }

    $summary | Sort-Object Year | Format-Table -AutoSize
}

# --- Main Execution ---
$photoCounts    = Count-FilesByYear -folderPath $imagesPath -extensions @(".jpg", ".jpeg", ".png", ".heic", ".tiff")
$videoCounts    = Count-FilesByYear -folderPath $videosPath -extensions @(".mp4", ".mov", ".mkv", ".avi")
$metadataCounts = Get-MetadataCountsByYear -metadataFolder $metadataPath

Show-MediaSummary -photoCounts $photoCounts -videoCounts $videoCounts -metadataCounts $metadataCounts
