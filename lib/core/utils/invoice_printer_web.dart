import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// بند في الفاتورة
class PrintLine {
  final String name;
  final double price;
  final double qty;
  final double total;

  const PrintLine({
    required this.name,
    required this.price,
    required this.qty,
    required this.total,
  });
}

/// طباعة فاتورة عبر نافذة مطبوعة في المتصفح (يدعم العربية)
void printInvoice({
  required String invoiceNo,
  required String date,
  required String customer,
  required List<PrintLine> lines,
  required double total,
}) {
  final rows = lines
      .map(
        (l) =>
            '<tr>'
            '<td>${l.name}</td>'
            '<td>${l.price.toStringAsFixed(2)}</td>'
            '<td>${l.qty.toStringAsFixed(0)}</td>'
            '<td>${l.total.toStringAsFixed(2)}</td>'
            '</tr>',
      )
      .join();

  final htmlStr =
      '''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="utf-8">
<title>فاتورة $invoiceNo</title>
<style>
  body { font-family: 'Segoe UI', Tahoma, Arial, sans-serif; padding: 24px; }
  h2 { text-align: center; }
  table { width: 100%; border-collapse: collapse; margin-top: 16px; }
  th, td { border: 1px solid #333; padding: 6px 10px; text-align: right; }
  th { background: #f0f0f0; }
  .total { font-size: 20px; font-weight: bold; margin-top: 16px; }
  .meta { margin-bottom: 4px; }
</style>
</head>
<body>
  <h2>فاتورة مبيعات</h2>
  <p class="meta"><b>رقم الفاتورة:</b> $invoiceNo</p>
  <p class="meta"><b>التاريخ:</b> $date</p>
  <p class="meta"><b>العميل:</b> $customer</p>
  <table>
    <thead>
      <tr><th>المنتج</th><th>السعر</th><th>الكمية</th><th>الإجمالي</th></tr>
    </thead>
    <tbody>$rows</tbody>
  </table>
  <p class="total">الإجمالي: ${total.toStringAsFixed(2)}</p>
</body>
</html>''';

  final win = web.window.open('', '_blank');
  if (win == null) return;
  win.document.write(htmlStr.toJS);
  win.document.close();
  win.focus();
  win.print();
}
