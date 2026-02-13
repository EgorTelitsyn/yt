Write-Host ""
Write-Host "  yt-dlp scripts - setup" -ForegroundColor Cyan
Write-Host ""

# --- Resolve winget path ---

$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    $winget = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (-not (Test-Path $winget)) {
        Write-Host "ERROR: winget not found. Install App Installer from Microsoft Store." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}
if ($winget.Source) { $winget = $winget.Source }

# --- Install yt-dlp from GitHub (latest) ---

$binDir = "$env:USERPROFILE\bin"
if (-not (Test-Path $binDir)) { New-Item -Path $binDir -ItemType Directory | Out-Null }

Write-Host "[1/3] yt-dlp " -NoNewline
$ytdlpPath = Join-Path $binDir "yt-dlp.exe"
try {
    $release = Invoke-RestMethod "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest"
    $remoteVer = $release.tag_name
    $localVer = if (Test-Path $ytdlpPath) { (& $ytdlpPath --version 2>&1) } else { "" }

    if ($localVer -eq $remoteVer) {
        Write-Host "latest ($remoteVer)" -ForegroundColor DarkGray
    } else {
        $url = ($release.assets | Where-Object { $_.name -eq "yt-dlp.exe" }).browser_download_url
        Invoke-WebRequest -Uri $url -OutFile $ytdlpPath -UseBasicParsing
        if ($localVer) {
            Write-Host "updated ($localVer -> $remoteVer)" -ForegroundColor Green
        } else {
            Write-Host "installed ($remoteVer)" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# --- Install winget dependencies ---

$packages = @(
    @{ Id = "Gyan.FFmpeg";    Name = "FFmpeg" },
    @{ Id = "DenoLand.Deno";  Name = "Deno" }
)

$i = 1
foreach ($pkg in $packages) {
    $i++
    Write-Host "[$i/3] $($pkg.Name) " -NoNewline
    $result = & $winget install --id $pkg.Id -e --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    if ($result -match "already installed") {
        Write-Host "installed, updating..." -NoNewline
        $upResult = & $winget upgrade --id $pkg.Id -e --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
        if ($upResult -match "No available upgrade|No installed package") {
            Write-Host " latest" -ForegroundColor DarkGray
        } else {
            Write-Host " updated" -ForegroundColor Green
        }
    } else {
        Write-Host "installed" -ForegroundColor Green
    }
}

Write-Host ""

# --- Add dependencies to PATH ---

$depsToFind = @(
    @{ Cmd = "ffmpeg";   Exe = "ffmpeg.exe";  Label = "FFmpeg" },
    @{ Cmd = "deno";     Exe = "deno.exe";    Label = "Deno" }
)

# Refresh PATH to pick up anything winget just added
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

foreach ($dep in $depsToFind) {
    Write-Host "Checking $($dep.Label)..." -NoNewline

    # Already available?
    if (Get-Command $dep.Cmd -ErrorAction SilentlyContinue) {
        Write-Host " OK" -ForegroundColor DarkGray
        continue
    }

    # Search common install locations
    $searchPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps",
        "$env:LOCALAPPDATA\Programs",
        "$env:USERPROFILE\.deno\bin",
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}"
    )

    # Also check winget install log for actual install path
    $logDir = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
    if (Test-Path $logDir) {
        $latestLog = Get-ChildItem -Path $logDir -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestLog) {
            $logContent = Get-Content $latestLog.FullName -ErrorAction SilentlyContinue | Out-String
            # Extract install paths from log
            $regex = [regex]'(?i)install\s+location[:\s]+(.+)'
            $match = $regex.Match($logContent)
            if ($match.Success) {
                $logPath = $match.Groups[1].Value.Trim()
                if (Test-Path $logPath) { $searchPaths = @($logPath) + $searchPaths }
            }
        }
    }

    $found = $null
    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            $found = Get-ChildItem -Path $searchPath -Filter $dep.Exe -Recurse -Depth 4 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { break }
        }
    }

    if ($found) {
        $dir = $found.DirectoryName
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$dir*") {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$dir", "User")
            $env:Path += ";$dir"
        }
        Write-Host " added ($dir)" -ForegroundColor Green
    } else {
        Write-Host " NOT FOUND" -ForegroundColor Red
        Write-Host "         Searching entire user folder..." -NoNewline
        $deepSearch = Get-ChildItem -Path $env:USERPROFILE -Filter $dep.Exe -Recurse -Depth 6 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($deepSearch) {
            $dir = $deepSearch.DirectoryName
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$dir*") {
                [Environment]::SetEnvironmentVariable("Path", "$userPath;$dir", "User")
                $env:Path += ";$dir"
            }
            Write-Host " found! ($dir)" -ForegroundColor Green
        } else {
            # Fallback installers for deps that winget failed to install
            if ($dep.Cmd -eq "deno") {
                Write-Host " using official installer..." -ForegroundColor Yellow
                irm https://deno.land/install.ps1 | iex 2>&1 | Out-Null
                $denoDir = "$env:USERPROFILE\.deno\bin"
                if (Test-Path "$denoDir\deno.exe") {
                    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
                    if ($userPath -notlike "*$denoDir*") {
                        [Environment]::SetEnvironmentVariable("Path", "$userPath;$denoDir", "User")
                        $env:Path += ";$denoDir"
                    }
                    Write-Host "         installed to $denoDir" -ForegroundColor Green
                } else {
                    Write-Host "         failed. Install Deno manually: https://deno.land" -ForegroundColor Red
                }
            } else {
                Write-Host " not found. Install $($dep.Label) manually." -ForegroundColor Red
            }
        }
    }
}

