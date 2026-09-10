"""مشغّل نظام محاسبي: يفتح النظام المحدد في Google Chrome كتطبيق مستقل.

يتعرّف المشغّل على النظام من اسم ملفه التنفيذي (مثال: «فرع ذمار.exe») ويفتح
الرابط السحابي الثابت https://accountingsystem-fc3f0.web.app/?sys=<وضع النظام>.
"""
import os
import subprocess
import sys

HOST = 'https://accountingsystem-fc3f0.web.app'

# اسم النظام في الملف التنفيذي -> (معرف النظام sys, الاسم الظاهر)
SYSTEMS = {
    'النظام الأساسي': ('admin', 'النظام الأساسي (التحكم)'),
    'فرع صنعاء': ('branch1', 'فرع صنعاء'),
    'فرع عدن': ('branch2', 'فرع عدن'),
    'فرع تعز': ('branch3', 'فرع تعز'),
    'فرع الحديدة': ('branch4', 'فرع الحديدة'),
    'فرع ذمار': ('branch5', 'فرع ذمار'),
}

CHROME_CANDIDATES = [
    os.path.expandvars(r'%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe'),
    os.path.join(os.environ.get('ProgramFiles', ''), 'Google',
                 'Chrome', 'Application', 'chrome.exe'),
    os.path.join(os.environ.get('ProgramFiles(x86)', ''),
                 'Google', 'Chrome', 'Application', 'chrome.exe'),
]

EDGE_CANDIDATES = [
    os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\Edge\Application\msedge.exe'),
    os.path.join(os.environ.get('ProgramFiles', ''), 'Microsoft',
                 'Edge', 'Application', 'msedge.exe'),
]


def _find_browser():
    for path in CHROME_CANDIDATES + EDGE_CANDIDATES:
        if path and os.path.isfile(path):
            return path
    for cand in ('chrome', 'msedge'):
        path = _where(cand)
        if path:
            return path
    return None


def _where(name):
    try:
        out = subprocess.check_output(
            ['where', name], shell=True, text=True, stderr=subprocess.STDOUT,
        )
        return out.strip().splitlines()[0].strip()
    except Exception:
        return None


def _find_mode():
    name = os.path.splitext(os.path.basename(sys.executable))[0]
    entry = SYSTEMS.get(name)
    if entry is None:
        entry = SYSTEMS['النظام الأساسي']
    return entry


def main():
    mode, label = _find_mode()
    url = f'{HOST}/?sys={mode}'
    browser = _find_browser()
    if browser:
        try:
            subprocess.Popen(
                [browser, f'--app={url}', '--new-window'],
                close_fds=True,
            )
            return 0
        except Exception:
            pass
    # احتياط: فتح الرابط في المتصفح الافتراضي
    os.startfile(url)  # noqa: S606


if __name__ == '__main__':
    sys.exit(main())