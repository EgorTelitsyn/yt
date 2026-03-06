# yt-dlp downloader

Windows scripts for downloading video and audio from YouTube and other platforms. Optimized for Adobe Premiere Pro workflow.

## Quick start

1. Download `setup.bat` and `setup.ps1`
2. Double-click `setup.bat`
3. Restart your terminal
4. Run `yt` to open the interactive menu

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

Or run scripts directly:

| Command | Description |
|---------|-------------|
| `ytv`  | Download video |
| `yta`  | Download audio |
| `ytvc` | Download video clip (timecodes) |
| `ytac` | Download audio clip (timecodes) |

Before downloading, scripts show a preview of the output directory and filename. After a successful download, a confirmation message with the full file path is displayed.

## Settings

Open via `yt` > Settings, or edit `~/bin/yt-settings.ps1` manually.

### User config

| Variable | Default | Description |
|----------|---------|-------------|
| `$COOKIES` | `""` | Browser cookies for auth (e.g. `"chrome"`, `"firefox:path/to/profile"`) |
| `$OUTPUT_DIR` | `~/Videos` | Download directory |
| `$MAX_RESOLUTION` | `1440` | Max video resolution |

### Toggle flags

| Flag | Default | yt-dlp option |
|------|---------|---------------|
| Embed metadata | on | `--embed-metadata` |
| Embed thumbnail | on | `--embed-thumbnail --convert-thumbnails jpg` |
| Write description | off | `--write-description` |

## Defaults

| Setting | Value |
|---------|-------|
| Video codec | H.265 (HEVC), fallback H.264 |
| Container | MP4 |
| Audio | MP3, best quality |

## What setup does

- Installs **yt-dlp**, **FFmpeg**, and **Deno** automatically
- Copies scripts to `~/bin/` and adds it to PATH
- Sets PowerShell execution policy for the scripts
- On re-run: updates dependencies, patches missing settings without overwriting existing ones

## Generated files

After setup, the following files are placed in `~/bin/`:

| File | Description |
|------|-------------|
| `yt.ps1` / `yt.bat` | Interactive launcher with menu |
| `ytv.ps1` | Download video |
| `yta.ps1` | Download audio |
| `ytvc.ps1` | Download video clip (timecodes) |
| `ytac.ps1` | Download audio clip (timecodes) |
| `yt-settings.ps1` | User configuration (not overwritten on re-run) |

## Uninstall

Double-click `uninstall.bat` and confirm when prompted. This removes all scripts from `~/bin/`, cleans up PATH, and uninstalls FFmpeg and Deno.

## Dependencies

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — video/audio downloader
- [FFmpeg](https://github.com/FFmpeg/FFmpeg) — media processing
- [Deno](https://github.com/denoland/deno) — JavaScript runtime (for YouTube PO token challenges)
