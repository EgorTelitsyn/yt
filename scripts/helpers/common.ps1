# Common helper functions for yt-dlp scripts

function Ensure-OutputDirectory($outputDir) {
    $expandedDir = $ExecutionContext.InvokeCommand.ExpandString($outputDir)
    if (-not (Test-Path $expandedDir)) {
        New-Item -ItemType Directory -Path $expandedDir -Force | Out-Null
    }
}

function Get-DownloadPreview($url, $outputTemplate, $cookies, $formatArgs) {
    $previewArgs = @("--ignore-config", "--print", "filename", "-o", $outputTemplate)
    if ($cookies) { $previewArgs += "--cookies-from-browser", $cookies }
    $previewArgs += $formatArgs
    $previewArgs += $url
    $filename = (& yt-dlp @previewArgs 2>$null) | Select-Object -First 1
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
