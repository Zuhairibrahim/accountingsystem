"""تشغيل النظام الأساسي + إنشاء تطبيقات الفروع الجديدة تلقائياً.

كل البيانات سحابية 100% عبر Firebase — هذا الخادم لا يخزن أي بيانات:
- خدمة تطبيق الويب (Flutter build/web) للنظام الأساسي فقط:
    8080 -> النظام الأساسي (التحكم)   http://localhost:8080/?sys=admin
    (كل الفروع تعمل عبر السحابة — Firebase — من أي مكان)
- الجزء المحلي الوحيد: تصدير تطبيق مستقل (EXE) لأي فرع جديد تلقائياً
  داخل مجلد المسؤول عند إنشائه من الأدمن (بناء بالخلفية مع تتبع التقدم):
    POST /api/create_app          <- بدء الإنشاء (يعيد build_id فوراً)
    GET  /api/build_status?id=..  <- حالة البناء الحية (step/done/ok/path)
                                    (واحتياطياً اختصار .lnk / ملف .url)
    GET  /api/ping                <- فحص جاهزية الخادم
"""
import json
import os
import re
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading
import uuid
from http.server import HTTPServer, SimpleHTTPRequestHandler

BUILD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')
HOST = '0.0.0.0'
APPS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'apps')
LAUNCHER_PY = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    'tool', 'exe_build', 'launcher.py',
)
BRANCH_BUILD_DIR = os.path.join(tempfile.gettempdir(), 'opencode', 'branch_build')

# النظام الأساسي فقط — كل الفروع (حتى 50) عبر السحابة من أي مكان.
PORTS = {
    8080: 'النظام الأساسي',
}

RENDER_PS1 = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    'tool', 'exe_build', 'render_icon.ps1',
)

# لوحة ألوان تُستخدم تلقائياً لأيقونة كل فرع جديد حسب رقم المعرّف
PALETTES = [
    ('#0EA5E9', '#0C4A6E'),
    ('#10B981', '#064E3B'),
    ('#F472B6', '#831843'),
    ('#A78BFA', '#4C1D95'),
    ('#14B8A6', '#134E4A'),
    ('#F59E0B', '#92400E'),
    ('#EF4444', '#7F1D1D'),
    ('#3B82F6', '#1E3A8A'),
    ('#84CC16', '#365314'),
    ('#06B6D4', '#164E63'),
]

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

WEB_ROOT = BUILD_DIR if os.path.isdir(BUILD_DIR) else os.getcwd()

# ==================== سجل عمليات البناء (تقدم حي) ====================
# BUILDS: build_id -> {id, sys_id, done, ok, message, path, step, started}
BUILDS = {}
BUILDS_LOCK = threading.Lock()
BUILD_SEMAPHORE = threading.Semaphore(1)  # بناء واحد في كل مرة (تسريع الكاش)


def _set_build(build_id, **fields):
    with BUILDS_LOCK:
        b = BUILDS.get(build_id)
        if b is not None:
            b.update(fields)


def _set_step(build_id, step):
    _set_build(build_id, step=step)


# ==================== أدوات مساعدة ====================

def _safe_name(text):
    """اسم آمن للملفات من أي نص (يدعم العربية)."""
    text = re.sub(r'[\\/:*?"<>|]+', '_', str(text)).strip()
    return text or 'system'


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


_ADMIN_DIR_CACHE = None
_ADMIN_DIR_LOCK = threading.Lock()


def _admin_dir():
    """مجلد المسؤول على سطح المكتب الحقيقي (يُنشأ تلقائياً عند أول استخدام)."""
    global _ADMIN_DIR_CACHE
    with _ADMIN_DIR_LOCK:
        if _ADMIN_DIR_CACHE is None:
            _ADMIN_DIR_CACHE = os.path.join(_desktop_path(), 'admin')
        os.makedirs(_ADMIN_DIR_CACHE, exist_ok=True)
        return _ADMIN_DIR_CACHE


def _icon_dir():
    d = os.path.join(_admin_dir(), 'icons')
    os.makedirs(d, exist_ok=True)
    return d


def _branch_number(sys_id):
    m = re.search(r'(\d+)$', str(sys_id))
    return int(m.group(1)) if m else 90


def _find_browser():
    for path in CHROME_CANDIDATES + EDGE_CANDIDATES:
        if path and os.path.isfile(path):
            return path
    for cand in ('chrome', 'msedge'):
        try:
            out = subprocess.check_output(
                ['where', cand], shell=True, text=True,
                stderr=subprocess.STDOUT,
            )
            return out.strip().splitlines()[0].strip()
        except Exception:
            continue
    return None


