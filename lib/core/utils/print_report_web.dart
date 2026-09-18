import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// فتح نافذة طباعة بتقرير HTML فاخر (RTL) — يعمل من أي متصفح على أي جهاز.
///
/// تُفتح نافذة جديدة مباشرة من ضغطة المستخدم (حتى لا يحجبها المتصفح)
/// ثم يستدعي أمر الطباعة تلقائياً وتُغلق النافذة بعد الطباعة.
void printHtmlReport({
  required String title,
  required String companyLine,
  required String bodyHtml,
}) {
  final html = '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8">
<title>$title</title>
<style>
  @page { size: A4 landscape; margin: 10mm; }
  * { box-sizing: border-box;
      font-family: 'Segoe UI', Tahoma, 'Traditional Arabic', Arial, sans-serif; }
  body { margin: 0; color: #0f172a; background: #fff; }
  .head { display: flex; justify-content: space-between; align-items: center;
          border-bottom: 3px solid #0f172a; padding-bottom: 10px;
          margin-bottom: 12px; }
  .head h1 { font-size: 19px; margin: 0 0 4px; }
  .head .meta { font-size: 11.5px; color: #475569; }
  .head .brand { text-align: left; font-size: 12px; font-weight: bold;
                 color: #b45309; }
  .badge { background: #0f172a; color: #fff; padding: 7px 14px;
           border-radius: 8px; display: inline-block; font-size: 12.5px;
           font-weight: bold; margin-bottom: 10px; }
  .cards { display: flex; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
  .card { flex: 1; min-width: 125px; border: 1px solid #e2e8f0;
          border-radius: 8px; padding: 8px 10px; background: #f8fafc; }
  .card .t { font-size: 10.5px; color: #64748b; margin-bottom: 3px; }
  .card .v { font-size: 15px; font-weight: bold; color: #0f172a; }
  table { width: 100%; border-collapse: collapse; font-size: 11.5px; }
  th { background: #0f172a; color: #fff; padding: 8px 6px;
       font-size: 11px; white-space: nowrap; }
  td { padding: 6px; border-bottom: 1px solid #e2e8f0; text-align: center; }
  tr:nth-child(even) td { background: #f8fafc; }
  .totals td { background: #fef3c7 !important; font-weight: bold;
               border-top: 2px solid #d97706; border-bottom: 2px solid #d97706; }
  .neg { color: #dc2626; font-weight: bold; }
  .pos { color: #16a34a; font-weight: bold; }
  .foot { margin-top: 12px; font-size: 10px; color: #64748b; text-align: center;
          border-top: 1px solid #e2e8f0; padding-top: 8px; }
  @media print { .noprint { display: none; } }
</style>
</head>
<body>
<div class="head">
  <div>
    <h1>$title</h1>
    <div class="meta">$companyLine</div>
  </div>
  <div class="brand">النظام المحاسبي المتكامل</div>
</div>
$bodyHtml
<div class="foot">
  تقرير سحابي مولّد تلقائياً — النظام المحاسبي &nbsp;|&nbsp; طُبع بتاريخ
  التقرير أعلاه &nbsp;|&nbsp; كل البيانات محفوظة في السحابة (Firebase)
</div>
<script>
  window.onload = function () {
    setTimeout(function () { window.focus(); window.print(); }, 300);
  };
  window.onafterprint = function () {
    setTimeout(function () { window.close(); }, 250);
  };
</script>
</body>
</html>''';
  final win = web.window.open('', '_blank');
  if (win == null) return;
  win.document.write(html.toJS);
  win.document.close();
}
