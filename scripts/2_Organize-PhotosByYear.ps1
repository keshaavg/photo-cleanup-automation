# Filename: Organize-TakeoutFiles.ps1

param (
    [string]$SourceFolder = "C:\Photo_Cleanup\From_Google_Photos\Takeout",
    [string]$HandlePath = "C:\Tools\Handle\handle.exe",
    [string]$FfprobePath = "C:\Tools\ffprobe.exe"  # Update this path to your ffprobe.exe location
)

Add-Type -AssemblyName System.Drawing

function Get-ExifDateTaken($filePath) {
    try {
        $fs = [System.IO.File]::Open($filePath, 'Open', 'Read', 'ReadWrite')
        try {
            $image = [System.Drawing.Image]::FromStream($fs)
            $prop = $image.GetPropertyItem(36867)
            $dateString = [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim([char]0)
            $image.Dispose()
            return [datetime]::ParseExact($dateString, "yyyy:MM:dd HH:mm:ss", $null)
        } finally {
            $fs.Close()
        }
    } catch {
        return $null
    }
}

function Get-VideoYear($filePath, $ffprobePath) {
    if (!(Test-Path $ffprobePath)) { return "Unknown" }
    try {
        $output = & $ffprobePath -v quiet -print_format json -show_format -show_streams "$filePath" 2>$null
        if ($output) {
            $json = $output | ConvertFrom-Json
            $creation = $json.format.tags.creation_time
            if ($creation) {
                $date = [datetime]::Parse($creation)
                return $date.Year.ToString()
            }
        }
    } catch {}
    return "Unknown"
}

function Get-UniqueFilePath($targetPath) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($targetPath)
    $ext = [System.IO.Path]::GetExtension($targetPath)
    $dir = [System.IO.Path]::GetDirectoryName($targetPath)
    $i = 1
    while (Test-Path $targetPath) {
        $targetPath = Join-Path $dir ("{0}_{1}{2}" -f $baseName, $i, $ext)
        $i++
    }
    return $targetPath
}

function Is-FileLocked($filePath) {
    try {
        $stream = [System.IO.File]::Open($filePath, 'Open', 'ReadWrite', 'None')
        $stream.Close()
        return $false
    } catch {
        return $true
    }
}

function Get-LockingProcess($filePath, $HandlePath) {
    if (!(Test-Path $HandlePath)) { return "handle.exe not found" }
    $handleOutput = & $HandlePath -accepteula $filePath 2>$null
    $lines = $handleOutput | Where-Object { $_ -match ": File  " }
    $processes = ($lines | ForEach-Object {
        if ($_ -match "^(.+?)\s+pid:") { $matches[1] }
    }) | Sort-Object -Unique
    if ($processes.Count -gt 0) {
        return $processes -join ", "
    } else {
        return "Unknown process"
    }
}

$destinationRoot = Join-Path $SourceFolder "..\Organized"
$allFiles = Get-ChildItem -Path $SourceFolder -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\Organized\\' }

$total = $allFiles.Count
$counter = 0
$summary = @{}
$failCount = 0
$warningLog = Join-Path $destinationRoot "move_warnings.log"
if (Test-Path $warningLog) { Remove-Item $warningLog -Force }

Write-Host "[*] Organizing $total files from: $SourceFolder"
$startTime = Get-Date

foreach ($file in $allFiles) {
    $ext = $file.Extension.ToLower()
    $isImage = $ext -in ".jpg", ".jpeg", ".png", ".gif", ".heic", ".tiff", ".bmp"
    $isVideo = $ext -in ".mp4", ".mov", ".avi", ".mkv", ".wmv"
    $isMetadata = $ext -eq ".json"

    if ($isImage) {
        $dateTaken = Get-ExifDateTaken $file.FullName
        $year = if ($dateTaken) { $dateTaken.Year.ToString() } else { "Unknown" }
        $destFolder = Join-Path $destinationRoot "Images\$year"
        $key = "Images_$year"
    } elseif ($isVideo) {
        $year = Get-VideoYear $file.FullName $FfprobePath
        $destFolder = Join-Path $destinationRoot "Videos\$year"
        $key = "Videos_$year"
    } elseif ($isMetadata) {
        $destFolder = Join-Path $destinationRoot "Metadata"
        $key = "Metadata"
    } else {
        $destFolder = Join-Path $destinationRoot "Other Files"
        $key = "Other_Files"
    }

    if (!(Test-Path $destFolder)) {
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
    }

    $targetPath = Join-Path $destFolder $file.Name
    $uniquePath = Get-UniqueFilePath $targetPath

    if (Is-FileLocked $file.FullName) {
        $failCount++
        $locker = Get-LockingProcess $file.FullName $HandlePath
        $msg = "Locked file (skipped): $($file.FullName) [LOCKED BY: $locker]"
        Write-Warning $msg
        Add-Content -Path $warningLog -Value $msg
        continue
    }

    try {
        if ($file.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
            $file.Attributes = $file.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
        }

        Move-Item -Path $file.FullName -Destination $uniquePath -Force -ErrorAction Stop

        if ($summary.ContainsKey($key)) {
            $summary[$key]++
        } else {
            $summary[$key] = 1
        }
    } catch {
        $failCount++
        Write-Warning "Failed to move: $($file.FullName)"
        Add-Content -Path $warningLog -Value "Failed to move: $($file.FullName)"
    }

    $counter++
    $elapsed = (Get-Date) - $startTime
    $remaining = if ($counter -gt 0) {
        [TimeSpan]::FromSeconds($elapsed.TotalSeconds * (($total - $counter) / $counter))
    } else {
        [TimeSpan]::Zero
    }
    $status = "$counter of $total processed - Time remaining: {0:hh\:mm\:ss}" -f $remaining
    $percent = [math]::Round(($counter / $total) * 100, 0)
    Write-Progress -Activity "Organizing files..." -Status $status -PercentComplete $percent
}

# Remove any empty directories
Get-ChildItem -Path $SourceFolder -Recurse -Directory | Where-Object {
    ($_ | Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue).Count -eq 0
} | Remove-Item -Recurse -Force

Write-Host ""
Write-Host "=== Organization Summary ==="
$summary.Keys | Sort-Object | ForEach-Object {
    Write-Host ("{0,-20}: {1}" -f $_, $summary[$_])
}
Write-Host ("Files failed to move : {0}" -f $failCount)

Write-Host ""
Write-Host "[OK] All files processed. Problematic files (if any) logged to: $warningLog"
