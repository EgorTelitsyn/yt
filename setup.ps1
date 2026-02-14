$setupDir = $PSScriptRoot

. "$setupDir\resources\helpers.ps1"
. "$setupDir\resources\install.ps1"
. "$setupDir\resources\write-scripts.ps1"

Write-Host ""
Write-Host "  yt-dlp scripts - setup" -ForegroundColor Cyan
Write-Host ""

$binDir = "$env:USERPROFILE\bin"
if (-not (Test-Path $binDir)) { New-Item -Path $binDir -ItemType Directory | Out-Null }

$winget = Resolve-Winget

Install-YtDlp
Install-WingetDeps
Write-Host ""
Add-DepsToPath

Write-Host ""
$detectedBrowser = Get-DefaultBrowser
$settingsPath = Join-Path $binDir "yt-settings.ps1"
Write-YtSettings
Install-YtScripts

Write-Host ""
# Add ~/bin/ to PATH
Write-Host "Adding $binDir to PATH..." -NoNewline
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
    Write-Host " added" -ForegroundColor Green
} else {
    Write-Host " already in PATH" -ForegroundColor DarkGray
}

# Set execution policy
Write-Host "Setting execution policy..." -NoNewline
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
Write-Host " done" -ForegroundColor Green

Write-Host ""
Write-Host "  Done! Restart your terminal." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next step: edit $settingsPath"
if (-not $detectedBrowser) {
    Write-Host "    - set COOKIES (or leave empty)"
}
Write-Host "    - set OUTPUT_DIR"
Write-Host ""
Read-Host "Press Enter to exit"
