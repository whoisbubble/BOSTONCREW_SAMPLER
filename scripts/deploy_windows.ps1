param(
    [string]$BuildDir = "build-cmake",
    [string]$OutputDir = "deploy\windows",
    [string]$Configuration = "Release",
    [string]$QtBinDir = ""
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

if (-not (Test-IsUnderPath $DeployPath $ProjectRoot)) {
    throw "OutputDir must be inside the project folder for this deploy script: $DeployPath"
}

Add-DefaultQtToolPaths $QtBinDir
$cmake = Find-Cmake $BuildPath
New-Item -ItemType Directory -Force -Path $BuildPath | Out-Null

& $cmake -S $ProjectRoot -B $BuildPath -DCMAKE_BUILD_TYPE=$Configuration
Add-BuildToolPaths $BuildPath
& $cmake --build $BuildPath --config $Configuration

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

$targetExe = Join-Path $DeployPath $exeName
Copy-Item -LiteralPath $exe.FullName -Destination $targetExe -Force

foreach ($dataDir in "Samples", "Content", "SaveData") {
    $source = Join-Path $exe.Directory.FullName $dataDir
    if (Test-Path $source) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $DeployPath $dataDir) -Recurse -Force
    }
}

$windeployqt = Find-Windeployqt $QtBinDir $BuildPath
Add-ToPath ([System.IO.Path]::GetDirectoryName($windeployqt))
$deployMode = "--release"
if ($Configuration -match "Debug") {
    $deployMode = "--debug"
}

& $windeployqt $deployMode --qmldir $ProjectRoot --multimedia --compiler-runtime $targetExe

Write-Host ""
Write-Host "Deployment is ready:"
Write-Host $DeployPath
