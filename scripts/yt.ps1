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

    $totalItems = $toggles.Count + 1  # +1 for Cookies
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
        # Cookies item
        $cval = (Get-Variable -Name "COOKIES" -ValueOnly)
        if ($cval) { $cdesc = $cval } else { $cdesc = "disabled" }
        $clabel = "Cookies".PadRight(20)
        if ($ssel -eq $toggles.Count) {
            Write-Host "  >     " -NoNewline -ForegroundColor Cyan
            Write-Host "$clabel" -NoNewline -ForegroundColor Cyan
            Write-Host " $cdesc" -ForegroundColor DarkGray
        } else {
            Write-Host "        $clabel" -NoNewline
            Write-Host " $cdesc" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  Enter: toggle/edit  |  Esc: save & back" -ForegroundColor DarkGray
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
            if ($ssel -lt $totalItems - 1) { $ssel++ }
            Draw-Settings
        }
        elseif ($key.Key -eq "Enter") {
            if ($ssel -lt $toggles.Count) {
                # Toggle item
                $varName = $toggles[$ssel].Var
                $current = (Get-Variable -Name $varName -ValueOnly)
                Set-Variable -Name $varName -Value (-not $current)
            } else {
                # Cookies editor
                [Console]::CursorVisible = $true
                $cval = (Get-Variable -Name "COOKIES" -ValueOnly)
                Write-Host ""
                Write-Host "  Current: " -NoNewline
                if ($cval) { Write-Host $cval -ForegroundColor Cyan } else { Write-Host "disabled" -ForegroundColor DarkGray }
                Write-Host "  Browser name, browser:path, or empty to disable" -ForegroundColor DarkGray
                $newVal = Read-Host "  "
                Set-Variable -Name "COOKIES" -Value $newVal
                [Console]::CursorVisible = $false
                [Console]::Clear()
                Write-Host ""
                Write-Host "  Settings" -ForegroundColor Cyan
                Write-Host ""
                $settingsTop = [Console]::CursorTop
            }
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
    # Save cookies
    $cval = (Get-Variable -Name "COOKIES" -ValueOnly)
    $oldCookies = [regex]::Match($content, '\$COOKIES\s*=\s*"[^"]*"').Value
    if ($oldCookies) {
        $content = $content.Replace($oldCookies, '$COOKIES = "' + $cval + '"')
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
