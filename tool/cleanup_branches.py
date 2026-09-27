#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""تنظيف شامل لكل بقايا الفروع السابقة من السحابة (Firestore) — REST.

يحذف بالكامل ويُبقي نظام الأدمن (admin / BR00) فقط:
  1. accounting_branches            ← سجل الفروع
  2. accounting_systems/{غير admin}  ← شجرة كل فرع (records/stores/counters)
  3. accounting_eod_reports         ← تقارير نهاية يوم الفروع (غير BR00)
  4. accounting_section_reports     ← تقارير أقسام الفروع (غير BR00)
  5. accounting_audit_logs          ← عمليات الفروع (غير admin)

ملاحظة: listCollectionIds محجوب بدون توثيق، لذا يُستخدم مخطط المخازن
الثابت من الكود (AppConstants.allStores عبر stores/counters).
"""
import json
import sys
import time
import urllib.error
import urllib.request

PROJECT = 'accountingsystem-fc3f0'
ROOT = f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
DOCS = f'{ROOT}/databases/(default)/documents'

STORES = [
    'company', 'users', 'roles', 'permissions', 'customers', 'suppliers',
    'products', 'product_categories', 'units', 'branches', 'warehouses',
    'stock', 'stock_movements', 'sales', 'sale_items', 'purchases',
    'purchase_items', 'cash_accounts', 'cash_transactions', 'bank_accounts',
    'bank_transactions', 'expenses', 'receipts', 'payments', 'employees',
    'salary_records', 'attendance', 'taxes', 'fiscal_years',
    'accounting_periods', 'audit_logs', 'settings', 'backup_metadata',
    'branch_reports', 'attendance_reports',
]

CANDIDATE_IDS = [
    *(f'branch{i}' for i in range(1, 21)),
    *(f'v{i}' for i in range(1, 21)),
]

deleted = {'docs': 0}


def _req(url, method='GET', tries=4):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, method=method)
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 503) and attempt < tries - 1:
                time.sleep(1.2 * (attempt + 1))
                continue
            raise
    return {}


def _delete(url):
    """حذف مع تجاهل 404 (المستند غير موجود أصلاً)."""
    try:
        _req(url, method='DELETE')
        deleted['docs'] += 1
        return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise


def list_docs(col_path):
    out, token = [], None
    while True:
        url = f'{DOCS}/{col_path}?pageSize=500'
        if token:
            url += f'&pageToken={token}'
        data = _req(url)
        for d in data.get('documents', []):
            out.append((d['name'], d))
        token = data.get('nextPageToken')
        if not token:
            return out


def field(doc, key):
    v = doc.get('fields', {}).get(key, {})
    return v.get('stringValue') or v.get('integerValue') or ''


def wipe_system_tree(sys_id):
    """حذف شجرة فرع كاملة بالمخطط الثابت: records ← store ← counter ← جذر."""
    n = 0
    for store in STORES:
        base = f'accounting_systems/{sys_id}'
        for name, _doc in list_docs(f'{base}/stores/{store}/records'):
            _delete(f'{ROOT}/{name}')
            n += 1
        if _delete(f'{DOCS}/{base}/stores/{store}'):
            n += 1
        if _delete(f'{DOCS}/{base}/counters/{store}'):
            n += 1
    if _delete(f'{DOCS}/accounting_systems/{sys_id}'):
        n += 1
    return n


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

    # 1) سجل الفروع
    names = list_docs('accounting_branches')
    for name, _ in names:
        _delete(f'{ROOT}/{name}')
    print(f'[1/5] سجل الفروع: حُذف {len(names)} مستند', flush=True)

    # 2) أشجار الفروع (حقيقية وأشباح) — إبقاء admin فقط
    total = 0
    for sys_id in CANDIDATE_IDS:
        total += wipe_system_tree(sys_id)
    print(f'[2/5] أشجار الفروع ({len(CANDIDATE_IDS)} معرفاً): حُذف {total} عنصر', flush=True)

    # 3+4) التقارير المشتركة (إبقاء BR00)
    for label, col in (
        ('تقارير نهاية اليوم', 'accounting_eod_reports'),
        ('تقارير الأقسام', 'accounting_section_reports'),
    ):
        keep = gone = 0
        for name, doc in list_docs(col):
            if field(doc, 'branch_code') == 'BR00':
                keep += 1
            else:
                _delete(f'{ROOT}/{name}')
                gone += 1
        print(f'[3/5] {label}: حُذف {gone} — أُبقي {keep} (BR00)', flush=True)

    # 5) سجل العمليات (إبقاء admin)
    keep = gone = 0
    for name, doc in list_docs('accounting_audit_logs'):
        if field(doc, 'system_id') == 'admin':
            keep += 1
        else:
            _delete(f'{ROOT}/{name}')
            gone += 1
    print(f'[4/5] سجل العمليات: حُذف {gone} — أُبقي {keep} (admin)', flush=True)

    # تحقق
    left_systems = [n.rsplit('/', 1)[-1] for n, _ in list_docs('accounting_systems')]
    left_registry = len(list_docs('accounting_branches'))
    print(
        f'[5/5] تحقق: أنظمة ظاهرة {left_systems} | سجل الفروع {left_registry} '
        f'| إجمالي المحذوف {deleted["docs"]}',
        flush=True,
    )
    print('اكتمل التنظيف عبر REST.', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
