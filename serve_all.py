"""تشغيل الأنظمة الخمسة بشكل احترافي (الخادم المحلي الموحّد).

- خدمة تطبيق الويب (Flutter build/web) على المنافذ:
    8080 -> النظام الأساسي (التحكم)   http://localhost:8080/?sys=admin
    8081 -> فرع صنعاء                  http://localhost:8081/?sys=branch1
    8082 -> فرع عدن                    http://localhost:8082/?sys=branch2
    8083 -> فرع تعز                    http://localhost:8083/?sys=branch3
    8084 -> فرع الحديدة                http://localhost:8084/?sys=branch4
- صندوق بريد محلي (Relay) حتى تصل تقارير الفروع للنظام الأساسي فوراً:
    POST /api/report    <- الفروع ترسل تقرير نهاية اليوم (JSON)
    GET  /api/reports   <- النظام الأساسي يستقبل التقارير تلقائياً
    GET  /api/ping      <- فحص جاهزية الخادم
- إنشاء تطبيق لفرع جديد تلقائياً على سطح المكتب عند إنشائه من الأدمن:
    POST /api/create_app <- ينشئ اختصار Windows (.lnk) يفتح هذا الفرع كتطبيق مستقل
"""
import json
import os
import re
import socketserver
import subprocess
import sys
import tempfile
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler

BUILD_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')
HOST = '0.0.0.0'
APPS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'apps')
RELAY_DIR = os.path.join(tempfile.gettempdir(), 'accounting_relay')

PORTS = {
    8080: 'النظام الأساسي',
    8081: 'فرع صنعاء',
    8082: 'فرع عدن',
    8083: 'فرع تعز',
    8084: 'فرع الحديدة',
}

os.makedirs(RELAY_DIR, exist_ok=True)

# تنظيف صندوق البريد عند كل إقلاع
for _f in os.listdir(RELAY_DIR):
    if _f.endswith('.json'):
        try:
            os.remove(os.path.join(RELAY_DIR, _f))
        except OSError:
            pass

try:
    WEB_ROOT = BUILD_DIR
except Exception:
    WEB_ROOT = os.getcwd()


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
            text=True,
        )
        path = out.strip()
        if path and os.path.isdir(path):
            return path
    except Exception:
        pass
    fallback = os.path.join(os.path.expanduser('~'), 'Desktop')
    return fallback if os.path.isdir(fallback) else os.path.expanduser('~')


def create_desktop_app(branch):
    """إنشاء اختصار (.lnk) لتطبيق فرع مستقل على سطح المكتب.

    branch: dict باسم/id/url الخاص بالفرع.
    يعيد (ok, message, path).
    """
    name = _safe_name(branch.get('name') or 'نظام جديد')
    app_url = str(branch.get('url') or '').strip()
    branch_id = str(branch.get('id') or '').strip()
    if not app_url:
        return False, 'لا يوجد رابط للفرع', None

    desktop = _desktop_path()
    shortcut = os.path.join(desktop, f'{name} — تطبيق.lnk')

    # مسار الخادم و launcher العام داخل apps/
    launcher = os.path.join(APPS_DIR, 'run_app.bat')
    if not os.path.isfile(launcher):
        return False, 'لم يُعثر على مشغّل التطبيقات (apps/run_app.bat)', None

    ps_script = (
        "$s=(New-Object -ComObject WScript.Shell).CreateShortcut("
        + json.dumps(shortcut, ensure_ascii=False)
        + ");"
        + "$s.TargetPath=" + json.dumps(launcher, ensure_ascii=False) + ';'
        + "$s.Arguments=" + json.dumps(app_url, ensure_ascii=False) + ';'
        + "$s.Description=" + json.dumps(f'نظام: {name}', ensure_ascii=False) + ';'
        + "$s.WorkingDirectory=" + json.dumps(APPS_DIR, ensure_ascii=False) + ';'
        + "$s.Save();"
    )
    try:
        subprocess.run(
            ['powershell', '-NoProfile', '-Command', ps_script],
            check=True,
            timeout=60,
        )
    except Exception as e:
        return False, f'تعذّر إنشاء الاختصار: {e}', None
    return True, f'تم إنشاء تطبيق «{name}» على سطح المكتب', shortcut


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

    def _json(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self._cors()
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header('Content-Length', '0')
        self.end_headers()

    def _is_system_server(self):
        # صندوق البريد وإنشاء التطبيقات يعملان فقط على خادم النظام الأساسي (8080)
        try:
            return self.server.server_address[1] == 8080
        except Exception:
            return False

    def do_GET(self):
        if not self._is_system_server():
            super().do_GET()
            return
        if self.path.startswith('/api/ping'):
            self._json(200, {'ok': True, 'app': 'accounting-system'})
            return
        if self.path.startswith('/api/reports'):
            reports = []
            try:
                for fn in sorted(os.listdir(RELAY_DIR)):
                    if not fn.endswith('.json'):
                        continue
                    with open(os.path.join(RELAY_DIR, fn), encoding='utf-8') as f:
                        reports.append(json.load(f))
            except Exception:
                pass
            self._json(200, reports)
            return
        if self.path.startswith('/api/'):
            self._json(404, {'ok': False, 'error': 'not found'})
            return
        super().do_GET()

    def do_POST(self):
        if not self._is_system_server():
            self._json(404, {'ok': False, 'error': 'not found'})
            return
        if self.path.startswith('/api/report'):
            length = int(self.headers.get('Content-Length', 0) or 0)
            raw = self.rfile.read(length).decode('utf-8')
            data = {}
            try:
                data = json.loads(raw)
            except Exception:
                pass
            code = str(data.get('branch_code') or 'BR??')
            date = str(data.get('report_date') or 'unknown').replace('/', '-')
            safe = ''.join(
                c for c in f'{code}_{date}' if c.isalnum() or c in '-_'
            )
            with open(
                os.path.join(RELAY_DIR, f'{safe}.json'), 'w', encoding='utf-8'
            ) as f:
                json.dump(data, f, ensure_ascii=False)
            self._json(200, {'ok': True})
            return
        if self.path.startswith('/api/create_app'):
            length = int(self.headers.get('Content-Length', 0) or 0)
            raw = self.rfile.read(length).decode('utf-8')
            branch = {}
            try:
                branch = json.loads(raw)
            except Exception:
                pass
            ok, msg, path = create_desktop_app(branch)
            self._json(200, {'ok': ok, 'message': msg, 'path': path})
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