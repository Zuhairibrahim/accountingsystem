#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""حذف نهائي لكل أثر للفروع القديمة — نظافة 100% (يبقى الأدمن فقط).

يمسح بالكامل:
  1. accounting_audit_logs                        ← كل السجل (بداية نظيفة)
  2. accounting_systems/admin/stores/branches      ← صفوف جدول الفروع القديمة
  3. accounting_systems/admin/stores/branch_reports    ← تقارير الفروع المستلمة
  4. accounting_systems/admin/stores/attendance_reports← تقارير الحضور المستلمة
  5. تحقق نهائي: لا مستندات في أي منها + سجل الفروع والتقارير المشتركة فارغة
"""
import json
import sys
import time
import urllib.error
import urllib.request

PROJECT = 'accountingsystem-fc3f0'
API = 'https://firestore.googleapis.com/v1'
DOCS = f'{API}/{PROJECT}/databases/(default)/documents'

TARGETS = [
    'accounting_audit_logs',
    'accounting_systems/admin/stores/branches/records',
    'accounting_systems/admin/stores/branch_reports/records',
    'accounting_systems/admin/stores/attendance_reports/records',
]

VERIFY_EMPTY = TARGETS + [
    'accounting_branches',
    'accounting_eod_reports',
    'accounting_section_reports',
]


def _req(url, method='GET', tries=5):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, method=method)
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 503) and attempt < tries - 1:
                time.sleep(1.5 * (attempt + 1))
                continue
            if e.code == 404:
                return {}
            raise
    return {}


def list_doc_names(col_path):
    out, token = [], None
    while True:
        url = f'{DOCS}/{col_path}?pageSize=500'
        if token:
            url += f'&pageToken={token}'
        data = _req(url)
        out.extend(d['name'] for d in data.get('documents', []))
        token = data.get('nextPageToken')
        if not token:
            return out


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

    for col in TARGETS:
        names = list_doc_names(col)
        for n in names:
            _req(f'{API}/{n}', method='DELETE')
        print(f'[حذف] {col}: {len(names)} مستند', flush=True)

    print('', flush=True)
    print('== التحقق النهائي ==', flush=True)
    all_empty = True
    for col in VERIFY_EMPTY:
        left = len(list_doc_names(col))
        status = 'فارغة' if left == 0 else f'متبقي {left}!!'
        if left:
            all_empty = False
        print(f'  {col}: {status}', flush=True)
    print(
        'النتيجة: نظافة كاملة — لا يوجد أي أثر لأي فرع.'
        if all_empty else 'تحذير: أعِد التشغيل لبقايا متبقية.',
        flush=True,
    )
    return 0 if all_empty else 1


if __name__ == '__main__':
    sys.exit(main())