def _render_branch_icon(name, code, sys_id):
    """توليد أيقونة مخصصة لاسم الفرع الجديد (تُحفظ في مجلد المسؤول/icons)."""
    try:
        number = _branch_number(sys_id)
        c1, c2 = PALETTES[(number - 1) % len(PALETTES)]
        icon_dir = _icon_dir()  # قبل كتابة الملف — لا يفشل أول إنشاء
        meta = os.path.join(icon_dir, f'{sys_id}_meta.txt')
        with open(meta, 'w', encoding='utf-8') as f:
            f.write('\n'.join((name, 'النظام المحاسبي', code, 'branch', c1, c2)) + '\n')
        if os.path.isfile(RENDER_PS1):
            subprocess.run(
                [
                    'powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                    '-File', RENDER_PS1, '-MetaPath', meta,
                    '-OutBase', os.path.join(icon_dir, sys_id),
                ],
                check=True, timeout=90,
            )
        icon = os.path.join(icon_dir, f'{sys_id}.ico')
        return icon if os.path.isfile(icon) else None
    except Exception:
        return None


def _build_branch_exe(name, code, sys_id, icon, build_id=None):
    """بناء تطبيق مستقل (EXE) مكتفٍ ذاتياً للفرع الجديد بأيقونته المخصصة.

    يُضمَّن معرف النظام داخل الـ EXE نفسه (بدون أي ملفات خارجية) حتى يعمل
    التطبيق فور فتحه على أي جهاز بعد نسخه (لابتوب الموظف) ويفتح رابط
    السحابة الخاص بالفرع مباشرة — كل البيانات عبر Firebase.
    يعيد مسار الـ EXE أو None عند الفشل.
    """
    try:
        with BUILD_SEMAPHORE:  # بناء واحد في كل مرة (إعادة استخدام كاش PyInstaller)
            os.makedirs(BRANCH_BUILD_DIR, exist_ok=True)
            # نسخ المشغّل العام إلى مجلد البناء حتى يُضمَّن داخل التطبيق
            shutil.copyfile(
                LAUNCHER_PY,
                os.path.join(BRANCH_BUILD_DIR, 'launcher.py'),
            )
            # سكربت الدخول: يحقن معرف الفرع واسمه داخل التطبيق ثم يشغّله
            entry = os.path.join(BRANCH_BUILD_DIR, f'entry_{sys_id}.py')
            with open(entry, 'w', encoding='utf-8') as f:
                f.write('# -*- coding: utf-8 -*-\n')
                f.write('import launcher\n')
                f.write('launcher.EMBEDDED_MODE = ' + repr(sys_id) + '\n')
                f.write('launcher.EMBEDDED_NAME = ' + repr(name) + '\n')
                f.write('launcher.main()\n')
            exe_name = f'app_{sys_id}'
            cmd = [
                sys.executable, '-m', 'PyInstaller',
                '--onefile', '--windowed',
                '--name', exe_name,
                '--noconfirm',
                '--distpath', BRANCH_BUILD_DIR,
                '--workpath', os.path.join(BRANCH_BUILD_DIR, 'work'),
                '--specpath', BRANCH_BUILD_DIR,
                entry,
            ]
            if icon:
                cmd.insert(4, '--icon')
                cmd.insert(5, icon)
            subprocess.run(cmd, check=True, timeout=300)
            built = os.path.join(BRANCH_BUILD_DIR, exe_name + '.exe')
            if not os.path.isfile(built):
                return None
            if build_id:
                _set_step(build_id, 'نسخ التطبيق إلى مجلد المسؤول')
            target = os.path.join(_admin_dir(), f'{name}.exe')
            shutil.copyfile(built, target)
            return target
    except Exception:
        return None


def _make_shortcut(admin_dir, name, app_url, icon):
    """احتياط عند تعذّر بناء الـ EXE: اختصار .lnk بنفس الأيقونة (أو .url)."""
    browser = _find_browser()
    if browser:
        try:
            shortcut = os.path.join(admin_dir, f'{name}.lnk')
            icon_location = (icon or browser + ',0').replace('/', '\\')
            ps_script = (
                "$s=(New-Object -ComObject WScript.Shell).CreateShortcut("
                + json.dumps(shortcut, ensure_ascii=False)
                + ');'
                + "$s.TargetPath=" + json.dumps(browser, ensure_ascii=False) + ';'
                + "$s.Arguments=" + json.dumps(f'--app={app_url} --new-window', ensure_ascii=False) + ';'
                + "$s.Description=" + json.dumps(f'النظام المحاسبي — {name}', ensure_ascii=False) + ';'
                + "$s.IconLocation=" + json.dumps(icon_location, ensure_ascii=False) + ';'
                + "$s.Save();"
            )
            subprocess.run(
                ['powershell', '-NoProfile', '-Command', ps_script],
                check=True, timeout=60,
            )
            if os.path.isfile(shortcut):
                return shortcut
        except Exception:
            pass
    shortcut = os.path.join(admin_dir, f'{name}.url')
    try:
        with open(shortcut, 'w', encoding='utf-8') as f:
            f.write('[InternetShortcut]\r\nURL=' + app_url + '\r\n')
        return shortcut
    except Exception:
        return None


