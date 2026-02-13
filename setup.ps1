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

# yt-settings.ps1 -- create or patch missing variables
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

# Toggle flags (changed via yt.ps1 > Settings)
$EMBED_METADATA = $true
$EMBED_THUMBNAIL = $true
$WRITE_DESCRIPTION = $false
'@ | Set-Content -Path $settingsPath -Encoding UTF8
    Write-Host "Created yt-settings.ps1 (edit this file!)" -ForegroundColor Yellow
} else {
    # Patch missing variables into existing settings
    $content = Get-Content $settingsPath -Raw
    $missing = @()
    $defaults = @(
        @{ Var = "COOKIES";           Line = '$$COOKIES = ""' },
        @{ Var = "OUTPUT_DIR";        Line = '$$OUTPUT_DIR = "$$env:USERPROFILE/Videos"' },
        @{ Var = "MAX_RESOLUTION";    Line = '$$MAX_RESOLUTION = 1440' },
        @{ Var = "VIDEO_FORMAT";      Line = '$$VIDEO_FORMAT = "bestvideo[height<=$$MAX_RESOLUTION][vcodec*=265]+bestaudio/bestvideo[height<=$$MAX_RESOLUTION][vcodec*=264]+bestaudio/bestvideo[height<=$$MAX_RESOLUTION][vcodec!*=vp0][vcodec!*=vp9][vcodec!*=av01]+bestaudio/best"' },
        @{ Var = "VIDEO_SORT";        Line = '$$VIDEO_SORT = "res:$$MAX_RESOLUTION,vcodec:h265,acodec:aac"' },
        @{ Var = "MERGE_FORMAT";      Line = '$$MERGE_FORMAT = "mp4"' },
        @{ Var = "EMBED_METADATA";    Line = '$$EMBED_METADATA = $$true' },
        @{ Var = "EMBED_THUMBNAIL";   Line = '$$EMBED_THUMBNAIL = $$true' },
        @{ Var = "WRITE_DESCRIPTION"; Line = '$$WRITE_DESCRIPTION = $$false' }
    )
    foreach ($d in $defaults) {
        if ($content -notmatch ("\`$$($d.Var)\s*=")) {
            $missing += $d.Line
        }
    }
    if ($missing.Count -gt 0) {
        $patch = "`r`n# Added by setup`r`n" + ($missing -join "`r`n") + "`r`n"
        Add-Content -Path $settingsPath -Value $patch -Encoding UTF8
        Write-Host "yt-settings.ps1 updated ($($missing.Count) new variables)" -ForegroundColor Green
    } else {
        Write-Host "yt-settings.ps1 up to date" -ForegroundColor DarkGray
    }
}

# ytv.ps1
@'
# Download video with h265/1440p/mp4 settings
. "$PSScriptRoot\yt-settings.ps1"

$URL = Read-Host "URL"

$outputTpl = "$OUTPUT_DIR/%(title)s.%(ext)s"

# Preview
$previewArgs = @("--ignore-config", "--print", "filename", "-o", $outputTpl)
if ($COOKIES) { $previewArgs += "--cookies-from-browser", $COOKIES }
$previewArgs += "-S", $VIDEO_SORT
$previewArgs += "-f", $VIDEO_FORMAT
$previewArgs += "--merge-output-format", $MERGE_FORMAT
$previewArgs += $URL
$filename = (& yt-dlp @previewArgs 2>$null) | Select-Object -First 1

Write-Host ""
Write-Host "  Saving to: " -NoNewline
Write-Host "$OUTPUT_DIR" -ForegroundColor DarkGray
if ($filename) {
    Write-Host "  File:     " -NoNewline
    Write-Host (Split-Path $filename -Leaf) -ForegroundColor DarkGray
}
Write-Host ""

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

if ($LASTEXITCODE -eq 0 -and $filename) {
    Write-Host ""
    Write-Host "  Done: $filename" -ForegroundColor Green
}
'@ | Set-Content -Path (Join-Path $binDir "ytv.ps1") -Encoding UTF8
Write-Host "Created ytv.ps1"

# yta.ps1
@'
# Download audio only (best quality, mp3)
. "$PSScriptRoot\yt-settings.ps1"

$URL = Read-Host "URL"

$outputTpl = "$OUTPUT_DIR/%(title)s.%(ext)s"

# Preview
$previewArgs = @("--ignore-config", "--print", "filename", "-o", $outputTpl)
if ($COOKIES) { $previewArgs += "--cookies-from-browser", $COOKIES }
$previewArgs += "-f", "bestaudio", "-x", "--audio-format", "mp3"
$previewArgs += $URL
$filename = (& yt-dlp @previewArgs 2>$null) | Select-Object -First 1

