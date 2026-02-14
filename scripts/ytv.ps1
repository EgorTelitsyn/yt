# Download video with h265/1440p/mp4 settings
. "$PSScriptRoot\yt-settings.ps1"

$URL = Read-Host "URL"

$outputTpl = "$OUTPUT_DIR/%(title)s.%(ext)s"

# Preview
$previewArgs = @("--ignore-config", "--print", "filename", "-o", $outputTpl)
if ($COOKIES) { $previewArgs += "--cookies-from-browser", $COOKIES }
$previewArgs += "-S", $VIDEO_SORT
$previewArgs += "-f", $VIDEO_FORMAT
$previewArgs += "--merge-output-format", $MERGE_FORMAT
$previewArgs += $URL
$filename = (& yt-dlp @previewArgs 2>$null) | Select-Object -First 1

Write-Host ""
Write-Host "  Saving to: " -NoNewline
Write-Host "$OUTPUT_DIR" -ForegroundColor DarkGray
if ($filename) {
    Write-Host "  File:     " -NoNewline
    Write-Host (Split-Path $filename -Leaf) -ForegroundColor DarkGray
}
Write-Host ""

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
$args_ += "-S", $VIDEO_SORT
$args_ += "-f", $VIDEO_FORMAT
$args_ += "--merge-output-format", $MERGE_FORMAT
if ($EMBED_METADATA) { $args_ += "--embed-metadata" }
if ($EMBED_THUMBNAIL) { $args_ += "--embed-thumbnail", "--convert-thumbnails", "jpg" }
if ($WRITE_DESCRIPTION) { $args_ += "--write-description" }
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", $outputTpl
$args_ += $URL

& yt-dlp @args_

if ($LASTEXITCODE -eq 0 -and $filename) {
    Write-Host ""
    Write-Host "  Done: $filename" -ForegroundColor Green
}
