# تحويل أيقونة العلامة PNG إلى ICO (256 مدمج PNG) لقالب تطبيقات الفروع
param(
    [string]$PngPath,
    [string]$IcoPath
)
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile($PngPath)

# نسخة 256x256
$bmp = New-Object System.Drawing.Bitmap(256, 256)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.DrawImage($src, 0, 0, 256, 256)
$g.Dispose()
$src.Dispose()

$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $ms.ToArray()

$fs = New-Object System.IO.FileStream($IcoPath, [System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([uint16]0)      # محجوز
$bw.Write([uint16]1)      # النوع: أيقونة
$bw.Write([uint16]1)      # عدد الصور
$bw.Write([byte]0)        # العرض (0 = 256)
$bw.Write([byte]0)        # الارتفاع (0 = 256)
$bw.Write([byte]0)        # الألوان
$bw.Write([byte]0)        # محجوز
$bw.Write([uint16]1)      # المستويات
$bw.Write([uint16]32)     # عمق البت
$bw.Write([uint32]$pngBytes.Length)
$bw.Write([uint32]22)     # بداية البيانات
$bw.Write($pngBytes)
$bw.Flush()
$bw.Close()
$fs.Close()
$ms.Dispose()
$bmp.Dispose()

Write-Output "[OK] $IcoPath"
