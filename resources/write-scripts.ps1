function Write-YtSettings {
    if (-not (Test-Path $settingsPath)) {
        $templatePath = Join-Path $setupDir "scripts\yt-settings.ps1"
        $template = Get-Content $templatePath -Raw
        if ($detectedBrowser) {
            $template = $template -replace '\$COOKIES = ""', "`$COOKIES = `"$detectedBrowser`""
        }
        $template | Set-Content -Path $settingsPath -Encoding UTF8
        if ($detectedBrowser) {
            Write-Host "Created yt-settings.ps1 (cookies: $detectedBrowser)" -ForegroundColor Green
        } else {
            Write-Host "Created yt-settings.ps1 (edit this file!)" -ForegroundColor Yellow
        }
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
}

function Install-YtScripts {
    $scriptsDir = Join-Path $setupDir "scripts"
    $scriptFiles = @("ytv.ps1", "yta.ps1", "ytvc.ps1", "ytac.ps1", "yt.ps1")
    foreach ($file in $scriptFiles) {
        $src = Join-Path $scriptsDir $file
        $dst = Join-Path $binDir $file
        (Get-Content $src -Raw) | Set-Content -Path $dst -Encoding UTF8
        Write-Host "Created $file"
    }
    # yt.bat uses ASCII encoding
    $batSrc = Join-Path $scriptsDir "yt.bat"
    $batDst = Join-Path $binDir "yt.bat"
    (Get-Content $batSrc -Raw) | Set-Content -Path $batDst -Encoding ASCII
    Write-Host "Created yt.bat"
}
