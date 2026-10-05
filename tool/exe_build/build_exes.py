r"""بناء التطبيق التنفيذي (EXE) للنظام الأساسي (الأدمن).

- يولّد أيقونة مخصصة عبر render_icon.ps1 (تاج للأدمن) بحيث يظهر اسم
  النظام داخل أيقونة سطح المكتب.
- التطبيق عند فتحه ينقل المستخدم تلقائياً إلى Google Chrome ويفتح النظام
  السحابي على Firebase (كل البيانات والفروع عبر السحابة).
- الفروع الجديدة لا تُبنى هنا: تُبنى تلقائياً عند إضافتها من الأدمن عبر
  serve_all.py (تطبيق مستقل بأيقونة تحمل اسم الفرع داخل مجلد التطبيقات).
- المخرجات (مسار ديناميكي يعمل على أي جهاز):
  Desktop\ZuhairSystem\التطبيقات\النظام الأساسي\النظام الأساسي.exe
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
WORK_DIR = os.path.join(tempfile.gettempdir(), 'opencode', 'exe_build')
ICON_DIR = os.path.join(WORK_DIR, 'icons')
RENDER_PS1 = os.path.join(HERE, 'render_icon.ps1')

UNIFIED_DIR_NAME = 'ZuhairSystem'
ADMIN_APP_NAME = 'النظام الأساسي'

# (اسم التطبيق, معرف النظام sys, رمز الشارة, نوع الأيقونة, لون البدء, لون النهاية)
SYSTEMS = [
    (ADMIN_APP_NAME, 'admin', 'ADM-01', 'admin', '#1E3A8A', '#0B1220'),
]


def _desktop_path():
    """مسار سطح المكتب الحقيقي للمستخدم الحالي (يتعامل مع OneDrive إلخ)."""
    try:
        out = subprocess.check_output(
            [
                'powershell', '-NoProfile', '-Command',
                "[Environment]::GetFolderPath('Desktop')"
            ],
            text=True, timeout=20,
        )
        path = out.strip()
        if path and os.path.isdir(path):
            return path
    except Exception:
        pass
    fallback = os.path.join(os.path.expanduser('~'), 'Desktop')
    return fallback if os.path.isdir(fallback) else os.path.expanduser('~')


def _admin_dir():
    """مجلد تطبيق الأدمن الخاص داخل المجلد الموحد للتطبيقات على سطح المكتب."""
    d = os.path.join(
        _desktop_path(), UNIFIED_DIR_NAME, 'التطبيقات', ADMIN_APP_NAME,
    )
    os.makedirs(d, exist_ok=True)
    return d


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
        # ملفات خادم بناء تطبيقات الفروع (API) — يُضمَّن الخادم داخل تطبيق
        # الأدمن فيشغّله تلقائياً عند الفتح ويبني أيقونة كل فرع باسمه.
        '--add-data', os.path.join(ROOT, 'serve_all.py') + ';serve_all.py',
        '--add-data', os.path.join(HERE, 'launcher.py') + ';launcher.py',
        '--add-data', RENDER_PS1 + ';render_icon.ps1',
        '--add-data',
        os.path.join(ROOT, 'apps', 'template.apk') + ';template.apk',
    ]
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
    out_dir = _admin_dir()

    for name, mode, badge, kind, c1, c2 in SYSTEMS:
        out_base = os.path.join(ICON_DIR, mode)
        print(f'توليد أيقونة {name} ...', flush=True)
        icon = _render_icon(
            (name, 'النظام المحاسبي', badge, kind, c1, c2), out_base,
        )
        launcher = _build('launcher.py', name, icon, include_render=False)
        target = os.path.join(out_dir, name + '.exe')
        shutil.copyfile(launcher, target)
        print(f'[تم] {name}.exe', flush=True)

    icons_out = os.path.join(out_dir, 'icons')
    os.makedirs(icons_out, exist_ok=True)
    for name, mode, badge, kind, c1, c2 in SYSTEMS:
        shutil.copyfile(
            os.path.join(ICON_DIR, mode + '.ico'),
            os.path.join(icons_out, mode + '.ico'),
        )

    print(f'\nاكتمل البناء. الملفات في:\n{out_dir}')


if __name__ == '__main__':
    main()