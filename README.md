# yt-dlp downloader

Windows scripts for downloading video/audio from YouTube and other platforms. Optimized for Adobe Premiere Pro workflow.

## Quick start

1. Download `setup.bat` and `setup.ps1`
2. Double-click `setup.bat`
3. Restart terminal
4. Run `yt` to open the interactive menu

## What setup does

- Installs **yt-dlp**, **FFmpeg**, **Deno** (via winget)
- Generates download scripts in `~/bin/`
- Adds everything to PATH

## Usage

Run `yt` (or double-click `yt.bat` in `~/bin/`) to open the interactive menu:

```
  yt-dlp downloader

  > Video          download video
    Audio          download audio
    Video clip     video segment (timecodes)
    Audio clip     audio segment (timecodes)
```

Or run scripts directly: `ytv`, `yta`, `ytc`, `ytca`.

## Configuration

Edit `~/bin/yt-settings.ps1`:

- `$COOKIES` -- browser cookies for age-restricted content (e.g. `"chrome"`, `"firefox"`)
- `$OUTPUT_DIR` -- where to save files (default: `~/Videos`)
- `$MAX_RESOLUTION` -- max video resolution (default: `1440`)

## Defaults

- Codec: H.265 (HEVC), fallback H.264
- Container: MP4
- Metadata & thumbnail embedded
- Description saved to separate file
