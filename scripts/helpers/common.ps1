# Common helper functions for yt-dlp scripts

# Use the yt-dlp.exe installed by setup next to the scripts, not whatever comes first in PATH
# (e.g. a stale winget yt-dlp.yt-dlp package)
$YTDLP = Join-Path (Split-Path $PSScriptRoot -Parent) "yt-dlp.exe"
if (-not (Test-Path $YTDLP)) { $YTDLP = "yt-dlp" }

function Ensure-OutputDirectory($outputDir) {
    $expandedDir = $ExecutionContext.InvokeCommand.ExpandString($outputDir)
    if (-not (Test-Path $expandedDir)) {
        New-Item -ItemType Directory -Path $expandedDir -Force | Out-Null
    }
}

# Expands leading ~ and $env:VARS in a user-entered path
function Expand-UserPath([string]$path) {
    if (-not $path) { return $path }
    if ($path -match '^~(?=$|[\\/])') { $path = $HOME + $path.Substring(1) }
    try { return $ExecutionContext.InvokeCommand.ExpandString($path) } catch { return $path }
}

# yt-dlp cookie arguments: $useFile picks --cookies ($cookiesFile) or --cookies-from-browser ($cookies).
# Returns $null if the cookies file is set but missing.
function Get-CookieArgs($cookies, $cookiesFile, $useFile) {
    if ($useFile) {
        if (-not $cookiesFile) { return ,@() }
        $path = Expand-UserPath $cookiesFile
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Write-Host "  Cookies file not found: $path" -ForegroundColor Red
            Write-Host "  Fix it in yt > Settings > Cookies file" -ForegroundColor DarkGray
            return $null
        }
        # yt-dlp requires Netscape format; LF line endings on Windows can cause HTTP 400
        $raw = [System.IO.File]::ReadAllText($path)
        if ($raw -notmatch '^\s*# (Netscape )?HTTP Cookie File') {
            Write-Host "  Warning: cookies file is not in Netscape format (first line must be '# Netscape HTTP Cookie File')" -ForegroundColor Yellow
        }
        if ($raw.Contains("`n") -and -not $raw.Contains("`r`n")) {
            Write-Host "  Warning: cookies file has LF line endings, Windows expects CRLF (may cause HTTP 400)" -ForegroundColor Yellow
        }
        return ,@("--cookies", $path)
    }
    if ($cookies) { return ,@("--cookies-from-browser", $cookies) }
    return ,@()
}

