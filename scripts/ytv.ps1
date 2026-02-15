# Download video with h265/1440p/mp4 settings
. "$PSScriptRoot\yt-settings.ps1"
. "$PSScriptRoot\helpers\common.ps1"

$URL = Read-Host "URL"

Ensure-OutputDirectory $OUTPUT_DIR
$outputTpl = "$OUTPUT_DIR\%(title)s.%(ext)s"

# Preview
$formatArgs = @("-S", $VIDEO_SORT, "-f", $VIDEO_FORMAT, "--merge-output-format", $MERGE_FORMAT)
$filename = Get-DownloadPreview $URL $outputTpl $COOKIES $formatArgs

Write-DownloadInfo $OUTPUT_DIR $filename $null

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

Write-Success $filename
