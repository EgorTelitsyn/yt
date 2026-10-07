# Download audio clip (segment by timecodes)
. "$PSScriptRoot\yt-settings.ps1"
. "$PSScriptRoot\helpers\common.ps1"
. "$PSScriptRoot\helpers\time.ps1"

$cookieArgs = Get-CookieArgs $COOKIES $COOKIES_FILE $USE_COOKIES_FILE
if ($null -eq $cookieArgs) { return }

$URL   = Read-Host "URL"
$START = Read-Host "Start time (e.g. 00:01:30)"
$END   = Read-Host "End time (e.g. 00:02:45)"

if (-not $URL) { Write-Host "Error: URL is required"; exit 1 }

Ensure-OutputDirectory $OUTPUT_DIR

$startFmt = Format-Time $START
$endFmt   = Format-Time $END
$outputTpl = "$OUTPUT_DIR\%(title)s [$startFmt-$endFmt].%(ext)s"

# Preview
$formatArgs = @("-f", "bestaudio/best", "-x", "--audio-format", "mp3")
$filename = Get-DownloadPreview $URL $outputTpl $cookieArgs $formatArgs
if ($filename) { $filename = [System.IO.Path]::ChangeExtension($filename, "mp3") }

$extraInfo = @{ "Segment" = "$START - $END" }
Write-DownloadInfo $OUTPUT_DIR $filename $extraInfo

$args_ = @("--ignore-config")
$args_ += $cookieArgs
$args_ += "--download-sections", "*${START}-${END}"
$args_ += "-f", "bestaudio/best", "-x", "--audio-format", "mp3", "--audio-quality", "0"
if ($EMBED_METADATA) { $args_ += "--embed-metadata" }
if ($EMBED_THUMBNAIL) { $args_ += "--embed-thumbnail", "--convert-thumbnails", "jpg" }
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", $outputTpl
$args_ += $URL

& $YTDLP @args_

Write-Success $filename