# Candidates for Tab completion of a partially typed path (directories end with \)
function Get-PathCompletions([string]$text, [bool]$directoryOnly) {
    $expanded = Expand-UserPath $text
    if ($expanded -match '^[A-Za-z]:$') { return @("$expanded\") }
    $sep = $expanded.LastIndexOfAny([char[]]@('\', '/'))
    if ($sep -ge 0) {
        $dir       = $expanded.Substring(0, $sep + 1)
        $prefix    = $expanded.Substring($sep + 1)
        $searchDir = $dir
    } else {
        $dir       = ""
        $prefix    = $expanded
        $searchDir = (Get-Location).Path
    }
    if (-not (Test-Path -LiteralPath $searchDir -PathType Container)) { return @() }
    Get-ChildItem -LiteralPath $searchDir -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) } |
        Where-Object { $_.PSIsContainer -or -not $directoryOnly } |
        Sort-Object @{ Expression = { -not $_.PSIsContainer } }, Name |
        ForEach-Object { if ($_.PSIsContainer) { "$dir$($_.Name)\" } else { "$dir$($_.Name)" } }
}

# Line input prefilled with $initial; Esc cancels (returns $null).
# -Path enables Tab / Shift+Tab completion (-DirectoryOnly limits it to folders).
function Read-Input([string]$prompt, [string]$initial = "", [switch]$Path, [switch]$DirectoryOnly) {
    Write-Host $prompt -NoNewline
    $text      = $initial
    $drawnLen  = 0
    $startLeft = [Console]::CursorLeft
    $startTop  = [Console]::CursorTop
    $matches_  = $null
    $mi        = -1

    while ($true) {
        # Redraw (input may wrap across lines and scroll the buffer)
        $w = [Console]::BufferWidth
        [Console]::SetCursorPosition($startLeft, $startTop)
        $pad = [Math]::Max(0, $drawnLen - $text.Length)
        [Console]::Write($text + (' ' * $pad))
        $drawnLen = $text.Length
        $end = $startLeft + $text.Length + $pad
        $top = [Console]::CursorTop
        if ($end -gt 0 -and $end % $w -eq 0 -and [Console]::CursorLeft -ne 0) { $top++ }  # delayed wrap
        $startTop = $top - [Math]::Floor($end / $w)
        $pos = $startLeft + $text.Length
        $row = [Math]::Min($startTop + [Math]::Floor($pos / $w), [Console]::BufferHeight - 1)
        [Console]::SetCursorPosition($pos % $w, $row)

        $key = [Console]::ReadKey($true)
        if ($key.Key -eq "Enter")  { Write-Host ""; return $text }
        if ($key.Key -eq "Escape") { Write-Host ""; return $null }

        if ($key.Key -eq "Tab") {
            if (-not $Path) { continue }
            if ($null -eq $matches_) { $matches_ = @(Get-PathCompletions $text $DirectoryOnly.IsPresent) }
            if ($matches_.Count -eq 0) { continue }
            $back = ($key.Modifiers -band [ConsoleModifiers]::Shift)
            if ($back) {
                if ($mi -le 0) { $mi = $matches_.Count - 1 } else { $mi-- }
            } else {
                $mi = ($mi + 1) % $matches_.Count
            }
            $text = $matches_[$mi]
        } else {
            $matches_ = $null
            $mi = -1
            if ($key.Key -eq "Backspace") {
                if ($text.Length -eq 0) { continue }
                $text = $text.Substring(0, $text.Length - 1)
            } elseif ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                $text += $key.KeyChar
            }
        }
    }
}

# Asks for the given fields in order; Esc goes back one field, Esc on the first one returns $null.
# Empty answers are not accepted. Returns a hashtable Name -> value.
function Read-Steps($steps) {
    $values = @{}
    $i = 0
    while ($i -lt $steps.Count) {
        $s = $steps[$i]
        $v = Read-Input "$($s.Prompt): " $values[$s.Name]
        if ($null -eq $v) {
            if ($i -eq 0) { return $null }
            $i--
            continue
        }
        $v = $v.Trim()
        if (-not $v) { continue }
        $values[$s.Name] = $v
        $i++
    }
    return $values
}

function Get-DownloadPreview($url, $outputTemplate, $cookieArgs, $formatArgs) {
    $previewArgs = @("--ignore-config", "--print", "filename", "-o", $outputTemplate)
    $previewArgs += $cookieArgs
    $previewArgs += $formatArgs
    $previewArgs += $url
    $filename = (& $YTDLP @previewArgs 2>$null) | Select-Object -First 1
    return $filename
}

function Write-DownloadInfo($outputDir, $filename, $extraInfo) {
    Write-Host ""
    Write-Host "  Saving to: " -NoNewline
    Write-Host "$outputDir" -ForegroundColor DarkGray
    if ($filename) {
        Write-Host "  File:     " -NoNewline
        Write-Host (Split-Path $filename -Leaf) -ForegroundColor DarkGray
    }
    if ($extraInfo) {
        foreach ($key in $extraInfo.Keys) {
            Write-Host "  ${key}:  " -NoNewline
            Write-Host $extraInfo[$key] -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

function Write-Success($filename) {
    if ($LASTEXITCODE -eq 0 -and $filename) {
        Write-Host ""
        Write-Host "  Done: $filename" -ForegroundColor Green
    }
}
