# -*- coding: utf-8 -*-
"""مراقب حي لأخطاء التطبيق أثناء الاستخدام.

يراقب مجموعة `accounting_audit_logs` في Firestore كل 8 ثوانٍ ويطبع
أي عملية جديدة لحظة حدوثها مع تركيز خاص على أخطاء وقت التشغيل
(runtime_error) — كل خطأ يظهر هنا فوراً أثناء استخدام التطبيق
مع اسم النظام والوقت والتفاصيل.
"""
import json
import pathlib
import sys
import time
import urllib.request

PROJECT_ID = 'accountingsystem-fc3f0'
COLLECTION = 'accounting_audit_logs'
LOG_FILE = pathlib.Path(
    r'C:\Users\PC\AppData\Local\Temp\opencode\audit_watch.log'
)

# مفتاح API من إعدادات FlutterFire
_opts = pathlib.Path(
    r'E:\vip\accountingsystem\lib\core\firebase\firebase_options.dart'
).read_text(encoding='utf-8')
API_KEY = None
for _line in _opts.splitlines():
    if 'apiKey' in _line and "'" in _line:
        parts = _line.split("'")
        if len(parts) >= 3 and len(parts[-2]) > 20:
            API_KEY = parts[-2]
            break

if not API_KEY:
    print('[خطأ] لم يتم العثور على مفتاح Firebase API')
    sys.exit(1)


def fetch_docs():
    url = (
        f'https://firestore.googleapis.com/v1/projects/{PROJECT_ID}'
        f'/databases/(default)/documents/{COLLECTION}'
        f'?key={API_KEY}&pageSize=300'
    )
    try:
        with urllib.request.urlopen(url, timeout=15) as r:
            data = json.loads(r.read().decode())
        return data.get('documents', [])
    except Exception as e:
        print(f'[تحذير] تعذر الاتصال: {e}')
        return []


def doc_fields(doc):
    f = doc.get('fields', {})
    out = {}
    for k, v in f.items():
        for t in ('stringValue', 'integerValue', 'doubleValue'):
            if t in v:
                out[k] = v[t]
                break
    return out


def say(msg):
    print(msg, flush=True)
    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(msg + '\n')
    except Exception:
        pass


def main():
    seen = set()
    say('=' * 62)
    say('مراقب أخطاء النظام الحي — يعمل الآن')
    say('استخدم التطبيق بشكل طبيعي؛ أي خطأ يظهر هنا فوراً')
    say(f'ملف السجل: {LOG_FILE}')
    say('للإيقاف: أغلق نافذة المراقب')
    say('=' * 62)

    # التقاط الحالية بدون طبعتها (خط الأساس)
    for d in fetch_docs():
        seen.add(d['name'])

    while True:
        time.sleep(8)
        for d in fetch_docs():
            if d['name'] in seen:
                continue
            seen.add(d['name'])
            f = doc_fields(d)
            action = f.get('action', '?')
            is_error = action == 'runtime_error'
            mark = '!!! خطأ ' if is_error else '    عملية'
            stamp = f.get('time', '')[:19].replace('T', ' ')
            say(
                f'[{stamp}] {mark} | {f.get("action_label", action)}'
                f' | {f.get("system_name", "-")}'
                f' ({f.get("branch_code", "-")})'
                f' | {f.get("actor", "-")}'
            )
            if is_error:
                say(f'    التفاصيل: {f.get("details", "")[:300]}')
                say('-' * 62)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('\n[تم] أُوقف المراقب')
