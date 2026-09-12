"""بناء ملفات التشغيل التنفيذية (EXE) للأنظمة + برنامج إنشاء الفرع.

- يولّد أيقونة مخصصة لكل نظام عبر render_icon.ps1 (تاج للأدمن، متجر للفروع،
  علامة + لمنشئ الفروع) بحيث يظهر اسم النظام ورمزه داخل أيقونة سطح المكتب.
- يبني كل تطبيق بأيقونته الخاصة، والتطبيق عند فتحه ينقل المستخدم تلقائياً إلى
  Google Chrome ويفتح النظام السحابي لفرعه على Firebase.
- المخرجات في C:/Users/PC/Desktop/admin
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(os.path.expanduser('~'), 'Desktop', 'admin')
WORK_DIR = os.path.join(tempfile.gettempdir(), 'opencode', 'exe_build')
ICON_DIR = os.path.join(WORK_DIR, 'icons')
RENDER_PS1 = os.path.join(HERE, 'render_icon.ps1')

# (اسم التطبيق, معرف النظام sys, رمز الشارة, نوع الأيقونة, لون البدء, لون النهاية)
SYSTEMS = [
    ('النظام الأساسي', 'admin', 'ADM-01', 'admin', '#F59E0B', '#92400E'),
    ('فرع صنعاء', 'branch1', 'BR01', 'branch', '#0EA5E9', '#0C4A6E'),
    ('فرع عدن', 'branch2', 'BR02', 'branch', '#10B981', '#064E3B'),
    ('فرع تعز', 'branch3', 'BR03', 'branch', '#F472B6', '#831843'),
    ('فرع الحديدة', 'branch4', 'BR04', 'branch', '#A78BFA', '#4C1D95'),
    ('فرع ذمار', 'branch5', 'BR05', 'branch', '#14B8A6', '#134E4A'),
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