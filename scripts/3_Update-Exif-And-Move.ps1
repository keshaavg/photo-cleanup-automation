# Filename: Update-Exif-And-Move.ps1

# Configuration
$baseFolder = "C:\Photo_Cleanup\From_Google_Photos\Organized"
$unknownFolder = Join-Path $baseFolder "Images\Unknown"
$outputCsv = Join-Path $baseFolder "ExifUpdate_Log.csv"
$exifTool = "exiftool"  # Use full path if not in PATH

$log = @()

# Function: Clean strings for logs and EXIF metadata
function Clean-String {
    param ($text)
    if ($null -eq $text) { return "" }
    return ($text -replace '[",;]', '') -replace '[^\x20-\x7E]', ''
}

# Function: Parse date from filename, return [datetime] or $null
function Parse-DateFromFilename {
    param ($filename)

    $name = [System.IO.Path]::GetFileNameWithoutExtension($filename)

    if ($name -match '(\d{4})(\d{2})(\d{2})(?:[_-]?(\d{2})(\d{2})(\d{2}))?') {
        try {
            if ($matches[4]) {
                return [datetime]::ParseExact("$($matches[1])-$($matches[2])-$($matches[3]) $($matches[4]):$($matches[5]):$($matches[6])", "yyyy-MM-dd HH:mm:ss", $null)
            } else {
                return [datetime]::ParseExact("$($matches[1])-$($matches[2])-$($matches[3])", "yyyy-MM-dd", $null)
            }
        } catch { return $null }
    }
    elseif ($name -match '(\d{4})[-_](\d{2})[-_](\d{2})[-_]?(\d{2})?[-_]?(\d{2})?[-_]?(\d{2})?') {
        try {
            if ($matches[4] -and $matches[5] -and $matches[6]) {
                return [datetime]::ParseExact("$($matches[1])-$($matches[2])-$($matches[3]) $($matches[4]):$($matches[5]):$($matches[6])", "yyyy-MM-dd HH:mm:ss", $null)
            } else {
                return [datetime]::ParseExact("$($matches[1])-$($matches[2])-$($matches[3])", "yyyy-MM-dd", $null)
            }
        } catch { return $null }
    }

    return $null
}

# Function: Update EXIF and move file if date is valid
function Update-ExifAndMove {
    param (
        [System.IO.FileInfo]$file,
        [datetime]$parsedDate
    )

    $result = @{
        Filename = Clean-String $file.Name
        ParsedDateTime = ""
        Action = ""
        Success = $false
    }

    if ($parsedDate -and $parsedDate.Year -ge 2016 -and $parsedDate.Year -le 2025) {
        $datetimeStr = $parsedDate.ToString("yyyy:MM:dd HH:mm:ss")
        $yearFolder = Join-Path $baseFolder "Images\$($parsedDate.Year)"
        $comment = Clean-String ("Inferred from filename on " + $parsedDate.ToString("yyyy-MM-dd HH:mm:ss"))

        try {
            & $exifTool `
              "-DateTimeOriginal=$datetimeStr" `
              "-CreateDate=$datetimeStr" `
              "-Comment=$comment" `
              -overwrite_original "$($file.FullName)" | Out-Null

            if (!(Test-Path $yearFolder)) {
                New-Item -ItemType Directory -Path $yearFolder | Out-Null
            }

            $destPath = Join-Path $yearFolder $file.Name
            Move-Item -Path $file.FullName -Destination $destPath -Force

            $result.ParsedDateTime = $parsedDate.ToString("yyyy-MM-dd HH:mm:ss")
            $result.Action = "EXIF updated and moved to Images\$($parsedDate.Year)"
            $result.Success = $true
        } catch {
            $result.Action = "Error during EXIF update or move: $_"
        }
    } else {
        $result.Action = "Skipped: No valid date parsed or year out of range"
    }

    return $result
}

# MAIN EXECUTION LOOP with progress bar
$images = Get-ChildItem -Path $unknownFolder -File | Where-Object {
    $_.Extension -match '\.(jpg|jpeg|png|heic|tiff)$'
}

$total = $images.Count
$counter = 0
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($file in $images) {
    $parsedDate = Parse-DateFromFilename -filename $file.Name
    $logEntry = Update-ExifAndMove -file $file -parsedDate $parsedDate
    $log += $logEntry
    $counter++

    # Progress with estimated time remaining
    $elapsed = $stopwatch.Elapsed
    $avgTimePerFile = if ($counter -gt 0) { $elapsed.TotalSeconds / $counter } else { 0 }
    $remaining = [TimeSpan]::FromSeconds($avgTimePerFile * ($total - $counter))

    Write-Progress -Activity "Processing images..." `
                   -Status "$counter of $total - Time left: $([int]$remaining.TotalMinutes)m $($remaining.Seconds)s" `
                   -PercentComplete (($counter / $total) * 100)
}

$stopwatch.Stop()

# Write final log to CSV
$log | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
Write-Host "`nDone. Log saved to: $outputCsv"