# --- Write scripts to ~/bin/ ---

$binDir = "$env:USERPROFILE\bin"
if (-not (Test-Path $binDir)) { New-Item -Path $binDir -ItemType Directory | Out-Null }

Write-Host ""

# yt-settings.ps1 -- only if not already there (preserve user config)
$settingsPath = Join-Path $binDir "yt-settings.ps1"
if (-not (Test-Path $settingsPath)) {
    @'
# yt-dlp settings -- edit for your system
# Dependencies (yt-dlp, ffmpeg, deno) are expected in PATH -- run setup.bat first

# Browser cookies (format: "browser:profile_path", leave empty to disable)
# Examples: "chrome", "firefox", "firefox:C:/Users/You/AppData/Roaming/zen/Profiles/xxxxx.Default (release)"
$COOKIES = ""

# Output directory
$OUTPUT_DIR = "$env:USERPROFILE/Videos"

# Video settings
$MAX_RESOLUTION = 1440
$VIDEO_FORMAT = "bestvideo[height<=$MAX_RESOLUTION][vcodec*=265]+bestaudio/bestvideo[height<=$MAX_RESOLUTION][vcodec*=264]+bestaudio/bestvideo[height<=$MAX_RESOLUTION][vcodec!*=vp0][vcodec!*=vp9][vcodec!*=av01]+bestaudio/best"
$VIDEO_SORT = "res:$MAX_RESOLUTION,vcodec:h265,acodec:aac"
$MERGE_FORMAT = "mp4"
'@ | Set-Content -Path $settingsPath -Encoding UTF8
    Write-Host "Created yt-settings.ps1 (edit this file!)" -ForegroundColor Yellow
} else {
    Write-Host "yt-settings.ps1 already exists, skipping" -ForegroundColor DarkGray
}

# ytv.ps1
@'
# Download video with h265/1440p/mp4 settings
. "$PSScriptRoot\yt-settings.ps1"

$URL = Read-Host "URL"

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
$args_ += "-S", $VIDEO_SORT
$args_ += "-f", $VIDEO_FORMAT
$args_ += "--merge-output-format", $MERGE_FORMAT
$args_ += "--embed-metadata", "--embed-thumbnail", "--convert-thumbnails", "jpg"
$args_ += "--write-description", "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", "$OUTPUT_DIR/%(title)s.%(ext)s"
$args_ += $URL

& yt-dlp @args_
'@ | Set-Content -Path (Join-Path $binDir "ytv.ps1") -Encoding UTF8
Write-Host "Created ytv.ps1"

# yta.ps1
@'
# Download audio only (best quality, mp3)
. "$PSScriptRoot\yt-settings.ps1"

$URL = Read-Host "URL"

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
$args_ += "-f", "bestaudio", "-x", "--audio-format", "mp3", "--audio-quality", "0"
$args_ += "--embed-metadata", "--embed-thumbnail", "--convert-thumbnails", "jpg"
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", "$OUTPUT_DIR/%(title)s.%(ext)s"
$args_ += $URL

& yt-dlp @args_
'@ | Set-Content -Path (Join-Path $binDir "yta.ps1") -Encoding UTF8
Write-Host "Created yta.ps1"

# ytc.ps1
@'
# Download video clip (segment by timecodes)
. "$PSScriptRoot\yt-settings.ps1"

$URL   = Read-Host "URL"
$START = Read-Host "Start time (e.g. 00:01:30)"
$END   = Read-Host "End time (e.g. 00:02:45)"

if (-not $URL) { Write-Host "Error: URL is required"; exit 1 }

function Format-Time($t) {
    $parts = $t -split ":"
    $h = [int]$parts[0]; $m = [int]$parts[1]; $s = [int]$parts[2]
    if ($h -gt 0) { "${h}h${m}m${s}s" }
    elseif ($m -gt 0) { "${m}m${s}s" }
    else { "${s}s" }
}

