# PROJECT_PLAN — نظام محاسبي متكامل (Flutter Web + IndexedDB)

> **المنصة**: Flutter Web تعمل داخل Google Chrome فقط
> **قاعدة البيانات**: IndexedDB محلية داخل المتصفح
> **اسم قاعدة البيانات**: `accounting_system`
> **التخزين**: Browser Local Storage / IndexedDB (بدون إنترنت)
> **Backend**: لا يوجد — كل شيء محلي

---

## 1. Architecture

```
UI (Widgets / Riverpod)
        │
        ▼
Presentation (Pages) — RTL, Desktop
        │
        ▼
State Management (Riverpod — Providers/Notifiers)
        │
        ▼
Repositories (منطق العمل)
        │
        ▼
Services (Accounting Engine, Journal, Ledger, Backup, Audit)
        │
        ▼
Database Access (LocalDatabase — IndexedDB عبر idb_shim)
        │
        ▼
IndexedDB (Store: accounting_system)
```

- **لا** يُوضع Business Logic داخل Widgets.
- كل صفحة تقرأ/تكتب من قاعدة البيانات عبر `Repository`.
- `AccountingEngine` يتولى توليد القيود والتحقق من `Debit == Credit`.

---

## 2. Folder Structure

```text
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── constants/
│   ├── database/
│   │   ├── local_database.dart
│   │   ├── database_schema.dart
│   │   ├── database_migrations.dart
│   │   ├── database_seed.dart
│   │   └── database_backup.dart
│   ├── accounting/
│   │   ├── accounting_engine.dart
│   │   ├── journal_service.dart
│   │   ├── ledger_service.dart
│   │   ├── trial_balance_service.dart
│   │   ├── profit_loss_service.dart
│   │   └── balance_sheet_service.dart
│   ├── models/
│   ├── repositories/
│   ├── services/
│   │   ├── audit_service.dart
│   │   ├── permission_service.dart
│   │   └── sequence_service.dart
│   ├── theme/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── dashboard/
│   ├── sales/
│   ├── purchases/
│   ├── customers/
│   ├── suppliers/
│   ├── products/
│   ├── inventory/
│   ├── accounts/
│   ├── journal/
│   ├── ledger/
│   ├── cash/
│   ├── banks/
│   ├── expenses/
│   ├── employees/
│   ├── reports/
│   └── settings/
```

---

## 3. Database Structure (IndexedDB — Store `accounting_system`)

كل "جدول" = Object Store داخل IndexedDB بمفتاح أساسي `id`.

| Store | الحقول الأساسية |
|-------|------------------|
| `company` | id, name, address, phone, currency |
| `users` | id, username, password_hash, full_name, role, is_active |
| `roles` | id, name |
| `permissions` | id, role_id, action |
| `accounts` | id, code, name, parent_id, type, normal_side, is_active |
| `account_groups` | id, name, parent_id |
| `cost_centers` | id, name |
| `customers` | id, code, name, phone, address, balance, credit_limit, is_active, account_id |
| `suppliers` | id, code, name, phone, address, balance, account_id |
| `products` | id, sku, barcode, name, category_id, unit_id, cost_price, sale_price, min_stock, tax_pct, is_active |
| `product_categories` | id, name |
| `units` | id, name |
| `warehouses` | id, name |
| `stock` | id, product_id, warehouse_id, quantity |
| `stock_movements` | id, product_id, warehouse_id, type, qty, reference, date |
| `sales` | id, invoice_no, date, customer_id, warehouse_id, subtotal, discount, tax, total, paid, remaining, status, journal_id |
| `sales_items` | id, sale_id, product_id, qty, price, total |
| `purchases` | id, invoice_no, date, supplier_id, subtotal, discount, tax, total, paid, remaining, status, journal_id |
| `purchase_items` | id, purchase_id, product_id, qty, price, total |
| `journal_entries` | id, entry_no, date, description, reference, status, created_by |
| `journal_lines` | id, journal_entry_id, account_id, debit, credit |
| `cash_accounts` | id, name, balance, account_id |
| `cash_transactions` | id, cash_account_id, type, amount, description, reference, date |
| `bank_accounts` | id, name, iban, bank_name, currency, balance, account_id |
| `bank_transactions` | id, bank_account_id, type, amount, description, reference, date |
| `expenses` | id, expense_no, date, account_id, amount, payment_type, description |
| `receipts` | id, receipt_no, date, customer_id, amount, cash_id, bank_id, description |
| `payments` | id, payment_no, date, supplier_id, amount, cash_id, bank_id, description |
| `employees` | id, name, phone, base_salary, allowances, deductions, net_salary |
| `salary_records` | id, employee_id, month, year, base_salary, allowances, deductions, net |
| `taxes` | id, name, rate, is_active |
| `fiscal_years` | id, name, start_date, end_date, is_open |
| `accounting_periods` | id, name, start_date, end_date, is_open |
| `audit_logs` | id, user_id, action, entity, entity_id, old_value, new_value, date |
| `settings` | key, value |
| `backup_metadata` | id, version, created_at |