Write-Host ""
Write-Host "  Saving to: " -NoNewline
Write-Host "$OUTPUT_DIR" -ForegroundColor DarkGray
if ($filename) {
    Write-Host "  File:     " -NoNewline
    Write-Host (Split-Path $filename -Leaf) -ForegroundColor DarkGray
}
Write-Host ""

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
$args_ += "-f", "bestaudio", "-x", "--audio-format", "mp3", "--audio-quality", "0"
if ($EMBED_METADATA) { $args_ += "--embed-metadata" }
if ($EMBED_THUMBNAIL) { $args_ += "--embed-thumbnail", "--convert-thumbnails", "jpg" }
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", $outputTpl
$args_ += $URL

& yt-dlp @args_

if ($LASTEXITCODE -eq 0 -and $filename) {
    Write-Host ""
    Write-Host "  Done: $filename" -ForegroundColor Green
}
'@ | Set-Content -Path (Join-Path $binDir "yta.ps1") -Encoding UTF8
Write-Host "Created yta.ps1"

# ytvc.ps1
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

$outputTpl = "$OUTPUT_DIR/%(title)s [$startFmt-$endFmt].%(ext)s"

# Preview
$previewArgs = @("--ignore-config", "--print", "filename", "-o", $outputTpl)
if ($COOKIES) { $previewArgs += "--cookies-from-browser", $COOKIES }
$previewArgs += "-S", $VIDEO_SORT
$previewArgs += "-f", $VIDEO_FORMAT
$previewArgs += "--merge-output-format", $MERGE_FORMAT
$previewArgs += $URL
$filename = (& yt-dlp @previewArgs 2>$null) | Select-Object -First 1

Write-Host ""
Write-Host "  Saving to: " -NoNewline
Write-Host "$OUTPUT_DIR" -ForegroundColor DarkGray
if ($filename) {
    Write-Host "  File:     " -NoNewline
    Write-Host (Split-Path $filename -Leaf) -ForegroundColor DarkGray
}
Write-Host "  Segment:  " -NoNewline
Write-Host "$START - $END" -ForegroundColor DarkGray
Write-Host ""

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
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

& yt-dlp @args_

if ($LASTEXITCODE -eq 0 -and $filename) {
    Write-Host ""
    Write-Host "  Done: $filename" -ForegroundColor Green
}
'@ | Set-Content -Path (Join-Path $binDir "ytvc.ps1") -Encoding UTF8
Write-Host "Created ytvc.ps1"

# ytac.ps1
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

$outputTpl = "$OUTPUT_DIR/%(title)s [$startFmt-$endFmt].%(ext)s"

# Preview
$previewArgs = @("--ignore-config", "--print", "filename", "-o", $outputTpl)
if ($COOKIES) { $previewArgs += "--cookies-from-browser", $COOKIES }
$previewArgs += "-f", "bestaudio", "-x", "--audio-format", "mp3"
$previewArgs += $URL
$filename = (& yt-dlp @previewArgs 2>$null) | Select-Object -First 1

Write-Host ""
Write-Host "  Saving to: " -NoNewline
Write-Host "$OUTPUT_DIR" -ForegroundColor DarkGray
if ($filename) {
    Write-Host "  File:     " -NoNewline
    Write-Host (Split-Path $filename -Leaf) -ForegroundColor DarkGray
}
Write-Host "  Segment:  " -NoNewline
Write-Host "$START - $END" -ForegroundColor DarkGray
Write-Host ""

$args_ = @("--ignore-config")
if ($COOKIES) { $args_ += "--cookies-from-browser", $COOKIES }
$args_ += "--download-sections", "*${START}-${END}"
$args_ += "-f", "bestaudio", "-x", "--audio-format", "mp3", "--audio-quality", "0"
if ($EMBED_METADATA) { $args_ += "--embed-metadata" }
if ($EMBED_THUMBNAIL) { $args_ += "--embed-thumbnail", "--convert-thumbnails", "jpg" }
$args_ += "--ignore-errors", "--no-overwrites", "--progress"
$args_ += "-o", $outputTpl
$args_ += $URL

& yt-dlp @args_

if ($LASTEXITCODE -eq 0 -and $filename) {
    Write-Host ""
    Write-Host "  Done: $filename" -ForegroundColor Green
}
'@ | Set-Content -Path (Join-Path $binDir "ytac.ps1") -Encoding UTF8
Write-Host "Created ytac.ps1"

# yt.ps1 -- interactive launcher
@'
# yt-dlp downloader -- interactive launcher
. "$PSScriptRoot\yt-settings.ps1"