$startFmt = Format-Time $START
$endFmt   = Format-Time $END

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
$args_ += "-S", $VIDEO_SORT
$args_ += "-f", $VIDEO_FORMAT
$args_ += "--merge-output-format", $MERGE_FORMAT
$args_ += "--download-sections", "*${START}-${END}"
$args_ += "--embed-metadata", "--embed-thumbnail", "--convert-thumbnails", "jpg"
$args_ += "--write-description", "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", "$OUTPUT_DIR/%(title)s [$startFmt-$endFmt].%(ext)s"
$args_ += $URL

& yt-dlp @args_
'@ | Set-Content -Path (Join-Path $binDir "ytc.ps1") -Encoding UTF8
Write-Host "Created ytc.ps1"

# ytca.ps1
@'
# Download audio clip (segment by timecodes)
. "$PSScriptRoot\yt-settings.ps1"

$URL   = Read-Host "URL"
$START = Read-Host "Start time (e.g. 00:01:30)"
$END   = Read-Host "End time (e.g. 00:02:45)"

if (-not $URL) { Write-Host "Error: URL is required"; exit 1 }

function Format-Time($t) {
    $parts = $t -split ":"
    $h = [int]$parts[0]; $m = [int]$parts[1]; $s = [int]$parts[2]
    if ($h -gt 0) { "${h}h${m}m${s}s" }
    elseif ($m -gt 0) { "${m}m${s}s" }
    else { "${s}s" }
}

$startFmt = Format-Time $START
$endFmt   = Format-Time $END

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
$args_ += "--download-sections", "*${START}-${END}"
$args_ += "-f", "bestaudio", "-x", "--audio-format", "mp3", "--audio-quality", "0"
$args_ += "--embed-metadata", "--embed-thumbnail", "--convert-thumbnails", "jpg"
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", "$OUTPUT_DIR/%(title)s [$startFmt-$endFmt].%(ext)s"
$args_ += $URL

& yt-dlp @args_
'@ | Set-Content -Path (Join-Path $binDir "ytca.ps1") -Encoding UTF8
Write-Host "Created ytca.ps1"

# yt.ps1 -- interactive launcher
@'
# yt-dlp downloader -- interactive launcher
$items = @(
    @{ Label = "Video";      Desc = "download video";                Script = "ytv.ps1" },
    @{ Label = "Audio";      Desc = "download audio";                Script = "yta.ps1" },
    @{ Label = "Video clip";  Desc = "video segment (timecodes)";   Script = "ytc.ps1" },
    @{ Label = "Audio clip";  Desc = "audio segment (timecodes)";   Script = "ytca.ps1" }
)

$sel = 0

Write-Host ""
Write-Host "  yt-dlp downloader" -ForegroundColor Cyan
Write-Host ""

$menuTop = [Console]::CursorTop

function Draw-Menu {
    [Console]::SetCursorPosition(0, $menuTop)
    for ($i = 0; $i -lt $items.Count; $i++) {
        $label = $items[$i].Label.PadRight(14)
        $desc  = $items[$i].Desc
        if ($i -eq $sel) {
            Write-Host "  > " -NoNewline -ForegroundColor Cyan
            Write-Host "$label" -NoNewline -ForegroundColor Cyan
            Write-Host " $desc" -ForegroundColor DarkGray
        } else {
            Write-Host "    $label" -NoNewline
            Write-Host " $desc" -ForegroundColor DarkGray
        }
    }
}

Draw-Menu

while ($true) {
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq "UpArrow") {
        if ($sel -gt 0) { $sel-- }
        Draw-Menu
    }
    elseif ($key.Key -eq "DownArrow") {
        if ($sel -lt $items.Count - 1) { $sel++ }
        Draw-Menu
    }
    elseif ($key.Key -eq "Enter") {
        break
    }
}

Write-Host ""

$script = Join-Path $PSScriptRoot $items[$sel].Script
. $script
'@ | Set-Content -Path (Join-Path $binDir "yt.ps1") -Encoding UTF8
Write-Host "Created yt.ps1"

# yt.bat -- launcher shortcut
@'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0yt.ps1"
'@ | Set-Content -Path (Join-Path $binDir "yt.bat") -Encoding ASCII
Write-Host "Created yt.bat"

Write-Host ""

# --- Add ~/bin/ to PATH ---

Write-Host "Adding $binDir to PATH..." -NoNewline
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
    Write-Host " added" -ForegroundColor Green
} else {
    Write-Host " already in PATH" -ForegroundColor DarkGray
}

# --- Set execution policy for scripts ---

Write-Host "Setting execution policy..." -NoNewline
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
Write-Host " done" -ForegroundColor Green

Write-Host ""
Write-Host "  Done! Restart your terminal." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next step: edit $settingsPath"
Write-Host "    - set COOKIES (or leave empty)"
Write-Host "    - set OUTPUT_DIR"
Write-Host ""
Read-Host "Press Enter to exit"
