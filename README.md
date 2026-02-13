# yt-dlp downloader

Windows scripts for downloading video/audio from YouTube and other platforms. Optimized for Adobe Premiere Pro workflow.

## Quick start

1. Download `setup.bat` and `setup.ps1`
2. Double-click `setup.bat`
3. Restart terminal
4. Run `yt` to open the interactive menu

## What setup does

- Installs **yt-dlp** (from GitHub releases), **FFmpeg**, **Deno** (via winget)
- Generates download scripts and launcher in `~/bin/`
- Adds dependencies and `~/bin/` to PATH
- On re-run: updates dependencies, patches missing settings without overwriting existing ones

## Usage

Run `yt` (or double-click `yt.bat` in `~/bin/`) to open the interactive menu:

```
  yt-dlp downloader

  > Video          download video
    Audio          download audio
    Video clip     video segment (timecodes)
    Audio clip     audio segment (timecodes)
    Settings       toggle flags
```

Or run scripts directly: `ytv`, `yta`, `ytvc`, `ytac`.

Before downloading, scripts show a preview of the output directory and filename. After a successful download, a green confirmation message with the full file path is displayed.

## Settings

Open via `yt` > Settings, or edit `~/bin/yt-settings.ps1` manually.

### User config

| Variable | Default | Description |
|----------|---------|-------------|
| `$COOKIES` | `""` | Browser cookies for auth (e.g. `"chrome"`, `"firefox:path/to/profile"`) |
| `$OUTPUT_DIR` | `~/Videos` | Download directory |
| `$MAX_RESOLUTION` | `1440` | Max video resolution |

### Toggle flags

Toggled via the Settings submenu (saved to `yt-settings.ps1`):

| Flag | Default | yt-dlp option |
|------|---------|---------------|
| Embed metadata | on | `--embed-metadata` |
| Embed thumbnail | on | `--embed-thumbnail --convert-thumbnails jpg` |
| Write description | off | `--write-description` |

## Defaults

- Codec: H.265 (HEVC), fallback H.264
- Container: MP4
- Audio: MP3, best quality

## Generated scripts

| Script | Description |
|--------|-------------|
| `yt.ps1` / `yt.bat` | Interactive launcher with menu |
| `ytv.ps1` | Download video |
| `yta.ps1` | Download audio |
| `ytvc.ps1` | Download video clip (timecodes) |
| `ytac.ps1` | Download audio clip (timecodes) |
| `yt-settings.ps1` | Configuration (not overwritten on re-run) |

## Dependencies

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) -- video/audio downloader
- [FFmpeg](https://github.com/FFmpeg/FFmpeg) -- media processing
- [Deno](https://github.com/denoland/deno) -- JavaScript runtime (for YouTube PO token challenges)
