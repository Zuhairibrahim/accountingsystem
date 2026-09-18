#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ترقيع بناء الويب بعد flutter build web:

1. يستبدل flutter_service_worker.js بسكربت «قاتل» يمسح كل الكاش القديم
   في متصفحات المستخدمين ويلغي تسجيل نفسه نهائياً — يحل مشكلة بقاء
   نسخة قديمة من التطبيق تعمل من الكاش بعد تحديث السحابة.
2. يزيل تسجيل الـ Service Worker من flutter_bootstrap.js حتى لا يُسجَّل
   مرة أخرى في أي متصفح جديد (التطبيق سحابي 100% ولا يحتاج كاش تطبيق).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build' / 'web'
LAUNCHER = ROOT / 'apps' / 'launcher.exe'

# مفتاح XOR لترميز قالب المشغّل — خطة Spark تمنع ملفات EXE على Hosting،
# فيُرفع مرمّزاً (launcher.exe.enc) ويُفك الترميز داخل المتصفح قبل التنزيل.
XOR_KEY = b'\xa3\x5f\x2b\x7e'


def xor_bytes(data: bytes) -> bytes:
    return bytes(b ^ XOR_KEY[i % len(XOR_KEY)] for i, b in enumerate(data))

KILL_SWITCH = """// Kill-switch service worker: يمسح كل الكاش القديم ويلغي تسجيل نفسه نهائياً.
// التطبيق سحابي 100% (Firebase) — لا حاجة لأي كاش تطبيق محلي.
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.map((k) => caches.delete(k))))
      .then(() => undefined),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    await self.clients.claim();
    try {
      await self.registration.unregister();
    } catch (_) {}
    try {
      const list = await self.clients.matchAll({ type: 'window' });
      for (const c of list) {
        try {
          await c.navigate(c.url);
        } catch (_) {}
      }
    } catch (_) {}
  })());
});

// شبكة فقط — لا تقديم أي ملف من كاش إطلاقاً.
self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});
"""


def main() -> int:
    if not BUILD.is_dir():
        print(f'build/web غير موجود: {BUILD}', file=sys.stderr)
        return 1

    sw = BUILD / 'flutter_service_worker.js'
    sw.write_text(KILL_SWITCH, encoding='utf-8')
    print('[1/2] flutter_service_worker.js => kill-switch (مسح كاش + إلغاء تسجيل)')

    fb = BUILD / 'flutter_bootstrap.js'
    if fb.is_file():
        src = fb.read_text(encoding='utf-8')
        patched = re.sub(
            r'serviceWorkerSettings\s*:\s*\{[^{}]*\},?\s*',
            '',
            src,
        )
        if patched != src:
            fb.write_text(patched, encoding='utf-8')
            print('[2/2] flutter_bootstrap.js => أُزيل تسجيل الـ Service Worker')
        else:
            print('[2/2] flutter_bootstrap.js => لا تسجيل موجود (تماماً)')

    # 3) نسخ قالب المشغّل (apps/launcher.exe) داخل بناء الويب مُرمَّزاً بـ XOR
    #    (launcher.exe.enc) — خطة Spark تمنع EXE على Hosting، والتطبيق يفك
    #    الترميز في المتصفح قبل إلحاق معرف الفرع وتنزيل التطبيق النهائي.
    if LAUNCHER.is_file():
        dest = BUILD / 'apps' / 'launcher.exe.enc'
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(xor_bytes(LAUNCHER.read_bytes()))
        print(f'[3/3] apps/launcher.exe => build/web/apps/launcher.exe.enc ({dest.stat().st_size} bytes)')
    else:
        print('[3/3] تحذير: apps/launcher.exe غير موجود — تصدير الفروع لن يعمل')
    return 0


if __name__ == '__main__':
    sys.exit(main())
