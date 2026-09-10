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

/// على غير الويب لا نطبع (لا عملية)
void printInvoice({
  required String invoiceNo,
  required String date,
  required String customer,
  required List<PrintLine> lines,
  required double total,
}) {
  // no-op
}
