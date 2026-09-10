# وثيقة المشروع — النظام المحاسبي المتكامل

> **النظام**: نظام محاسبي متكامل (Integrative Accounting System)
> **المنصة**: Flutter (تطبيق محمول + Desktop)
> **قاعدة البيانات**: محلية داخل المشروع — SQLite عبر حزمة `sqflite` (مع إمكانية الانتقال إلى `drift` لاحقاً)
> **الهدف**: نظام احترافي قابل للتعميم على المحلات والشركات، بدون الحاجة لخادم خارجي

---

## 1. فكرة النظام

نظام محاسبي متكامل يعمل محلياً على الجهاز (بياناته في ملف SQLite داخل المشروع)، يغطي الدورة المحاسبية كاملة:

- شجرة الحسابات + القيد المزدوج
- المبيعات والمشتريات والفواتير والمرتجعات
- العملاء والموردون وكشوف الحساب
- المخزون والمستودعات
- الصناديق والبنوك وسندات القبض والصرف
- المصروفات والإيرادات
- التقارير المالية (دفتر اليومية، الأستاذ، ميزان المراجعة، الدخل، الميزانية العمومية)
- تقارير تجارية (المبيعات، المشتريات، الأرباح، المصروفات، المخزون)
- المستخدمون والصلاحيات + سجل العمليات (Audit Log)

---

## 2. أنواع المستخدمين والصلاحيات

| الدور | الصلاحيات |
|-------|-----------|
| **المدير (Admin)** | كل شيء: القيود، الفواتير، الإعدادات، حذف الشركة، المستخدمون |
| **المحاسب** | القيود، الفواتير، العملاء، الموردون، التقارير — بدون الإعدادات وحذف البيانات |
| **موظف المبيعات** | إنشاء فاتورة، العملاء، المدفوعات — بدون القيود المالية والتقارير المالية |
| **أمين المستودع** | المخزون، الاستلام، الصرف، الجرد — بدون الحسابات |

**التنفيذ**: جدول `users` به عمود `role`، ووظيفة `hasPermission(role, action)` في طبقة الخدمات تُفحص قبل كل إجراء.

---

## 3. الوحدات (Modules)

| الوحدة | الحسابات/الشاشات |
|--------|------------------|
| لوحة التحكم Dashboard | ملخص المبيعات، المشتريات، الأرباح، المصروفات، رسوم بيانية |
| الحسابات Accounts | شجرة الحسابات + الحسابات الإجمالية/التفصيلية |
| القيود اليومية Journal | قيد + تفاصيل، يأذن فقط عند توازن مدين = دائن |
| دفتر الأستاذ Ledger | حركة كل حساب مع الرصيد التراكمي |
| العملاء / الموردون | بطاقة + كشف حساب + رصيد |
| المبيعات | فواتير البيع + بنود + مرتجعات + تحصيلات |
| المشتريات | فواتير الشراء + بنود + مرتجعات + مدفوعات |
| المخزون | منتجات، تصنيفات، وحدات، مستودعات، حركات، جرد |
| الصناديق والبنوك | سند قبض/صرف، تحويلات، حركة صندوق/بنك |
| المصروفات والإيرادات | تسجيل مصروف/إيراد ينشئ قيداً تلقائياً |
| التقارير Reports | كل التقارير المالية والتجارية |
| الإعدادات Settings | الضرائب، العملات، الشركة، المستخدمون، النسخ الاحتياطي |

---

## 4. دورة العمليات المحاسبية

```
فاتورة بيع / شراء  أوست مصروف / سند قبض
            │
            ▼
     تأكيد العملية (اعتماد)
            │
            ▼
   إنشاء قيد اليومية تلقائياً (Journal Entry)
            │
            ▼
  Journal Entry Lines (مدين/دائن)
            │
            ▼
   دفتر الأستاذ ← ميزان المراجعة ← القوائم المالية
```

**قاعدة ذهبية**: القيود هي مصدر الحقيقة المحاسبية. لا شاشة تعدّل رصيداً مباشرة؛ كل عملية تنشئ قيداً، والتقارير تُحسب من القيود.

---

## 5. شجرة الحسابات Chart of Accounts

بنية ثابتة مخزنة في جدول `accounts` (وليست في الكود)، ويمكن للمستخدم إضافة/تعديل/تعطيل حسابات:

