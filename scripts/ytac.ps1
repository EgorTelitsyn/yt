# Download audio clip (segment by timecodes)
. "$PSScriptRoot\yt-settings.ps1"

$URL   = Read-Host "URL"
$START = Read-Host "Start time (e.g. 00:01:30)"
$END   = Read-Host "End time (e.g. 00:02:45)"

if (-not $URL) { Write-Host "Error: URL is required"; exit 1 }

function Format-Time($t) {
    $parts = $t -split ":"
    $h = [int]$parts[0]; $m = [int]$parts[1]; $s = [int]$parts[2]
    if ($h -gt 0) { "${h}h${m}m${s}s" }
    elseif ($m -gt 0) { "${m}m${s}s" }
    else { "${s}s" }
}

$startFmt = Format-Time $START
$endFmt   = Format-Time $END

$outputTpl = "$OUTPUT_DIR/%(title)s [$startFmt-$endFmt].%(ext)s"

# Preview
$previewArgs = @("--ignore-config", "--print", "filename", "-o", $outputTpl)
if ($COOKIES) { $previewArgs += "--cookies-from-browser", $COOKIES }
$previewArgs += "-f", "bestaudio", "-x", "--audio-format", "mp3"
$previewArgs += $URL
$filename = (& yt-dlp @previewArgs 2>$null) | Select-Object -First 1

Write-Host ""
Write-Host "  Saving to: " -NoNewline
Write-Host "$OUTPUT_DIR" -ForegroundColor DarkGray
if ($filename) {
    Write-Host "  File:     " -NoNewline
    Write-Host (Split-Path $filename -Leaf) -ForegroundColor DarkGray
}
Write-Host "  Segment:  " -NoNewline
Write-Host "$START - $END" -ForegroundColor DarkGray
Write-Host ""

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
$args_ += "--download-sections", "*${START}-${END}"
$args_ += "-f", "bestaudio", "-x", "--audio-format", "mp3", "--audio-quality", "0"
if ($EMBED_METADATA) { $args_ += "--embed-metadata" }
if ($EMBED_THUMBNAIL) { $args_ += "--embed-thumbnail", "--convert-thumbnails", "jpg" }
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", $outputTpl
$args_ += $URL

& yt-dlp @args_

if ($LASTEXITCODE -eq 0 -and $filename) {
    Write-Host ""
    Write-Host "  Done: $filename" -ForegroundColor Green
}
