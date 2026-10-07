# Download audio only (best quality, mp3)
. "$PSScriptRoot\yt-settings.ps1"
. "$PSScriptRoot\helpers\common.ps1"

$cookieArgs = Get-CookieArgs $COOKIES $COOKIES_FILE $USE_COOKIES_FILE
if ($null -eq $cookieArgs) { return }

$URL = Read-Host "URL"

Ensure-OutputDirectory $OUTPUT_DIR
$outputTpl = "$OUTPUT_DIR\%(title)s.%(ext)s"

# Preview
$formatArgs = @("-f", "bestaudio/best", "-x", "--audio-format", "mp3")
$filename = Get-DownloadPreview $URL $outputTpl $cookieArgs $formatArgs
if ($filename) { $filename = [System.IO.Path]::ChangeExtension($filename, "mp3") }

Write-DownloadInfo $OUTPUT_DIR $filename $null

$args_ = @("--ignore-config")
$args_ += $cookieArgs
$args_ += "-f", "bestaudio/best", "-x", "--audio-format", "mp3", "--audio-quality", "0"
if ($EMBED_METADATA) { $args_ += "--embed-metadata" }
if ($EMBED_THUMBNAIL) { $args_ += "--embed-thumbnail", "--convert-thumbnails", "jpg" }
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", $outputTpl
$args_ += $URL

& $YTDLP @args_

Write-Success $filename
