function Resolve-Winget {
    $w = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $w) {
        $w = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
        if (-not (Test-Path $w)) {
            Write-Host "ERROR: winget not found. Install App Installer from Microsoft Store." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        }
        return $w
    }
    if ($w.Source) { return $w.Source }
    return $w
}

function Invoke-WithSpinner {
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @()
    )
    $frames = @('|','/','-','\')
    $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    $pos = [Console]::CursorLeft
    $top = [Console]::CursorTop
    $i = 0
    [Console]::CursorVisible = $false
    while ($job.State -eq 'Running') {
        [Console]::SetCursorPosition($pos, $top)
        [Console]::Write($frames[$i % 4])
        $i++
        Start-Sleep -Milliseconds 150
    }
    [Console]::SetCursorPosition($pos, $top)
    [Console]::Write(' ')
    [Console]::SetCursorPosition($pos, $top)
    [Console]::CursorVisible = $true
    if ($job.State -eq 'Failed') {
        $err = Receive-Job $job 2>&1 | Out-String
        Remove-Job $job
        throw $err
    }
    $output = Receive-Job $job 2>&1 | Out-String
    Remove-Job $job
    return $output
}

function Get-DefaultBrowser {
    try {
        $progId = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" -ErrorAction Stop).ProgId
    } catch {
        return ""
    }
    $map = @(
        @{ Pattern = "^ChromeHTML";     Browser = "chrome" },
        @{ Pattern = "^MSEdge";         Browser = "edge" },
        @{ Pattern = "^FirefoxURL";     Browser = "firefox" },
        @{ Pattern = "^Opera";          Browser = "opera" },
        @{ Pattern = "^BraveHTML";      Browser = "brave" },
        @{ Pattern = "^VivaldiHTM";     Browser = "vivaldi" },
        @{ Pattern = "^ChromiumHTM";    Browser = "chromium" }
    )
    foreach ($entry in $map) {
        if ($progId -match $entry.Pattern) {
            return $entry.Browser
        }
    }
    return ""
}
