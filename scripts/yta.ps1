# Download audio only (best quality, mp3)
. "$PSScriptRoot\yt-settings.ps1"
. "$PSScriptRoot\helpers\common.ps1"

$URL = Read-Host "URL"

Ensure-OutputDirectory $OUTPUT_DIR
$outputTpl = "$OUTPUT_DIR\%(title)s.%(ext)s"

# Preview
$formatArgs = @("-f", "bestaudio", "-x", "--audio-format", "mp3")
$filename = Get-DownloadPreview $URL $outputTpl $COOKIES $formatArgs

Write-DownloadInfo $OUTPUT_DIR $filename $null

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
$args_ += "-f", "bestaudio", "-x", "--audio-format", "mp3", "--audio-quality", "0"
if ($EMBED_METADATA) { $args_ += "--embed-metadata" }
if ($EMBED_THUMBNAIL) { $args_ += "--embed-thumbnail", "--convert-thumbnails", "jpg" }
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", $outputTpl
$args_ += $URL

& yt-dlp @args_

Write-Success $filename