العلاقات تتم عبر مفاتيح أجنبية منطقية (Foreign Key IDs) لا تُفرض قسرياً في IndexedDB.

---

## 4. Modules

- Dashboard / لوحة التحكم
- Sales / المبيعات (+ فواتير + مرتجعات)
- Purchases / المشتريات
- Customers / العملاء
- Suppliers / الموردون
- Products / المنتجات
- Inventory / المخزون (مستودعات + حركة)
- Accounts / شجرة الحسابات
- Journal / القيود اليومية
- Ledger / دفتر الأستاذ
- Cash / الصندوق
- Banks / البنوك
- Expenses / المصروفات
- Employees / الموظفون والرواتب
- Reports / التقارير
- Settings / الإعدادات

---

## 5. Accounting Logic

- مبدأ **القيد المزدوج**: كل عملية تُنتج سطرين+ في `journal_lines`.
- **شرط إلزامي**: `SUM(debit) == SUM(credit)` وإلا لا تُعتمد العملية.
- مصدر الحقيقة المحاسبية = القيود (`journal_entries` + `journal_lines`).
- لا تُعدّل الأرصدة يدوياً؛ تُستخرج من القيود.
- اعتماد فاتورة بيع يُنشئ:
  1. قيد المبيعات (صندوق/عميل ← مبيعات)
  2. قيد تكلفة المبيعات (تكلفة المبيعات ← مخزون)
  3. حركة مخزون (نقص)
- اعتماد فاتورة شراء يُنشئ:
  1. قيد الشراء (مخزون ← مورد/صندوق)
  2. حركة مخزون (زيادة)

---

## 6. Navigation

- **go_router** مع `ShellRoute` لتعليق الـ Sidebar.
- قائمة ثابتة على اليسار في Desktop.
- المسارات المسماة لكل وحدة (e.g. `/sales`, `/accounts`).

---

## 7. State Management

- **Riverpod** (`flutter_riverpod` / `hooks_riverpod`).
- `Provider` لكل Repository.
- `AsyncNotifierProvider` / `NotifierProvider` لكل صفحة رئيسية.
- `SessionProvider` لجلسة المستخدم الحالية.
- فصل كامل: UI / State / Repository / Database.

---

## 8. Backup/Restore Strategy

- **Export**: قراءة كل الـ Object Stores وتجميعها في JSON واحد.
  - `accounting_backup_2026-09-04.json` содержит `{version, exported_at, data: {store: [rows]}}`.
- **Import**: التحقق من بنية الملف (version + data) قبل الكتابة.
  - مسح قاعدة البيانات الحالية ثم إعادة إدراج البيانات.
- ميزة حساسة لأن البيانات داخل متصفح واحد فقط.

---

## 9. Validation Rules

- القيد يجب أن يكون متوازناً (مدين == دائن).
- الفاتورة: لا يمكن اعتماد فاتورة بدون بنود.
- لا يمكن بيع كمية أكبر من المتوفر في المستودع (تحذير/منع).
- لا يمكن حذف حساب له حركة محاسبية.
- كلمة مرور تُخزّن كـ Hash.
- الصلاحيات تُفحص قبل كل إجراء حساس.

---

## 10. مراحل التنفيذ

1. الفحص + الخطة ✅
2. تحويل المشروع إلى Flutter Web
3. قاعدة بيانات IndexedDB (schema + seed + backup)
4. المحرك المحاسبي (engine + services)
5. شجرة الحسابات
6. العملاء + الموردون
7. المنتجات والمخزون
8. المبيعات + المشتريات (بالقيود)
9. الصندوق + البنوك + المصروفات
10. القيود + الأستاذ + الميزان + الأرباح والخسائر + الميزانية العمومية
11. الموظفون والرواتب + Dashboard
12. التصميم Sidebar + الصلاحيات + Audit + الطباعة
13. الاختبارات: analyze + test + build web
