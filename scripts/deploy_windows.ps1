param(
    [string]$BuildDir = "build-cmake",
    [string]$OutputDir = "deploy\windows",
    [string]$Configuration = "Release",
    [string]$QtBinDir = "",
    [string]$FfmpegDir = "",
    [string]$FfmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip",
    [string]$CacheDir = "deploy\.cache",
    [string]$ArchivePath = "deploy\BOSTONCREW-SAMPLER-windows.zip",
    [string]$AppExeName = "BOSTONCREW SAMPLER.exe",
    [switch]$SkipFfmpeg,
    [switch]$NoArchive
)

$ErrorActionPreference = "Stop"

$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$BuildPath = if ([System.IO.Path]::IsPathRooted($BuildDir)) {
    [System.IO.Path]::GetFullPath($BuildDir)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $BuildDir))
}
$DeployPath = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    [System.IO.Path]::GetFullPath($OutputDir)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $OutputDir))
}
$CachePath = if ([System.IO.Path]::IsPathRooted($CacheDir)) {
    [System.IO.Path]::GetFullPath($CacheDir)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $CacheDir))
}
$ArchiveFullPath = if ([System.IO.Path]::IsPathRooted($ArchivePath)) {
    [System.IO.Path]::GetFullPath($ArchivePath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $ArchivePath))
}

function Test-IsUnderPath([string]$Child, [string]$Parent) {
    $fullChild = [System.IO.Path]::GetFullPath($Child).TrimEnd('\', '/')
    $fullParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
    return $fullChild.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)
}