```text
1 الأصول
   11 الأصول المتداولة
      1101 الصندوق
      1102 البنوك
      1103 العملاء
      1104 المخزون
   12 الأصول الثابتة
      1201 السيارات
      1202 الأجهزة
      1203 الأثاث
2 الالتزامات
   21 الموردون
   22 القروض
   23 الضرائب المستحقة
3 حقوق الملكية
   31 رأس المال
   32 الأرباح المحتجزة
4 الإيرادات
   41 المبيعات
   42 إيرادات أخرى
5 المصروفات
   51 المشتريات
   52 الرواتب
   53 الإيجار
   54 الكهرباء
   55 الاتصالات
   56 مصروفات أخرى
```

حقول الحساب: `code` (كود فريد)، `name`، `parent_id`، `type` (أصل/التزام/حق ملكية/إيراد/مصروف)، `normal_side` (مدين/دائن)، `is_active`.

---

## 6. قواعد المحاسبة (القيد المزدوج)

- كل قيد يحتوي سطراً أو أكثر (سطران على الأقل).
- يمنع الحفظ إذا كان **إجمالي المدين ≠ إجمالي الدائن**.
- كل فاتورة/سند معتمد يُنشئ قيداً **تلقائياً** عبر خدمية `JournalService`. أمثلة:

**شراء بضاعة نقداً 1000:**
```
من حـ/ المخزون        1000
    إلى حـ/ الصندوق        1000
```

**بيع نقداً 2000 (تكلفة 1200):**
```
من حـ/ الصندوق              2000
    إلى حـ/ المبيعات             2000

من حـ/ تكلفة المبيعات      1200
    إلى حـ/ المخزون             1200
```

---

## 7. قاعدة البيانات المحلية (SQLite)

### 7.1 لماذا SQLite محلية؟
- البيانات ملك المستخدم بالكامل وتبقى على جهازه.
- لا تحتاج إنترنت ولا خادم، وافتراضياً أسرع.
- مناسبة للعمليات العلائقية والتقارير (JOIN + GROUP BY) مع حجم بيانات شركة متوسطة.
- **الحزم المقترحة**:
  - `sqflite` (المحرك، للجوال + دعم Windows/Linux عبر `sqflite_common_ffi`)
  - `path` و `path_provider` (تحديد مكان ملف قاعدة البيانات)
  - (لاحقاً اختياري) `drift` إذا احتجنا طبقة مشروطة أكثر

### 7.2 الجداول

**الأساس:** `settings`, `users`, `accounts`

**المحرك المحاسبي:** `journal_entries`, `journal_entry_lines`

**الأطراف:** `customers`, `suppliers`, `customer_transactions`, `supplier_transactions`

**المخزون:** `products`, `categories`, `units`, `warehouses`, `inventory_transactions`

**المبيعات:** `sales`, `sale_items`, `sale_returns`, `sale_return_items`

**المشتريات:** `purchases`, `purchase_items`, `purchase_returns`, `purchase_return_items`

**الصناديق والبنوك:** `cashboxes`, `banks`, `bank_transactions`, `receipts`, `payments`

**مصروفات/إيرادات:** `expenses`, `revenues`

**مساعدة:** `taxes`, `currencies`, `audit_logs`

```text
accounts ───────────────┐
                        ▼
journal_entries ── journal_entry_lines ──┐ (account_id) حساب/مدين/دائن
                                         │
sales ── sale_items ── products ── inventory_transactions
purchases ── purchase_items ── products ─┘
customers ── sales , receipts
suppliers ── purchases , payments
```

### 7.3 مخطط الجداول الأساسية (DDL)

