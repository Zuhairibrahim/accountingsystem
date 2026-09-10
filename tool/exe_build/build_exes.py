"""بناء ملفات التشغيل التنفيذية (EXE) للأنظمة الستة + برنامج إنشاء الفرع.

- يولّد أيقونة app.ico (بدون مكتبات خارجية).
- يبني launcher مرة واحدة ثم ينسخه بأسماء الأنظمة الستة.
- يبني برنامج إنشاء الفرع.
- المخرجات في C:/Users/PC/Desktop/admin
"""
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(os.path.expanduser('~'), 'Desktop', 'admin')
WORK_DIR = os.path.join(tempfile.gettempdir(), 'opencode', 'exe_build')

SYSTEM_EXES = [
    'النظام الأساسي.exe',
    'فرع صنعاء.exe',
    'فرع عدن.exe',
    'فرع تعز.exe',
    'فرع الحديدة.exe',
    'فرع ذمار.exe',
]

BRANCH_PROGRAM_NAME = 'إنشاء فرع جديد.exe'

ICON_PATH = os.path.join(WORK_DIR, 'app.ico')


# ============================ الأيقونة ============================
def _png_chunk(tag, data):
    body = tag + data
    return struct.pack('>I', len(data)) + body + struct.pack(
        '>I', zlib.crc32(body) & 0xFFFFFFFF
    )


def _png_from_rgba(w, h, pixels):
    raw = bytearray()
    for y in range(h):
        raw.append(0)  # مرشح بلا
        raw.extend(pixels[y * w:(y + 1) * w])
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    return (
        b'\x89PNG\r\n\x1a\n'
        + _png_chunk(b'IHDR', ihdr)
        + _png_chunk(b'IDAT', zlib.compress(bytes(raw), 9))
        + _png_chunk(b'IEND', b'')
    )


def _write_ico(path, size=256):
    w = h = size
    px = [0] * (w * h * 4)

    def setp(x, y, r, g, b, a=255):
        if 0 <= x < w and 0 <= y < h:
            i = (y * w + x) * 4
            px[i] = r
            px[i + 1] = g
            px[i + 2] = b
            px[i + 3] = a

    half, margin, radius = w // 2, 22, 60
    for y in range(h):
        for x in range(w):
            qx = abs(x - half) - (half - margin - radius)
            qy = abs(y - half) - (half - margin - radius)
            d = math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0)
            if d <= radius:
                t = y / h  # تدرّج لوني
                setp(x, y,
                     int(217 - 46 * t), int(142 - 38 * t), int(4 - 2 * t))

    # شريط القاعدة + أعمدة بيانية (مظهر تقارير محاسبية)
    def rect(x0, y0, x1, y1):
        for y in range(y0, y1):
            for x in range(x0, x1):
                setp(x, y, 255, 255, 255)

    rect(74, 168, 182, 182)                 # القاعدة
    bars = [46, 36, 52, 42]
    for i, height in enumerate(bars):
        x0 = 84 + i * 26
        rect(x0, 166 - height, x0 + 16, 168)  # العمود
    # دائرة خضراء مع علامة صح صغيرة
    cx, cy, cr = 168, 78, 26
    for y in range(h):
        for x in range(w):
            if (x - cx) ** 2 + (y - cy) ** 2 <= cr * cr:
                setp(x, y, 34, 197, 94)

    image = _png_from_rgba(w, h, px)
    header = b'\x00\x00' + struct.pack('<HH', 1, 1)
    entry = struct.pack('<BBBBHHII', 0, 0, 0, 0, 1, 32, len(image), 22)
    with open(path, 'wb') as f:
        f.write(header + entry + image)


# ============================ البناء ============================
def _build(script, exe_name):
    print(f'بناء {exe_name} ...', flush=True)
    subprocess.run(
        [
            sys.executable, '-m', 'PyInstaller',
            '--onefile', '--windowed',
            '--name', exe_name,
            '--icon', ICON_PATH,
            '--noconfirm',
            '--distpath', WORK_DIR,
            '--workpath', os.path.join(WORK_DIR, 'work'),
            '--specpath', WORK_DIR,
            os.path.join(HERE, script),
        ],
        check=True,
    )
    exe = os.path.join(WORK_DIR, exe_name + '.exe')
    if not os.path.isfile(exe):
        raise SystemExit(f'فشل البناء: {exe}')
    return exe


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass
    os.makedirs(WORK_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    _write_ico(ICON_PATH)
    print(f'الأيقونة جاهزة: {ICON_PATH}', flush=True)

    launcher = _build('launcher.py', 'launcher_app')
    for name in SYSTEM_EXES:
        target = os.path.join(OUT_DIR, name)
        shutil.copyfile(launcher, target)
        print(f'[تم] {name}', flush=True)

    program = _build('branch_program.py', 'branch_create')
    target = os.path.join(OUT_DIR, BRANCH_PROGRAM_NAME)
    shutil.copyfile(program, target)
    print(f'[تم] {BRANCH_PROGRAM_NAME}', flush=True)

    print(f'\nاكتمل البناء. الملفات في:\n{OUT_DIR}')


if __name__ == '__main__':
    main()