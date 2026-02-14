function Install-YtDlp {
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
            $null = Invoke-WithSpinner -ScriptBlock {
                param($u, $p)
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $u -OutFile $p -UseBasicParsing
            } -ArgumentList @($url, $ytdlpPath)
            if ($localVer) {
                Write-Host "updated ($localVer -> $remoteVer)" -ForegroundColor Green
            } else {
                Write-Host "installed ($remoteVer)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Install-WingetDeps {
    $packages = @(
        @{ Id = "Gyan.FFmpeg";    Name = "FFmpeg" },
        @{ Id = "DenoLand.Deno";  Name = "Deno" }
    )

    $i = 1
    foreach ($pkg in $packages) {
        $i++
        Write-Host "[$i/3] $($pkg.Name) " -NoNewline
        $result = Invoke-WithSpinner -ScriptBlock {
            param($w, $id)
            & $w install --id $id -e --source winget --accept-package-agreements --accept-source-agreements 2>&1
        } -ArgumentList @($winget, $pkg.Id)
        if ($result -match "already installed") {
            $upResult = Invoke-WithSpinner -ScriptBlock {
                param($w, $id)
                & $w upgrade --id $id -e --source winget --accept-package-agreements --accept-source-agreements 2>&1
            } -ArgumentList @($winget, $pkg.Id)
            if ($upResult -match "No available upgrade|No installed package") {
                Write-Host "latest" -ForegroundColor DarkGray
            } else {
                Write-Host "updated" -ForegroundColor Green
            }
        } else {
            Write-Host "installed" -ForegroundColor Green
        }
    }
}

function Add-DepsToPath {
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
}