$settingsFile = Join-Path $PSScriptRoot "yt-settings.ps1"

$items = @(
    @{ Label = "Video";       Desc = "download video";              Script = "ytv.ps1" },
    @{ Label = "Audio";       Desc = "download audio";              Script = "yta.ps1" },
    @{ Label = "Video clip";  Desc = "video segment (timecodes)";   Script = "ytvc.ps1" },
    @{ Label = "Audio clip";  Desc = "audio segment (timecodes)";   Script = "ytac.ps1" },
    @{ Label = "Settings";    Desc = "toggle flags";                Script = "" }
)

$sel = 0

function Show-MainMenu {
    [Console]::Clear()
    Write-Host ""
    Write-Host "  yt-dlp downloader" -ForegroundColor Cyan
    Write-Host ""
    $script:menuTop = [Console]::CursorTop
    Draw-MainMenu
}

function Draw-MainMenu {
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

function Show-Settings {
    $toggles = @(
        @{ Var = "EMBED_METADATA";    Label = "Embed metadata";    Desc = "title, author, description" },
        @{ Var = "EMBED_THUMBNAIL";   Label = "Embed thumbnail";   Desc = "cover image (jpg)" },
        @{ Var = "WRITE_DESCRIPTION"; Label = "Write description"; Desc = "save .description file" }
    )

    $ssel = 0

    function Draw-Settings {
        [Console]::SetCursorPosition(0, $settingsTop)
        for ($i = 0; $i -lt $toggles.Count; $i++) {
            $val = (Get-Variable -Name $toggles[$i].Var -ValueOnly)
            if ($val) { $check = "[x]" } else { $check = "[ ]" }
            $label = $toggles[$i].Label.PadRight(20)
            $desc  = $toggles[$i].Desc
            if ($i -eq $ssel) {
                Write-Host "  > " -NoNewline -ForegroundColor Cyan
                Write-Host "$check $label" -NoNewline -ForegroundColor Cyan
                Write-Host " $desc" -ForegroundColor DarkGray
            } else {
                Write-Host "    $check $label" -NoNewline
                Write-Host " $desc" -ForegroundColor DarkGray
            }
        }
        Write-Host ""
        Write-Host "  Enter: toggle  |  Esc: save & back" -ForegroundColor DarkGray
    }

    [Console]::Clear()
    Write-Host ""
    Write-Host "  Settings" -ForegroundColor Cyan
    Write-Host ""
    $settingsTop = [Console]::CursorTop

    Draw-Settings

    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq "UpArrow") {
            if ($ssel -gt 0) { $ssel-- }
            Draw-Settings
        }
        elseif ($key.Key -eq "DownArrow") {
            if ($ssel -lt $toggles.Count - 1) { $ssel++ }
            Draw-Settings
        }
        elseif ($key.Key -eq "Enter") {
            $varName = $toggles[$ssel].Var
            $current = (Get-Variable -Name $varName -ValueOnly)
            Set-Variable -Name $varName -Value (-not $current)
            Draw-Settings
        }
        elseif ($key.Key -eq "Escape") {
            break
        }
    }

    # Save toggles back to settings file
    $content = Get-Content $settingsFile -Raw
    foreach ($t in $toggles) {
        $varName = $t.Var
        $val = (Get-Variable -Name $varName -ValueOnly)
        if ($val) { $valStr = '$$true' } else { $valStr = '$$false' }
        $content = $content -replace ("\`$$varName\s*=\s*\`$$\w+"), "`$$varName = $valStr"
    }
    Set-Content -Path $settingsFile -Value $content -Encoding UTF8
}

Show-MainMenu

while ($true) {
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq "UpArrow") {
        if ($sel -gt 0) { $sel-- }
        Draw-MainMenu
    }
    elseif ($key.Key -eq "DownArrow") {
        if ($sel -lt $items.Count - 1) { $sel++ }
        Draw-MainMenu
    }
    elseif ($key.Key -eq "Enter") {
        if ($items[$sel].Script -eq "") {
            Show-Settings
            Show-MainMenu
        } else {
            break
        }
    }
}

Write-Host ""

$script = Join-Path $PSScriptRoot $items[$sel].Script
. $script

Write-Host ""
Read-Host "Press Enter to exit"
'@ | Set-Content -Path (Join-Path $binDir "yt.ps1") -Encoding UTF8
Write-Host "Created yt.ps1"

# yt.bat -- launcher shortcut
@'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0yt.ps1"
if %errorlevel% neq 0 (
    echo.
    echo Error occurred. See above.
    pause
)
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
