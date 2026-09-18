import 'report_models.dart';

/// تهريب نصوص HTML
String escHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// توليد جسم التقرير HTML (بطاقات إحصائية + جداول مع عناوين وإجماليات).
String buildReportBodyHtml({
  List<({String label, String value})> stats = const [],
  required List<ReportTable> tables,
}) {
  final buf = StringBuffer();

  if (stats.isNotEmpty) {
    buf.write('<div class="cards">');
    for (final s in stats) {
      buf.write(
        '<div class="card"><div class="t">${escHtml(s.label)}</div>'
        '<div class="v">${escHtml(s.value)}</div></div>',
      );
    }
    buf.write('</div>');
  }

  for (final t in tables) {
    if (t.caption != null) {
      buf.write('<div class="badge">${escHtml(t.caption!)}</div>');
    }
    buf.write('<table><thead><tr>');
    for (final c in t.columns) {
      buf.write('<th>${escHtml(c)}</th>');
    }
    buf.write('</tr></thead><tbody>');
    for (final row in t.rows) {
      buf.write('<tr>');
      for (final cell in row) {
        buf.write('<td>${escHtml(cell)}</td>');
      }
      buf.write('</tr>');
    }
    if (t.totalsRow != null) {
      buf.write('<tr class="totals">');
      for (final cell in t.totalsRow!) {
        buf.write('<td>${escHtml(cell)}</td>');
      }
      buf.write('</tr>');
    }
    buf.write('</tbody></table>');
  }
  return buf.toString();
}