function Add-ToPath([string]$PathToAdd) {
    if ($PathToAdd -eq "" -or -not (Test-Path $PathToAdd)) {
        return
    }
    $full = [System.IO.Path]::GetFullPath($PathToAdd).TrimEnd('\', '/')
    foreach ($entry in $env:PATH.Split(';')) {
        if ($entry.Trim() -eq "") {
            continue
        }
        if ([System.IO.Path]::GetFullPath($entry).TrimEnd('\', '/') -eq $full) {
            return
        }
    }
    $env:PATH = "$full;$env:PATH"
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
}

function Add-DefaultQtToolPaths([string]$RequestedQtBinDir) {
    if ($RequestedQtBinDir -ne "") {
        Add-ToPath $RequestedQtBinDir
    }

    $qtCmake = "C:\Qt\Tools\CMake_64\bin"
    if (Test-Path (Join-Path $qtCmake "cmake.exe")) {
        Add-ToPath $qtCmake
    }

    $mingwBin = Get-ChildItem "C:\Qt\Tools" -Directory -Filter "mingw*" -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName "bin" } |
        Where-Object { Test-Path (Join-Path $_ "g++.exe") } |
        Sort-Object -Descending |
        Select-Object -First 1
    if ($mingwBin) {
        Add-ToPath $mingwBin
    }
}

function Find-Cmake([string]$CurrentBuildPath) {
    $fromPath = Get-Command "cmake.exe" -ErrorAction SilentlyContinue
    if ($fromPath) {
        return $fromPath.Source
    }

    $cachePath = Join-Path $CurrentBuildPath "CMakeCache.txt"
    if (Test-Path $cachePath) {
        foreach ($line in Get-Content $cachePath) {
            if ($line -match "^CMAKE_COMMAND:INTERNAL=(.+)$" -and (Test-Path $Matches[1])) {
                return $Matches[1]
            }
        }
    }

    $fallback = "C:\Qt\Tools\CMake_64\bin\cmake.exe"
    if (Test-Path $fallback) {
        return $fallback
    }

    throw "cmake.exe was not found. Add CMake to PATH or run from a Qt command prompt."
}

function Add-BuildToolPaths([string]$CurrentBuildPath) {
    $cachePath = Join-Path $CurrentBuildPath "CMakeCache.txt"
    if (-not (Test-Path $cachePath)) {
        return
    }

    foreach ($line in Get-Content $cachePath) {
        if ($line -match "^CMAKE_CXX_COMPILER:.*=(.+)$" -and (Test-Path $Matches[1])) {
            Add-ToPath ([System.IO.Path]::GetDirectoryName($Matches[1]))
        }
        if ($line -match "^CMAKE_MAKE_PROGRAM:.*=(.+)$" -and (Test-Path $Matches[1])) {
            Add-ToPath ([System.IO.Path]::GetDirectoryName($Matches[1]))
        }
    }
}

function Find-Windeployqt([string]$RequestedQtBinDir, [string]$CurrentBuildPath) {
    if ($RequestedQtBinDir -ne "") {
        $candidate = Join-Path $RequestedQtBinDir "windeployqt.exe"
        if (Test-Path $candidate) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
        throw "windeployqt.exe was not found in QtBinDir: $RequestedQtBinDir"
    }

    $fromPath = Get-Command "windeployqt.exe" -ErrorAction SilentlyContinue
    if ($fromPath) {
        return $fromPath.Source
    }

    $cachePath = Join-Path $CurrentBuildPath "CMakeCache.txt"
    if (Test-Path $cachePath) {
        foreach ($line in Get-Content $cachePath) {
            if ($line -match "^Qt6_DIR:PATH=(.+)$") {
                $qtDir = $Matches[1]
                $candidate = [System.IO.Path]::GetFullPath((Join-Path $qtDir "..\..\bin\windeployqt.exe"))
                if (Test-Path $candidate) {
                    return $candidate
                }
            }
            if ($line -match "^CMAKE_PREFIX_PATH:.*=(.+)$") {
                foreach ($prefix in $Matches[1].Split(';')) {
                    if ($prefix.Trim() -eq "") {
                        continue
                    }
                    $candidate = Join-Path $prefix "bin\windeployqt.exe"
                    if (Test-Path $candidate) {
                        return [System.IO.Path]::GetFullPath($candidate)
                    }
                }
            }
        }
    }

    throw "windeployqt.exe was not found. Add Qt bin to PATH or pass -QtBinDir C:\Qt\6.x.x\mingw_64\bin."
}

function Find-ToolInDir([string]$Root, [string]$FileName) {
    if ($Root -eq "" -or -not (Test-Path $Root)) {
        return $null
    }
    $direct = Join-Path $Root $FileName
    if (Test-Path $direct) {
        return [System.IO.Path]::GetFullPath($direct)
    }
    $found = Get-ChildItem -LiteralPath $Root -Filter $FileName -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        Select-Object -First 1
    if ($found) {
        return $found.FullName
    }
    return $null
}

function Resolve-FfmpegTools([string]$RequestedFfmpegDir, [string]$DownloadUrl, [string]$CurrentCachePath) {
    $candidateRoots = @()
    if ($RequestedFfmpegDir -ne "") {
        $candidateRoots += [System.IO.Path]::GetFullPath($RequestedFfmpegDir)
    }
    $candidateRoots += (Join-Path $ProjectRoot "ffmpeg")
    $candidateRoots += (Join-Path $CurrentCachePath "ffmpeg")

    foreach ($root in $candidateRoots) {
        $ffmpeg = Find-ToolInDir $root "ffmpeg.exe"
        $ffprobe = Find-ToolInDir $root "ffprobe.exe"
        if ($ffmpeg -and $ffprobe) {
            return @{
                Ffmpeg = $ffmpeg
                Ffprobe = $ffprobe
            }
        }
    }

    if ($RequestedFfmpegDir -ne "") {
        throw "ffmpeg.exe and ffprobe.exe were not found in FfmpegDir: $RequestedFfmpegDir"
    }

    New-Item -ItemType Directory -Force -Path $CurrentCachePath | Out-Null
    $zipPath = Join-Path $CurrentCachePath "ffmpeg-release-essentials.zip"
    $extractPath = Join-Path $CurrentCachePath "ffmpeg"

    if (-not (Test-Path $zipPath)) {
        Write-Host "Downloading FFmpeg..."
        Write-Host $DownloadUrl
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipPath
    }

    if (Test-Path $extractPath) {
        Remove-Item -LiteralPath $extractPath -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $extractPath | Out-Null
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

    $ffmpegDownloaded = Find-ToolInDir $extractPath "ffmpeg.exe"
    $ffprobeDownloaded = Find-ToolInDir $extractPath "ffprobe.exe"
    if (-not $ffmpegDownloaded -or -not $ffprobeDownloaded) {
        throw "Downloaded FFmpeg archive does not contain ffmpeg.exe and ffprobe.exe."
    }

    return @{
        Ffmpeg = $ffmpegDownloaded
        Ffprobe = $ffprobeDownloaded
    }
}

function Copy-FfmpegToDeploy([hashtable]$Tools, [string]$CurrentDeployPath) {
    $targetDir = Join-Path $CurrentDeployPath "ffmpeg"
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Copy-Item -LiteralPath $Tools.Ffmpeg -Destination (Join-Path $targetDir "ffmpeg.exe") -Force
    Copy-Item -LiteralPath $Tools.Ffprobe -Destination (Join-Path $targetDir "ffprobe.exe") -Force
}

function Remove-LocalLicenseState([string]$CurrentDeployPath) {
    $saveData = Join-Path $CurrentDeployPath "SaveData"
    if (-not (Test-Path $saveData)) {
        return
    }
    Get-ChildItem -LiteralPath $saveData -Filter "license.json*" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force
}

if (-not (Test-IsUnderPath $DeployPath $ProjectRoot)) {
    throw "OutputDir must be inside the project folder for this deploy script: $DeployPath"
}
if (-not (Test-IsUnderPath $CachePath $ProjectRoot)) {
    throw "CacheDir must be inside the project folder for this deploy script: $CachePath"
}
if (-not $NoArchive -and -not (Test-IsUnderPath $ArchiveFullPath $ProjectRoot)) {
    throw "ArchivePath must be inside the project folder for this deploy script: $ArchiveFullPath"
}

Add-DefaultQtToolPaths $QtBinDir
$cmake = Find-Cmake $BuildPath
New-Item -ItemType Directory -Force -Path $BuildPath | Out-Null

Invoke-NativeCommand $cmake -S $ProjectRoot -B $BuildPath "-DCMAKE_BUILD_TYPE=$Configuration"
Add-BuildToolPaths $BuildPath
Invoke-NativeCommand $cmake --build $BuildPath --config $Configuration

$exeName = "appCPlusEventSampler.exe"
$exe = Get-ChildItem -Path $BuildPath -Filter $exeName -Recurse -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $exe) {
    throw "Built executable was not found under $BuildPath"
}

if (Test-Path $DeployPath) {
    Remove-Item -LiteralPath $DeployPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $DeployPath | Out-Null

$targetExe = Join-Path $DeployPath $AppExeName
Copy-Item -LiteralPath $exe.FullName -Destination $targetExe -Force

foreach ($dataDir in "Samples", "Content", "SaveData") {
    $source = Join-Path $exe.Directory.FullName $dataDir
    $destination = Join-Path $DeployPath $dataDir
    if (Test-Path $source) {
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    } else {
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
    }
}
Remove-LocalLicenseState $DeployPath

$windeployqt = Find-Windeployqt $QtBinDir $BuildPath
Add-ToPath ([System.IO.Path]::GetDirectoryName($windeployqt))
$deployMode = "--release"
if ($Configuration -match "Debug") {
    $deployMode = "--debug"
}

Invoke-NativeCommand $windeployqt $deployMode --qmldir $ProjectRoot --multimedia --compiler-runtime $targetExe

if (-not $SkipFfmpeg) {
    $ffmpegTools = Resolve-FfmpegTools $FfmpegDir $FfmpegUrl $CachePath
    Copy-FfmpegToDeploy $ffmpegTools $DeployPath
}

if (-not $NoArchive) {
    New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($ArchiveFullPath)) | Out-Null
    if (Test-Path $ArchiveFullPath) {
        Remove-Item -LiteralPath $ArchiveFullPath -Force
    }
    Compress-Archive -Path (Join-Path $DeployPath "*") -DestinationPath $ArchiveFullPath -Force
}

Write-Host ""
Write-Host "Deployment is ready:"
Write-Host $DeployPath
if (-not $SkipFfmpeg) {
    Write-Host "FFmpeg bundled:"
    Write-Host (Join-Path $DeployPath "ffmpeg")
}
if (-not $NoArchive) {
    Write-Host "Archive is ready:"
    Write-Host $ArchiveFullPath
}
