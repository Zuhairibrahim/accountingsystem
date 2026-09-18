# توليد أيقونة التطبيق الجديدة (ويب: favicon + PWA icons)
# التصميم: خلفية كحلية متدرجة + أعمدة صاعدة ذهبية مع سهم نمو — هوية محاسبية حديثة
param(
    [string]$ProjectRoot
)
Add-Type -AssemblyName System.Drawing

if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
$OutDir = Join-Path $ProjectRoot 'web\icons'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$GOLD  = [System.Drawing.ColorTranslator]::FromHtml('#F5B21A')
$GOLD2 = [System.Drawing.ColorTranslator]::FromHtml('#D98E04')
$NAVY1 = [System.Drawing.ColorTranslator]::FromHtml('#1E3A8A')
$NAVY2 = [System.Drawing.ColorTranslator]::FromHtml('#0B1220')

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

# $scale = معامل القياس (1.0 للأيقونة العادية، 0.72 للـ maskable بهامش أمان)
function New-Icon([int]$S, [double]$scale) {
    $bmp = New-Object System.Drawing.Bitmap($S, $S)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::Transparent)

    # ===== الخلفية الكحلية المتدرجة =====
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle(0, 0, $S, $S)), $NAVY1, $NAVY2, 45)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.FillRectangle($bgBrush, 0, 0, $S, $S)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    # لمعان ناعم
    $glow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(22, 255, 255, 255))
    $g.FillEllipse($glow, ($S * 0.45), (-$S * 0.35), ($S * 0.85), ($S * 0.85))
    $g.FillEllipse($glow, (-$S * 0.3), ($S * 0.5), ($S * 0.8), ($S * 0.8))

    # ===== الرمز: أعمدة صاعدة ذهبية + سهم نمو =====
    $u = $S / 512.0            # وحدة قياس
    $cx = $S / 2.0
    $symH = 220 * $u * $scale  # ارتفاع منطقة الرمز
    $baseY = $cx + $symH / 2   # خط القاعدة

    # تدرج ذهبي للأعمدة
    $symRect = New-Object System.Drawing.Rectangle(0, 0, $S, $S)
    $goldBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $symRect, $GOLD, $GOLD2, 90)

    # الأعمدة الأربعة الصاعدة (حواف دائرية)
    $bw = 34 * $u * $scale        # عرض العمود
    $gap = 26 * $u * $scale       # المسافة بين الأعمدة
    $heights = @(52, 92, 132, 172)
    $totalW = ($bw * 4) + ($gap * 3)
    $startX = $cx - $totalW / 2
    for ($i = 0; $i -lt 4; $i++) {
        $h = $heights[$i] * $u * $scale
        $x = $startX + ($i * ($bw + $gap))
        $r = [Math]::Min($bw / 2, 10 * $u * $scale)
        $bar = New-RoundRect ([float]$x) ([float]($baseY - $h)) ([float]$bw) ([float]$h) ([float]$r)
        $g.FillPath($goldBrush, $bar)
    }

    # سهم النمو الصاعد فوق الأعمدة
    $pen = New-Object System.Drawing.Pen($GOLD, [float](16 * $u * $scale))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $arrowY = $baseY - $symH - (6 * $u * $scale)
    $g.DrawArc($pen,
        [float]($startX - (10 * $u * $scale)), [float]($arrowY + (30 * $u * $scale)),
        [float]($totalW + (20 * $u * $scale)), [float](90 * $u * $scale), 200, 90)

    # رأس السهم
    $ah = 16 * $u * $scale
    $ax = $startX + $totalW + (8 * $u * $scale)
    $ay = $arrowY + (28 * $u * $scale)
    $arrowPts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    $arrowPts.Add([System.Drawing.PointF]::new([float]($ax - $ah), [float]($ay - $ah * 1.1)))
    $arrowPts.Add([System.Drawing.PointF]::new([float]($ax + $ah * 0.9), [float]($ay - $ah * 0.1)))
    $arrowPts.Add([System.Drawing.PointF]::new([float]($ax - $ah * 0.4), [float]($ay + $ah * 1.2)))
    $arrowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $arrowPath.AddPolygon([System.Drawing.PointF[]]$arrowPts.ToArray())
    $g.FillPath($goldBrush, $arrowPath)

    # خط قاعدة رفيع
    $basePen = New-Object System.Drawing.Pen(
        [System.Drawing.Color]::FromArgb(120, 245, 178, 26), [float](6 * $u * $scale))
    $basePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $basePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($basePen,
        [float]($startX - (14 * $u * $scale)), [float]($baseY + (16 * $u * $scale)),
        [float]($startX + $totalW + (14 * $u * $scale)), [float]($baseY + (16 * $u * $scale)))

    $g.Dispose()
    return $bmp
}

function Save-Icon([System.Drawing.Bitmap]$src, [string]$path, [int]$size) {
    if ($size -eq $src.Width) {
        $src.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        return
    }
    $small = New-Object System.Drawing.Bitmap($size, $size)
    $ig = [System.Drawing.Graphics]::FromImage($small)
    $ig.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $ig.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $ig.DrawImage($src, 0, 0, $size, $size)
    $ig.Dispose()
    $small.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $small.Dispose()
}

# العادية (رمز كامل الحجم)
$normal512 = New-Icon 512 1.0
Save-Icon $normal512 (Join-Path $OutDir 'Icon-512.png') 512
Save-Icon $normal512 (Join-Path $OutDir 'Icon-192.png') 192
$fav = New-Object System.Drawing.Bitmap(64, 64)
$fg = [System.Drawing.Graphics]::FromImage($fav)
$fg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$fg.DrawImage($normal512, 0, 0, 64, 64)
$fg.Dispose()
$fav.Save((Join-Path $ProjectRoot 'web\favicon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$fav.Dispose()
$normal512.Dispose()

# الـ maskable (بهامش أمان — الرمز أصغر داخل خلفية كاملة)
$mask512 = New-Icon 512 0.68
Save-Icon $mask512 (Join-Path $OutDir 'Icon-maskable-512.png') 512
Save-Icon $mask512 (Join-Path $OutDir 'Icon-maskable-192.png') 192
$mask512.Dispose()

Write-Output "[تم] تم توليد أيقونات الويب الجديدة في $OutDir"
