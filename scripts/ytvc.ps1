# Download video clip (segment by timecodes)
. "$PSScriptRoot\yt-settings.ps1"
. "$PSScriptRoot\helpers\common.ps1"
. "$PSScriptRoot\helpers\time.ps1"

$cookieArgs = Get-CookieArgs $COOKIES $COOKIES_FILE $USE_COOKIES_FILE
if ($null -eq $cookieArgs) { return }

$inp = Read-Steps @(
    @{ Name = "URL";   Prompt = "URL" },
    @{ Name = "START"; Prompt = "Start time (e.g. 00:01:30)" },
    @{ Name = "END";   Prompt = "End time (e.g. 00:02:45)" }
)
if ($null -eq $inp) { $CANCELLED = $true; return }
$URL   = $inp.URL
$START = $inp.START
$END   = $inp.END

Ensure-OutputDirectory $OUTPUT_DIR

$startFmt = Format-Time $START
$endFmt   = Format-Time $END
$outputTpl = "$OUTPUT_DIR\%(title)s [$startFmt-$endFmt].%(ext)s"

# Preview
$formatArgs = @("-S", $VIDEO_SORT, "-f", $VIDEO_FORMAT, "--merge-output-format", $MERGE_FORMAT)
$filename = Get-DownloadPreview $URL $outputTpl $cookieArgs $formatArgs

$extraInfo = @{ "Segment" = "$START - $END" }
Write-DownloadInfo $OUTPUT_DIR $filename $extraInfo

$args_ = @("--ignore-config")
$args_ += $cookieArgs
$args_ += "-S", $VIDEO_SORT
$args_ += "-f", $VIDEO_FORMAT
$args_ += "--merge-output-format", $MERGE_FORMAT
$args_ += "--download-sections", "*${START}-${END}"
if ($EMBED_METADATA) { $args_ += "--embed-metadata" }
if ($EMBED_THUMBNAIL) { $args_ += "--embed-thumbnail", "--convert-thumbnails", "jpg" }
if ($WRITE_DESCRIPTION) { $args_ += "--write-description" }
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", $outputTpl
$args_ += $URL

& $YTDLP @args_

Write-Success $filename