def _write_credentials_note(admin_dir, name, code, username, password, app_url):
    """ملف «بيانات الدخول» باسم المستخدم وكلمة السر والرابط."""
    try:
        note = os.path.join(admin_dir, f'{name} — بيانات الدخول.txt')
        with open(note, 'w', encoding='utf-8') as f:
            f.write('\n'.join([
                'النظام المحاسبي — فرع جديد',
                '===========================',
                'اسم الفرع: ' + name,
                'كود الفرع: ' + code,
                'اسم المستخدم: ' + username,
                'كلمة السر: ' + password,
                'رابط الدخول: ' + app_url,
                '',
                'التطبيق مستقل تماماً: انسخه إلى جهاز الموظف وافتحه —',
                'يفتح نظام الفرع مباشرة وكل البيانات عبر السحابة (Firebase).',
            ]) + '\n')
    except Exception:
        pass


# ==================== إنشاء تطبيق الفرع (في الخلفية) ====================

def start_desktop_app_build(branch):
    """بدء إنشاء تطبيق فرع في الخلفية وإرجاع (build_id, started).

    إن كان هناك بناء جارٍ لنفس الفرع يعيد معرّفه نفسه دون إعادة التشغيل.
    """
    sys_id = str(branch.get('id') or '').strip() or 'branch?'
    with BUILDS_LOCK:
        for b in BUILDS.values():
            if b.get('sys_id') == sys_id and not b.get('done'):
                return b['id'], False
        build_id = uuid.uuid4().hex[:12]
        BUILDS[build_id] = {
            'id': build_id,
            'sys_id': sys_id,
            'done': False,
            'ok': False,
            'message': '',
            'path': None,
            'step': 'بدء الإنشاء',
        }
    threading.Thread(
        target=_run_desktop_app_build,
        args=(build_id, branch),
        daemon=True,
    ).start()
    return build_id, True


def _run_desktop_app_build(build_id, branch):
    """منفّذ البناء في الخلفية: يحدّث الخطوات ويضمن نتيجة نهائية دائماً."""
    try:
        ok, msg, path = _create_desktop_app(branch, build_id)
        _set_build(build_id, done=True, ok=ok, message=msg, path=path,
                   step='اكتمل')
    except Exception as exc:  # لا يترك الطلب معلقاً أبداً
        _set_build(build_id, done=True, ok=False,
                   message=f'فشل غير متوقع أثناء الإنشاء: {exc}',
                   step='فشل')


def _create_desktop_app(branch, build_id):
    """إنشاء تطبيق فرع مستقل تلقائياً داخل مجلد المسؤول على سطح المكتب.

    branch: dict باسم/id/كود/رابط/اسم مستخدم/كلمة سر الخاص بالفرع.
    الخطوات:
    - أيقونة مخصصة تحمل اسم الفرع وكوده (render_icon.ps1).
    - تطبيق EXE مستقل بالأيقونة يفتح رابط السحابة على أي جهاز (PyInstaller).
    - احتياطاً عند تعذّر البناء: اختصار .lnk / ملف .url.
    - ملف «بيانات الدخول» باسم المستخدم وكلمة السر والرابط.
    يعيد (ok, message, path).
    """
    name = _safe_name(branch.get('name') or 'نظام جديد')
    app_url = str(branch.get('url') or '').strip()
    sys_id = str(branch.get('id') or '').strip()
    code = str(branch.get('code') or '').strip() or 'BR--'
    username = str(branch.get('username') or '').strip()
    password = str(branch.get('password') or '').strip()
    if not app_url:
        return False, 'لا يوجد رابط للفرع', None

    admin_dir = _admin_dir()

    # 1) أيقونة مخصصة تحمل اسم الفرع وكوده
    _set_step(build_id, f'توليد أيقونة الفرع «{name}»')
    icon = _render_branch_icon(name, code, sys_id)

    # 2) تطبيق EXE مستقل بأيقونة الفرع — يعمل على أي جهاز بعد نسخه
    _set_step(build_id, f'بناء تطبيق «{name}» التنفيذي (EXE)')
    exe = _build_branch_exe(name, code, sys_id, icon, build_id)

    # 3) احتياط عند تعذّر البناء: اختصار بنفس الأيقونة
    result = exe
    if not result:
        _set_step(build_id, 'تعذّر بناء EXE — إنشاء اختصار احتياطي')
        result = _make_shortcut(admin_dir, name, app_url, icon)

    # 4) ملف بيانات الدخول
    _write_credentials_note(admin_dir, name, code, username, password, app_url)

    if result:
        kind = 'تطبيق EXE' if exe else 'اختصار'
        return True, f'تم إنشاء {kind} «{name}» في مجلد المسؤول', result
    return False, f'تعذّر إنشاء التطبيق والاختصار لـ«{name}»', None


