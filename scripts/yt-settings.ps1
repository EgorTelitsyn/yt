# yt-dlp settings -- edit for your system
# Dependencies (yt-dlp, ffmpeg, deno) are expected in PATH -- run setup.bat first

# Browser cookies (format: "browser:profile_path", leave empty to disable)
# Examples: "chrome", "firefox", "firefox:C:/Users/You/AppData/Roaming/zen/Profiles/xxxxx.Default (release)"
$COOKIES = ""

# Output directory
$OUTPUT_DIR = "$env:USERPROFILE\Videos"

# Video settings
$MAX_RESOLUTION = 1440
$VIDEO_FORMAT = "bestvideo[height<=$MAX_RESOLUTION][vcodec*=265]+bestaudio/bestvideo[height<=$MAX_RESOLUTION][vcodec*=264]+bestaudio/bestvideo[height<=$MAX_RESOLUTION][vcodec!*=vp0][vcodec!*=vp9][vcodec!*=av01]+bestaudio/best"
$VIDEO_SORT = "res:$MAX_RESOLUTION,vcodec:h265,acodec:aac"
$MERGE_FORMAT = "mp4"

# Toggle flags (changed via yt.ps1 > Settings)
$EMBED_METADATA = $true
$EMBED_THUMBNAIL = $true
$WRITE_DESCRIPTION = $false
