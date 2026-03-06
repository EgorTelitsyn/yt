$setupDir = $PSScriptRoot
. "$setupDir\resources\helpers.ps1"

$binDir = "$env:USERPROFILE\bin"

Write-Host ""
Write-Host "  yt-dlp scripts - uninstall" -ForegroundColor Red
Write-Host ""
Write-Host "  Will remove:" -ForegroundColor DarkGray
Write-Host "    - yt-dlp, FFmpeg, Deno" -ForegroundColor DarkGray
Write-Host "    - Scripts in $binDir" -ForegroundColor DarkGray
Write-Host "    - $binDir from PATH" -ForegroundColor DarkGray
Write-Host ""
$confirm = Read-Host "  Type 'yes' to confirm"
if ($confirm -ne "yes") {
    Write-Host ""
    Write-Host "  Cancelled." -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit
}

$winget = Resolve-Winget

Write-Host ""

# Remove scripts and yt-dlp from ~/bin/
Write-Host "Removing scripts..." -NoNewline
$filesToRemove = @(
    "yt-dlp.exe",
    "yt.ps1", "ytv.ps1", "yta.ps1", "ytvc.ps1", "ytac.ps1",
    "yt.bat", "yt-settings.ps1", ".yt-update-cache.json"
)
foreach ($file in $filesToRemove) {
    $path = Join-Path $binDir $file
    if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
}
$helpersDir = Join-Path $binDir "helpers"
if (Test-Path $helpersDir) { Remove-Item $helpersDir -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host " done" -ForegroundColor Green

# Remove ~/bin from PATH
Write-Host "Removing $binDir from PATH..." -NoNewline
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = (($userPath -split ";") | Where-Object { $_ -and $_ -ne $binDir -and $_ -ne "$binDir\" }) -join ";"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")
Write-Host " done" -ForegroundColor Green

# Uninstall FFmpeg
Write-Host "Uninstalling FFmpeg..." -NoNewline
$r = Invoke-WithSpinner -ScriptBlock {
    param($w)
    & $w uninstall --id Gyan.FFmpeg -e --source winget --accept-source-agreements 2>&1
} -ArgumentList @($winget)
if ($r -match "No installed package") {
    Write-Host "not installed" -ForegroundColor DarkGray
} else {
    Write-Host "done" -ForegroundColor Green
}

# Uninstall Deno (winget)
Write-Host "Uninstalling Deno..." -NoNewline
$r = Invoke-WithSpinner -ScriptBlock {
    param($w)
    & $w uninstall --id DenoLand.Deno -e --source winget --accept-source-agreements 2>&1
} -ArgumentList @($winget)
if ($r -match "No installed package") {
    # Try removing ~/.deno manually (installed via official installer fallback)
    $denoDir = "$env:USERPROFILE\.deno"
    if (Test-Path $denoDir) {
        Remove-Item $denoDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "done (removed ~/.deno)" -ForegroundColor Green
    } else {
        Write-Host "not installed" -ForegroundColor DarkGray
    }
} else {
    Write-Host "done" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Done! Restart your terminal." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