class ThreadingHTTPServer(socketserver.ThreadingMixIn, HTTPServer):
    daemon_threads = True


class SPAHandler(SimpleHTTPRequestHandler):
    """خادم ملفات ثابتة + صندوق بريد + إنشاء تطبيقات سطح المكتب."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_ROOT, **kwargs)

    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        # ضروري: يسمح للتطبيق السحابي (https) بالوصول للخادم المحلي
        # (localhost) — بدونه يحجب المتصفح الطلب (Private Network Access)
        self.send_header('Access-Control-Allow-Private-Network', 'true')

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header('Content-Length', '0')
        self.end_headers()

    def _is_system_server(self):
        # الوظائف الخاصة تعمل فقط على خادم النظام الأساسي (8080)
        try:
            return self.server.server_address[1] == 8080
        except Exception:
            return False

    def _json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self._cors()
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if not self._is_system_server():
            super().do_GET()
            return
        if self.path.startswith('/api/ping'):
            self._json(200, {'ok': True, 'app': 'accounting-system'})
            return
        if self.path.startswith('/api/build_status'):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            build_id = (qs.get('id') or [''])[0]
            with BUILDS_LOCK:
                b = BUILDS.get(build_id)
                snap = dict(b) if b else None
            if snap is None:
                self._json(200, {
                    'done': True, 'ok': False, 'step': 'غير معروف',
                    'message': 'لا توجد عملية إنشاء بهذا المعرف '
                               '(ربما أُعيد تشغيل الخادم)',
                })
            else:
                self._json(200, snap)
            return
        if self.path.startswith('/api/'):
            self._json(404, {'ok': False, 'error': 'not found'})
            return
        super().do_GET()

    def _read_body_json(self):
        length = int(self.headers.get('Content-Length', 0) or 0)
        raw = self.rfile.read(length).decode('utf-8') if length else ''
        try:
            return json.loads(raw) if raw else {}
        except Exception:
            return {}

    def do_POST(self):
        if not self._is_system_server():
            self._json(404, {'ok': False, 'error': 'not found'})
            return
        if self.path.startswith('/api/create_app'):
            branch = self._read_body_json()
            if not str(branch.get('name') or '').strip():
                self._json(200, {'ok': False,
                                 'message': 'اسم الفرع مفقود في الطلب'})
                return
            build_id, _started = start_desktop_app_build(branch)
            self._json(200, {
                'ok': True,
                'build_id': build_id,
                'message': 'بدأ إنشاء التطبيق في الخلفية',
            })
            return
        self._json(404, {'ok': False, 'error': 'not found'})

    def log_message(self, fmt, *args):
        try:
            print('[%s] %s' % (self.server.server_address[1], fmt % args), flush=True)
        except Exception:
            pass


def start_server(port, name):
    print('بالتشغيل: %s -> http://localhost:%d/' % (name, port), flush=True)
    with ThreadingHTTPServer((HOST, port), SPAHandler) as httpd:
        httpd.serve_forever()


if __name__ == '__main__':
    if not os.path.isdir(BUILD_DIR):
        print('Build directory not found: %s' % BUILD_DIR)
        sys.exit(1)

    threads = []
    for port, name in PORTS.items():
        t = threading.Thread(target=start_server, args=(port, name), daemon=True)
        t.start()
        threads.append(t)

    print('=' * 52)
    print('       جميع الأنظمة تعمل — تفضل بالفتح')
    print('=' * 52)
    for port, name in PORTS.items():
        print('  %-20s http://localhost:%d/' % (name, port))
    print('=' * 52)
    print('  أبقِ هذه النافذة مفتوحة أثناء العمل.')
    print('  للإيقاف: أغلق النافذة أو اضغط Ctrl+C')

    try:
        while True:
            pass
    except KeyboardInterrupt:
        print('\nجاري إيقاف جميع الأنظمة...')
