param(
    [string]$OutputDir = "$PSScriptRoot\..\assets"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$out = [System.IO.Path]::GetFullPath($OutputDir)
$pngPath = Join-Path $out "app_icon.png"
$icoPath = Join-Path $out "app_icon.ico"

if (!(Test-Path $pngPath)) {
    throw "Icon source not found: $pngPath"
}

$sizes = @(256, 128, 64, 48, 32, 16)
$source = [System.Drawing.Image]::FromFile($pngPath)
$images = @()

try {
    foreach ($size in $sizes) {
        $bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.DrawImage($source, 0, 0, $size, $size)

        $stream = New-Object System.IO.MemoryStream
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        $images += [pscustomobject]@{
            Size = $size
            Bytes = $stream.ToArray()
            Stream = $stream
            Bitmap = $bitmap
            Graphics = $graphics
        }
    }

    $file = [System.IO.File]::Open($icoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $writer = New-Object System.IO.BinaryWriter $file
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$images.Count)

        $offset = 6 + (16 * $images.Count)
        foreach ($image in $images) {
            $dimension = if ($image.Size -eq 256) { 0 } else { [byte]$image.Size }
            $writer.Write([byte]$dimension)
            $writer.Write([byte]$dimension)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$image.Bytes.Length)
            $writer.Write([UInt32]$offset)
            $offset += $image.Bytes.Length
        }

        foreach ($image in $images) {
            $writer.Write($image.Bytes)
        }
    } finally {
        $writer.Dispose()
        $file.Dispose()
    }
} finally {
    foreach ($image in $images) {
        if ($image.Graphics) { $image.Graphics.Dispose() }
        if ($image.Bitmap) { $image.Bitmap.Dispose() }
        if ($image.Stream) { $image.Stream.Dispose() }
    }
    $source.Dispose()
}

Write-Host "Generated $icoPath"