```sql
CREATE TABLE accounts (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  code       TEXT NOT NULL UNIQUE,             -- 1101
  name       TEXT NOT NULL,
  parent_id  INTEGER REFERENCES accounts(id),
  type       TEXT NOT NULL,                    -- asset / liability / equity / revenue / expense
  normal_side TEXT NOT NULL,                   -- debit / credit
  is_active  INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE journal_entries (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_no    TEXT NOT NULL UNIQUE,            -- JE-000001
  entry_date  TEXT NOT NULL,
  description TEXT,
  reference   TEXT,                            -- رقم الفاتورة المرتبطة
  status      TEXT NOT NULL DEFAULT 'posted',  -- posted / void
  created_by  INTEGER REFERENCES users(id),
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE journal_entry_lines (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  journal_entry_id INTEGER NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
  account_id     INTEGER NOT NULL REFERENCES accounts(id),
  debit          REAL NOT NULL DEFAULT 0,
  credit         REAL NOT NULL DEFAULT 0,
  description    TEXT
);

CREATE TABLE products (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  code        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  category_id INTEGER REFERENCES categories(id),
  unit_id     INTEGER REFERENCES units(id),
  cost_price  REAL NOT NULL DEFAULT 0,
  sale_price  REAL NOT NULL DEFAULT 0,
  min_stock   REAL NOT NULL DEFAULT 0,
  is_active   INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE inventory_transactions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id   INTEGER NOT NULL REFERENCES products(id),
  warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),
  type         TEXT NOT NULL,   -- purchase / sale / return / damaged / transfer_in / transfer_out / adjustment
  quantity     REAL NOT NULL,
  unit_cost    REAL NOT NULL DEFAULT 0,
  reference     TEXT,
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE sales (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_no   TEXT NOT NULL UNIQUE,
  invoice_date TEXT NOT NULL,
  customer_id  INTEGER REFERENCES customers(id),
  subtotal     REAL NOT NULL DEFAULT 0,
  discount     REAL NOT NULL DEFAULT 0,
  tax          REAL NOT NULL DEFAULT 0,
  total        REAL NOT NULL DEFAULT 0,
  paid         REAL NOT NULL DEFAULT 0,
  remaining    REAL NOT NULL DEFAULT 0,
  status       TEXT NOT NULL,                 -- draft / posted / void
  journal_entry_id INTEGER REFERENCES journal_entries(id),
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE sale_items (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  sale_id   INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id),
  qty       REAL NOT NULL,
  price     REAL NOT NULL,
  total     REAL NOT NULL
);

CREATE TABLE customers (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  phone      TEXT,
  email      TEXT,
  address    TEXT,
  account_id INTEGER REFERENCES accounts(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE cashboxes (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  account_id INTEGER REFERENCES accounts(id),
  balance    REAL NOT NULL DEFAULT 0
);

CREATE TABLE banks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  name       TEXT NOT NULL,
  account_id INTEGER REFERENCES accounts(id),
  balance    REAL NOT NULL DEFAULT 0
);

CREATE TABLE receipts (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_no   TEXT NOT NULL UNIQUE,
  receipt_date TEXT NOT NULL,
  customer_id  INTEGER REFERENCES customers(id),
  amount       REAL NOT NULL,
  cashbox_id   INTEGER REFERENCES cashboxes(id),
  description  TEXT,
  journal_entry_id INTEGER REFERENCES journal_entries(id),
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE payments (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_no   TEXT NOT NULL UNIQUE,
  payment_date TEXT NOT NULL,
  supplier_id  INTEGER REFERENCES suppliers(id),
  amount       REAL NOT NULL,
  cashbox_id   INTEGER REFERENCES cashboxes(id),
  description  TEXT,
  journal_entry_id INTEGER REFERENCES journal_entries(id),
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE taxes (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  TEXT NOT NULL,
  rate  REAL NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE currencies (
  id     INTEGER PRIMARY KEY AUTOINCREMENT,
  code   TEXT NOT NULL UNIQUE,     -- YER / USD / SAR
  name   TEXT NOT NULL,
  rate   REAL NOT NULL DEFAULT 1,  -- مقابل العملة الأساسية
  is_default INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE audit_logs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER REFERENCES users(id),
  action     TEXT NOT NULL,        -- create / update / void / delete
  entity     TEXT NOT NULL,        -- sale / journal_entry ...
  entity_id  INTEGER,
  old_value  TEXT,
  new_value  TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

> ملاحظة: `customers` و `suppliers` منفصلان لتبسيط الشاشات، مع ربط كل سجل بحساب في `accounts` عبر `account_id` ليظهر في الميزانية والميزان.

---

## 8. طبقات الكود وتنظيم الملفات والمجلدات

### 8.1 البنية العامة (Feature-First)

```text
lib/
├── main.dart                     # نقطة الدخول + التهيئة (قاعدة البيانات)
│
├── core/                         # كل ما هو مشترك
│   ├── constants/                # ثوابت (أدوار، حالات، أسماء جداول)
│   ├── database/                 # محرك SQLite المركزي
│   │   ├── database.dart         # فتح الاتصال + إنشاء/ترقية الجداول
│   │   ├── migrations.dart       # إصدارات ونقل DB
│   │   └── seed.dart             # البيانات الافتراضية (شجرة الحسابات، الضرائب، المستخدم admin)
│   ├── services/                 # خدمات عامة
│   │   ├── permission_service.dart
│   │   └── audit_service.dart
│   ├── routing/                  # router + المسارات المسماة
│   ├── theme/                    # الثيم والألوان
│   └── utils/                    # مساعدات (رقم تسلسلي، تنسيق عملة، تحويل التاريخ)
│
├── shared/                       # widgets مشتركة بين الميزات
│   ├── widgets/
│   │   ├── app_drawer.dart
│   │   ├── app_bar_title.dart
│   │   └── stat_card.dart
│   └── extensions/
│
├── features/                     # كل ميزة في مجلد مستقل
│   ├── auth/
│   │   ├── data/
│   │   │   ├── models/user.dart
│   │   │   ├── daos/user_dao.dart        # SQL مباشر على جدول معيّن
│   │   │   └── repositories/auth_repository.dart
│   │   └── presentation/
│   │       ├── pages/login_page.dart
│   │       └── widgets/
│   ├── accounts/
│   │   ├── data/
│   │   │   ├── models/account.dart
│   │   │   ├── daos/account_dao.dart
│   │   │   └── repositories/account_repository.dart
│   │   └── presentation/
│   │       ├── pages/accounts_page.dart
│   │       └── widgets/account_tree_node.dart
│   ├── journal/                  # القيود اليومية
│   │   ├── data/models/journal_entry.dart, journal_entry_line.dart
│   │   ├── data/daos/journal_dao.dart
│   │   ├── data/repositories/journal_repository.dart
│   │   └── presentation/pages/journal_entry_form.dart, journal_page.dart
│   ├── sales/
│   ├── purchases/
│   ├── customers/
│   ├── suppliers/
│   ├── inventory/
│   ├── cash/                     # الصناديق وسندات القبض
│   ├── banks/
│   ├── expenses/
│   ├── reports/
│   └── settings/
│
└── shared/navigation.dart
```

### 8.2 توزيع الملفات داخل كل ميزة (نمط موحّد)

```text
features/sales/
├── data/
│   ├── models/
│   │   ├── sale.dart
│   │   ├── sale_item.dart
│   │   └── sale_totals.dart
│   ├── daos/
│   │   ├── sale_dao.dart          # CRUD لكل جدول (SQL خام)
│   │   └── sale_items_dao.dart
│   └── repositories/
│       └── sale_repository.dart   # منطق العمل: اعتماد الفاتورة + إنشاء القيد + تحديث المخزون
└── presentation/
    ├── pages/
    │   ├── sales_list_page.dart
    │   └── sale_form_page.dart
    └── widgets/
        ├── sale_item_tile.dart
        └── customer_picker.dart
