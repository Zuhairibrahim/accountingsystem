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

# ===== القاعدة: خلفية بتدرّج لوني تملأ المربع بالكامل (بلا هامش ولا شفافية) =====
$m = 0
$baseBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(0, 0, $S, $S)), $C1, $C2, 45
)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$g.FillRectangle($baseBrush, 0, 0, $S, $S)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

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
    # الهوية الجديدة: أعمدة صاعدة ذهبية + سهم نمو على تدرج كحلي
    $goldPen = New-Object System.Drawing.Pen($GOLD, 13)
    $goldPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $goldPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    # الأعمدة الأربعة الصاعدة (حواف دائرية)
    $bw = 28.0; $gap = 22.0
    $totalW = ($bw * 4) + ($gap * 3)
    $startX = 256.0 - ($totalW / 2)
    $baseY = 196.0
    $heights = @(46, 80, 114, 148)
    for ($i = 0; $i -lt 4; $i++) {
        $h = [float]$heights[$i]
        $x = [float]($startX + ($i * ($bw + $gap)))
        $bar = New-RoundRect $x ([float]($baseY - $h)) ([float]$bw) $h 9
        $g.FillPath($goldBrush, $bar)
    }

    # سهم النمو الصاعد فوق الأعمدة
    $g.DrawArc($goldPen, [float]($startX - 16), 62.0, [float]($totalW + 32), 84.0, 200, 90)

    # رأس السهم
    $ax = [float]($startX + $totalW + 14); $ay = 82.0; $ah = 17.0
    $apts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    $apts.Add([System.Drawing.PointF]::new(($ax - $ah), ($ay - $ah * 1.15)))
    $apts.Add([System.Drawing.PointF]::new(($ax + $ah * 0.95), ($ay - $ah * 0.05)))
    $apts.Add([System.Drawing.PointF]::new(($ax - $ah * 0.35), ($ay + $ah * 1.25)))
    $apPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $apPath.AddPolygon([System.Drawing.PointF[]]$apts.ToArray())
    $g.FillPath($goldBrush, $apPath)

    # خط القاعدة
    $basePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, 245, 178, 26), 7)
    $basePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $basePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($basePen, [float]($startX - 18), ($baseY + 16), [float]($startX + $totalW + 18), ($baseY + 16))
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