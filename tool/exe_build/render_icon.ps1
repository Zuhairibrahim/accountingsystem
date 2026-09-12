param(
    [string]$MetaPath,
    [string]$OutBase
)
Add-Type -AssemblyName System.Drawing

$lines = [System.IO.File]::ReadAllLines($MetaPath, [System.Text.Encoding]::UTF8)
$Name = if ($lines.Count -gt 0) { $lines[0] } else { 'نظام' }
$Caption = if ($lines.Count -gt 1) { $lines[1] } else { 'النظام المحاسبي' }
$Badge = if ($lines.Count -gt 2) { $lines[2] } else { '' }
$Kind = if ($lines.Count -gt 3) { $lines[3] } else { 'branch' }
$C1 = [System.Drawing.ColorTranslator]::FromHtml($lines[4])
$C2 = [System.Drawing.ColorTranslator]::FromHtml($lines[5])

$GOLD = [System.Drawing.ColorTranslator]::FromHtml('#FBBF24')
$DARK = [System.Drawing.ColorTranslator]::FromHtml('#0B1220')
$WHITE = [System.Drawing.Color]::White

function New-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Fit-Font($text, $maxW, $startSize) {
    $size = [float]$startSize
    while ($true) {
        $f = New-Object System.Drawing.Font('Segoe UI', $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $w = $g.MeasureString($text, $f).Width
        if (($w -le $maxW) -or ($size -le 26)) { return $f }
        $f.Dispose()
        $size -= 4
    }
}

$S = 512
$bmp = New-Object System.Drawing.Bitmap($S, $S)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Transparent)

# ===== القاعدة: مربع مستدير بتدرّج لوني خاص بالفرع =====
$m = 8
$basePath = New-RoundRect $m $m ($S - 2 * $m) ($S - 2 * $m) 170
$baseBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(0, 0, $S, $S)), $C1, $C2, 45
)
$g.FillPath($baseBrush, $basePath)

# ===== لمعان ناعم (هالات خلفية) =====
$glow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(26, 255, 255, 255))
$g.FillEllipse($glow, 260, -200, 430, 430)
$g.FillEllipse($glow, -140, 250, 400, 400)

# ===== حلقة داخلية رفيعة =====
$ring = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(64, 255, 255, 255), 5)
$ringPath = New-RoundRect ($m + 26) ($m + 26) ($S - 2 * ($m + 26)) ($S - 2 * ($m + 26)) 136
$g.DrawPath($ring, $ringPath)

# ===== الشعار (تاج للأدمن / متجر للفروع) =====
$whiteBrush = New-Object System.Drawing.SolidBrush($WHITE)
$goldBrush = New-Object System.Drawing.SolidBrush($GOLD)
$doorBrush = New-Object System.Drawing.SolidBrush($C1)
$gemBrush = New-Object System.Drawing.SolidBrush($C1)
if ($Kind -eq 'admin') {
    # تاج ذهبي متميز للأدمن
    $cx = 256.0
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    $pts.Add([System.Drawing.PointF]::new(($cx - 75), 128.0))
    $pts.Add([System.Drawing.PointF]::new(($cx - 75), 96.0))
    $pts.Add([System.Drawing.PointF]::new(($cx - 38), 114.0))
    $pts.Add([System.Drawing.PointF]::new(($cx), 78.0))
    $pts.Add([System.Drawing.PointF]::new(($cx + 38), 114.0))
    $pts.Add([System.Drawing.PointF]::new(($cx + 75), 96.0))
    $pts.Add([System.Drawing.PointF]::new(($cx + 75), 128.0))
    $pts.Add([System.Drawing.PointF]::new(($cx + 75), 138.0))
    $pts.Add([System.Drawing.PointF]::new(($cx - 75), 138.0))
    $crown = New-Object System.Drawing.Drawing2D.GraphicsPath
    $crown.AddPolygon([System.Drawing.PointF[]]$pts.ToArray())
    $g.FillPath($goldBrush, $crown)
    $g.FillRectangle($goldBrush, ($cx - 75), 126.0, 150, 14)
    $g.FillEllipse($gemBrush, ($cx - 10), 133.0, 20, 20)
} elseif ($Kind -eq 'creator') {
    # علامة + ذهبية لمُنشئ الفروع
    $cx = 256.0
    $g.FillRectangle($goldBrush, ($cx - 70), ($cx - 38), 140, 44)
    $g.FillRectangle($goldBrush, ($cx - 22), ($cx - 86), 44, 140)
    $g.FillEllipse($goldBrush, ($cx - 70), ($cx - 70), 140, 140)
    $g.FillEllipse($gemBrush, ($cx - 18), ($cx - 18), 36, 36)
} else {
    # واجهة متجر بيضاء فاخرة للفروع
    $cx = 256.0
    $y0 = 78.0
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    $pts.Add([System.Drawing.PointF]::new(($cx - 75), ($y0 + 8)))
    $pts.Add([System.Drawing.PointF]::new(($cx + 75), ($y0 + 8)))
    $pts.Add([System.Drawing.PointF]::new(($cx), ($y0 + 44)))
    $top = New-Object System.Drawing.Drawing2D.GraphicsPath
    $top.AddPolygon([System.Drawing.PointF[]]$pts.ToArray())
    $g.FillPath($whiteBrush, $top)
    $g.FillRectangle($whiteBrush, ($cx - 66), ($y0 + 44), 132, 54)
    $g.FillRectangle($doorBrush, ($cx - 21), ($y0 + 66), 42, 32)
}