```

**قاعدة التقسيم**:
- `models/` → كل ملف = كلاس Dart واحد يمثل صفاً في جدول.
- `daos/` → الوصول المباشر للبيانات (SQL خام، معاملات واحدة).
- `repositories/` → منطق العمل (عمليات مركبة مثل اعتماد فاتورة: تحقق + حركة مخزون + قيد). **لا يحتوي widgets.**
- `presentation/` → واجهة المستخدم فقط (pages + widgets). **لا يمس قاعدة البيانات مباشرة.**

---

## 9. الصفحات والشاشات

| الصفحة | المحتوى |
|--------|---------|
| Login | تسجيل الدخول (اختياري محلي مع دور افتراضي admin) |
| Dashboard | بطاقات: مبيعات، مشتريات، أرباح، مصروفات + رسم بياني للمبيعات آخر 7 أيام |
| شجرة الحسابات | عرض شجري + إضافة/تعديل/تعطيل حساب |
| القيود اليومية | قائمة قيود + نموذج قيد مع تحقق التوازن قبل الحفظ |
| دفتر الأستاذ | اختيار حساب → عرض الحركة والرصيد التراكمي |
| كشف حساب عميل/مورد | فواتير + مدفوعات + الرصيد |
| فاتورة بيع | بنود المنتج + خصم + ضريبة + مدفوع/متبقي |
| فاتورة شراء | نفس بنية البيع مقلوبة |
| المخزون | منتجات + حركات + جرد + تنبيه حد أدنى |
| الصندوق/البنك | سندات + حركة + رصيد |
| المصروفات/الإيرادات | نموذج بسيط يُنشئ قيداً تلقائياً |
| التقارير | كل تقرير صفحة + مشاركة/طباعة PDF لاحقاً |
| الإعدادات | شركة، ضرائب، عملات، مستخدمون، نسخة احتياطية |

---

## 10. التقارير

**مالية:**
- دفتر اليومية (كل القيود بتاريخ/نطاق)
- دفتر الأستاذ العام (لكل حساب: حركة + رصيد)
- ميزان المراجعة (أرصدة مدينة/دائنة)
- قائمة الدخل (إيرادات − مصروفات − تكلفة المبيعات = صافي الربح)
- الميزانية العمومية (الأصول = الالتزامات + حقوق الملكية)

**تجارية:**
- تقرير المبيعات (فواتير، إجماليات، حسب العميل/المنتج/الفترة)
- تقرير المشتريات
- تقرير الأرباح (مبيعات − تكلفة)
- تقرير المصروفات حسب التصنيف
- تقرير حركة الصندوق والبنك
- تقرير المخزون (أرصدة + حركات + حد أدنى)

كل تقرير يُحسب من القيود/الجداول المصدَرية عبر `dao` وليس من أرصدة مخزنة يدوياً.

---

## 11. الأمان والصلاحيات

- فحص الدور قبل كل إجراء عبر `PermissionService`.
- الشاشات الحساسة (التقارير المالية، الإعدادات) مقيدة بـ `role`.
- أرشفة العمليات في `audit_logs`.
- **لا حذف مادي** للعمليات المعتمدة: تعليم `status = void` + إنشاء قيد عكسي.
- كلمة المرور تُخزن hash (وليس نصاً) باستخدام `crypto`/`bcrypt`.

---

## 12. النسخ الاحتياطي

- تصدير/استيراد ملف `accountingsystem.db` من صفحة الإعدادات.
- تأثير كامل النسخة إلى مجلد معرّف (مشاركة/SD/Documents).
- اختياري لاحقاً: تصدير التقارير PDF عبر `pdf` الحزمة.

---

## 13. الاختبارات

- اختبارات وحدة (Dart test) على المحرك المحاسبي: خلق قيد، التوازن، تجميع ميزان المراجعة.
- اختبارات Repository باستخدام قاعدة SQLite في الذاكرة (`sqflite_common_ffi` + `inMemoryDatabasePath`).
- اختبار Widget للشاشات الرئيسية.

---

## 14. النشر

- الجوال: Android (APK/AAB) و iOS.
- Desktop: Windows (يعمل عبر `sqflite_common_ffi`).
- Web (اختياري لاحقاً): محدود بسبب SQLite — يُنقل إلى backend عند الحاجة.

---

## 15. خطة التنفيذ بالمراحل

| المرحلة | المحتوى | الحالة |
|---------|---------|--------|
| **0** | توثيق المشروع + تهيئة المشروع والهيكل | ✅ جارية |
| **1** | المحرك المحاسبي: قاعدة البيانات، seed (شجرة الحسابات)، المستخدمون، القيود، دفتر الأستاذ، ميزان المراجعة | ⏸ |
| **2** | العملاء والموردون: كشوف الحساب + سندات القبض/الصرف | ⏸ |
| **3** | المبيعات والمشتريات مع إنشاء القيود تلقائياً + المرتجعات والضرائب | ⏸ |
| **4** | المخزون: منتجات، مستودعات، حركات، جرد | ⏸ |
| **5** | التقارير المالية والتجارية الكاملة | ⏸ |
| **6** | الأشياء المتقدمة: الرواتب، الأصول الثابتة، الإهلاك، الشيكات، العملات، المصادقة والنسخ الاحتياطي | ⏸ |