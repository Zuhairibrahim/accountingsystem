"""مشغّل نظام محاسبي: يفتح النظام المحدد في Google Chrome كتطبيق مستقل.

- كل شيء عبر Firebase السحابية: يعمل التطبيق من أي مكان في العالم
  ومن أي جهاز — لا توجد أي بيانات أو خدمات محلية إطلاقاً.
- التطبيقات الديناميكية (الفروع المُضافة من الأدمن) يُحقن معرف النظام
  واسمه داخل الـ EXE نفسه وقت البناء (مثال: branch1 مع اسم الفرع)،
  وأيقونة التطبيق تُولَّد مباشرة باسم الفرع المُدخل من نظام الأدمن.
- احتياط: اسم الملف التنفيذي المعروف (النظام الأساسي) أو فتح الأدمن.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request

HOST = 'https://accountingsystem-fc3f0.web.app'

# نسخة التطبيق لكسر الكاش القديم في المتصفح — تُرفع مع كل تحديث مهم.
APP_VERSION = '20260926-1'

# ملف تعريف متصفح مستقل ونظيف للتطبيق — يضمن فتح أحدث نسخة من السحابة
# دائماً (لا كاش قديم ولا Service Worker قديم من جلسات التصفح العادية).
PROFILE_DIR = os.path.expandvars(
    r'%LOCALAPPDATA%\AccountingSystem\ChromeProfile',
)

# مجلد التنزيلات الرسمي للتطبيق — تطبيقات الفروع (EXE) داخل المجلد
# الموحد ZuhairSystem على سطح المكتب.
DOWNLOAD_DIR = r'C:\Users\PC\Desktop\ZuhairSystem\تطبيقات الفروع EXE'

# ==================== خادم بناء التطبيقات المحلي ====================
# تطبيق الأدمن يشغّل تلقائياً خادماً محلياً خفيفاً (serve_all.py) يقدّم
# واجهة /api/create_app — بها تُبنى تطبيقات الفروع محلياً بأيقونة تحمل
# اسم الفرع وتُنسخ إلى مجلد adszuhair مباشرة (البيانات كلها عبر Firebase).
SERVER_PING = 'http://localhost:8080/api/ping'
SERVER_DIR = os.path.expandvars(r'%LOCALAPPDATA%\AccountingSystem\server')


def _resource(name):
    """مسار ملف مُضمَّن داخل التطبيق (PyInstaller) أو بجانب الكود المصدري."""
    base = getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, name)


def _ping_server(timeout=1.0):
    try:
        with urllib.request.urlopen(SERVER_PING, timeout=timeout) as r:
            return r.status == 200
    except Exception:
        return False


def _find_python():
    """أول مفسر بايثون متاح على الجهاز (pythonw أولاً — بلا نافذة كونسول)."""
    for name in ('pythonw', 'python'):
        path = shutil.which(name)
        if path:
            return path
    patterns = [
        r'C:\Python3*\pythonw.exe',
        r'C:\Python3*\python.exe',
        os.path.expandvars(
            r'%LOCALAPPDATA%\Programs\Python\Python3*\pythonw.exe',
        ),
        os.path.expandvars(
            r'%LOCALAPPDATA%\Programs\Python\Python3*\python.exe',
        ),
        os.path.join(os.environ.get('ProgramFiles', ''), 'Python3*', 'pythonw.exe'),
        os.path.join(os.environ.get('ProgramFiles', ''), 'Python3*', 'python.exe'),
    ]
    for pattern in patterns:
        for path in sorted(glob.glob(pattern), reverse=True):
            if os.path.isfile(path):
                return path
    return None


def _install_server_files():
    """نسخ ملفات الخادم المُضمَّنة إلى مكان ثابت يستطيع بايثون تشغيله منه.

    البنية المطلوبة بجانب serve_all.py (كما في المشروع الأصلي):
        server/serve_all.py
        server/tool/exe_build/launcher.py
        server/tool/exe_build/render_icon.ps1
    """
    files = [
        (_resource('serve_all.py'), os.path.join(SERVER_DIR, 'serve_all.py')),
        (
            _resource('launcher.py'),
            os.path.join(SERVER_DIR, 'tool', 'exe_build', 'launcher.py'),
        ),
        (
            _resource('render_icon.ps1'),
            os.path.join(SERVER_DIR, 'tool', 'exe_build', 'render_icon.ps1'),
        ),
        (
            _resource('template.apk'),
            os.path.join(SERVER_DIR, 'apps', 'template.apk'),
        ),
    ]
    for src, dst in files:
        if not os.path.isfile(src):
            return False
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        try:
            with open(src, 'rb') as f:
                data = f.read()
            if not (os.path.isfile(dst) and open(dst, 'rb').read() == data):
                with open(dst, 'wb') as f:
                    f.write(data)
        except Exception:
            return False
    return True


def _ensure_local_server():
    """تشغيل خادم بناء التطبيقات إن لم يكن يعمل — ثم الانتظار حتى جاهزيته."""
    try:
        if _ping_server():
            return
        if not _install_server_files():
            return
        python = _find_python()
        if not python:
            return
        script = os.path.join(SERVER_DIR, 'serve_all.py')
        log = open(os.path.join(SERVER_DIR, 'server.log'), 'ab')
        env = dict(os.environ)
        env.setdefault('PYTHONIOENCODING', 'utf-8')
        env.setdefault('PYTHONUTF8', '1')
        subprocess.Popen(
            [python, script],
            cwd=SERVER_DIR,
            env=env,
            stdout=log,
            stderr=log,
            stdin=subprocess.DEVNULL,
            creationflags=(
                getattr(subprocess, 'CREATE_NO_WINDOW', 0)
                | getattr(subprocess, 'CREATE_NEW_PROCESS_GROUP', 0)
            ),
            close_fds=True,
        )
        # انتظار الجاهزية (حتى 60 ثانية — إقلاع بايثون قد يكون بطيئاً بسبب
        # برامج الحماية) — لا يمنع فتح التطبيق أبداً
        for _ in range(60):
            if _ping_server():
                return
            time.sleep(1.0)
    except Exception:
        pass  # لا يمنع فتح التطبيق أبداً


def _setup_profile():
    """ضبط مجلد التنزيل الافتراضي لمتصفح التطبيق على adszuhair — قبل الفتح."""
    try:
        os.makedirs(DOWNLOAD_DIR, exist_ok=True)
        os.makedirs(PROFILE_DIR, exist_ok=True)
        prefs_path = os.path.join(PROFILE_DIR, 'Preferences')
        prefs = {}
        if os.path.isfile(prefs_path):
            try:
                with open(prefs_path, encoding='utf-8') as f:
                    prefs = json.load(f)
            except Exception:
                prefs = {}
        prefs.setdefault('download', {})['default_directory'] = DOWNLOAD_DIR
        prefs['download']['prompt_for_download'] = False
        prefs.setdefault('savefile', {})['default_directory'] = DOWNLOAD_DIR
        with open(prefs_path, 'w', encoding='utf-8') as f:
            json.dump(prefs, f)
    except Exception:
        pass  # لا يمنع فتح التطبيق أبداً

# معرّف النظام المضمّن وقت البناء للتطبيقات الديناميكية (الفروع).
# يُحقن داخل الـ EXE نفسه حتى يعمل التطبيق على أي جهاز بعد نسخه
# (بدون أي ملفات خارجية) — None لتطبيق الأدمن (يتعرّف عليه من اسمه).
EMBEDDED_MODE = None
EMBEDDED_NAME = None

# اسم النظام في الملف التنفيذي -> (معرف النظام sys, الاسم الظاهر)
SYSTEMS = {
    'النظام الأساسي': ('admin', 'النظام الأساسي (التحكم)'),
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


def _embedded_marker():
    """معرف النظام الملحق بذيل ملف الـ EXE (علامة @@ZSYS=...@@).

    التطبيقات المُصدَّرة من الويب (تنزيل من تطبيق الأدمن) تُلحق هذه
    العلامة بعد قالب المشغّل — قراءتها هنا تجعل التطبيق يفتح نظام
    الفرع الصحيح على أي جهاز دون أي ملفات خارجية.
    """
    try:
        with open(os.path.abspath(sys.executable), 'rb') as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            f.seek(max(0, size - 512))
            tail = f.read()
        m = re.search(rb'@@ZSYS=([^@]+)@@', tail)
        if m:
            mode = m.group(1).decode('utf-8', 'replace').strip()
            if mode:
                return mode
    except Exception:
        pass
    return None


def _find_mode():
    # 1) علامة مُلحقة بذيل الـ EXE (تصدير الويب من تطبيق الأدمن)
    marker = _embedded_marker()
    if marker:
        return marker, marker
    # 2) تطبيق فرع مضمّن: المعرف داخل الـ EXE نفسه — يعمل على أي جهاز فوراً
    if EMBEDDED_MODE:
        return EMBEDDED_MODE, (EMBEDDED_NAME or EMBEDDED_MODE)
    exe_base = os.path.splitext(os.path.basename(sys.executable))[0]
    # احتياط: ملف إعدادات بنفس الاسم بجانب التطبيق
    cfg = os.path.join(
        os.path.dirname(os.path.abspath(sys.executable)),
        exe_base + '.json',
    )
    if os.path.isfile(cfg):
        try:
            with open(cfg, encoding='utf-8') as f:
                data = json.load(f)
            mode = str(data.get('sys') or '').strip()
            if mode:
                return mode, str(data.get('name') or mode)
        except Exception:
            pass
    entry = SYSTEMS.get(exe_base)
    if entry is None:
        entry = SYSTEMS['النظام الأساسي']
    return entry


def main():
    mode, label = _find_mode()
    url = f'{HOST}/?v={APP_VERSION}&sys={mode}'
    # تطبيق الأدمن فقط: تشغيل خادم بناء تطبيقات الفروع محلياً (API) —
    # هو الذي يبني أيقونة باسم الفرع ويصدّر التطبيق إلى مجلد adszuhair.
    if mode == 'admin':
        _ensure_local_server()
    _setup_profile()
    browser = _find_browser()
    if browser:
        try:
            subprocess.Popen(
                [
                    browser,
                    f'--app={url}',
                    '--new-window',
                    f'--user-data-dir={PROFILE_DIR}',
                    '--no-first-run',
                    '--no-default-browser-check',
                ],
                close_fds=True,
            )
            return 0
        except Exception:
            pass
    # احتياط: فتح الرابط في المتصفح الافتراضي
    os.startfile(url)  # noqa: S606


if __name__ == '__main__':
    sys.exit(main())
