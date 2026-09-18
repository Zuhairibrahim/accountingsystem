"""بناء التطبيق التنفيذي (EXE) للنظام الأساسي (الأدمن).

- يولّد أيقونة مخصصة عبر render_icon.ps1 (تاج للأدمن) بحيث يظهر اسم
  النظام داخل أيقونة سطح المكتب.
- التطبيق عند فتحه ينقل المستخدم تلقائياً إلى Google Chrome ويفتح النظام
  السحابي على Firebase (كل البيانات والفروع عبر السحابة).
- الفروع الجديدة لا تُبنى هنا: تُبنى تلقائياً عند إضافتها من الأدمن عبر
  serve_all.py (تطبيق مستقل بأيقونة تحمل اسم الفرع داخل مجلد المسؤول).
- المخرجات في C:/Users/PC/Desktop/admin
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = r'C:\Users\PC\Desktop\googlgg'
WORK_DIR = os.path.join(tempfile.gettempdir(), 'opencode', 'exe_build')
ICON_DIR = os.path.join(WORK_DIR, 'icons')
RENDER_PS1 = os.path.join(HERE, 'render_icon.ps1')

# (اسم التطبيق, معرف النظام sys, رمز الشارة, نوع الأيقونة, لون البدء, لون النهاية)
SYSTEMS = [
    ('النظام الأساسي', 'admin', 'ADM-01', 'admin', '#1E3A8A', '#0B1220'),
]


def _render_icon(meta_lines, out_base):
    meta_path = os.path.join(ICON_DIR, os.path.splitext(os.path.basename(out_base))[0] + '.txt')
    with open(meta_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(meta_lines) + '\n')
    subprocess.run(
        [
            'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', RENDER_PS1, '-MetaPath', meta_path, '-OutBase', out_base,
        ],
        check=True,
    )
    ico = out_base + '.ico'
    if not os.path.isfile(ico):
        raise SystemExit(f'فشل توليد الأيقونة: {ico}')
    return ico


def _build(script, exe_name, icon_path, include_render=True):
    print(f'بناء {exe_name} ...', flush=True)
    cmd = [
        sys.executable, '-m', 'PyInstaller',
        '--onefile', '--windowed',
        '--name', exe_name,
        '--icon', icon_path,
        '--noconfirm',
        '--distpath', WORK_DIR,
        '--workpath', os.path.join(WORK_DIR, 'work'),
        '--specpath', WORK_DIR,
    ]
    if include_render:
        cmd += ['--add-data', RENDER_PS1 + ';render_icon.ps1']
    cmd.append(os.path.join(HERE, script))
    subprocess.run(cmd, check=True)
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
    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)

    for name, mode, badge, kind, c1, c2 in SYSTEMS:
        out_base = os.path.join(ICON_DIR, mode)
        print(f'توليد أيقونة {name} ...', flush=True)
        icon = _render_icon(
            (name, 'النظام المحاسبي', badge, kind, c1, c2), out_base,
        )
        launcher = _build('launcher.py', name, icon, include_render=False)
        target = os.path.join(OUT_DIR, name + '.exe')
        shutil.copyfile(launcher, target)
        print(f'[تم] {name}.exe', flush=True)

    os.makedirs(os.path.join(OUT_DIR, 'icons'), exist_ok=True)
    for name, mode, badge, kind, c1, c2 in SYSTEMS:
        shutil.copyfile(
            os.path.join(ICON_DIR, mode + '.ico'),
            os.path.join(OUT_DIR, 'icons', mode + '.ico'),
        )

    print(f'\nاكتمل البناء. الملفات في:\n{OUT_DIR}')


if __name__ == '__main__':
    main()