# ===== الاسم الرئيسي =====
$nameFont = Fit-Font $Name 464 96
$nameRect = New-Object System.Drawing.RectangleF(28, 210, 456, 120)
$nameFmt = New-Object System.Drawing.StringFormat
$nameFmt.Alignment = [System.Drawing.StringAlignment]::Center
$nameFmt.LineAlignment = [System.Drawing.StringAlignment]::Center
$nameFmt.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionRightToLeft
$g.DrawString($Name, $nameFont, $whiteBrush, $nameRect, $nameFmt)

# ===== السطر التعريفي =====
$capFont = New-Object System.Drawing.Font('Segoe UI', 30, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$capBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(214, 255, 255, 255))
$capRect = New-Object System.Drawing.RectangleF(28, 326, 456, 46)
$capFmt = New-Object System.Drawing.StringFormat
$capFmt.Alignment = [System.Drawing.StringAlignment]::Center
$capFmt.LineAlignment = [System.Drawing.StringAlignment]::Center
$capFmt.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionRightToLeft
$g.DrawString($Caption, $capFont, $capBrush, $capRect, $capFmt)

# ===== شارة الكود أسفل =====
if ($Badge -ne '') {
    $badgeFont = New-Object System.Drawing.Font('Segoe UI', 32, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $bw = [float]$g.MeasureString($Badge, $badgeFont).Width
    $capsuleW = $bw + 64
    $capsuleH = 56
    $cxx = (512 - $capsuleW) / 2
    $cyy = 388
    $capPath = New-RoundRect $cxx $cyy $capsuleW $capsuleH 28
    $capFill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 255, 255, 255))
    $g.FillPath($capFill, $capPath)
    $darkBrush = New-Object System.Drawing.SolidBrush($DARK)
    $badgeRect = New-Object System.Drawing.RectangleF($cxx, ($cyy - 4), $capsuleW, $capsuleH)
    $badgeFmt = New-Object System.Drawing.StringFormat
    $badgeFmt.Alignment = [System.Drawing.StringAlignment]::Center
    $badgeFmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($Badge, $badgeFont, $darkBrush, $badgeRect, $badgeFmt)
}

# ===== الحفظ =====
$OutBase = $OutBase -replace '\.(png|ico)$', ''
$bmp.Save($OutBase + '.png', [System.Drawing.Imaging.ImageFormat]::Png)

# ===== تحويل الصورة المصغرة إلى أيقونة ICO (256) =====
$icoBmp = New-Object System.Drawing.Bitmap(256, 256)
$ig = [System.Drawing.Graphics]::FromImage($icoBmp)
$ig.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$ig.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$ig.DrawImage($bmp, 0, 0, 256, 256)
$ms = New-Object System.IO.MemoryStream
$icoBmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $ms.ToArray()

$fs = New-Object System.IO.FileStream(($OutBase + '.ico'), [System.IO.FileMode]::Create)
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
$ig.Dispose()
$icoBmp.Dispose()
$g.Dispose()
$bmp.Dispose()