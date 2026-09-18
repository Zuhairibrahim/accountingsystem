import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'report_models.dart';

pw.Font? _regularFont;
pw.Font? _boldFont;

Future<pw.Font> _fontFromFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return pw.Font.ttf(
    ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length),
  );
}

/// تحميل خط عربي من خطوط ويندوز (تاهوما ثم سيجوث ثم أريال) مع تخزين مؤقت.
Future<pw.Font> _loadRegular() async {
  if (_regularFont != null) return _regularFont!;
  for (final path in const [
    r'C:\Windows\Fonts\tahoma.ttf',
    r'C:\Windows\Fonts\segoeui.ttf',
    r'C:\Windows\Fonts\arial.ttf',
  ]) {
    try {
      final f = File(path);
      if (await f.exists()) {
        return _regularFont = await _fontFromFile(path);
      }
    } catch (_) {}
  }
  return _regularFont = pw.Font.helvetica();
}

Future<pw.Font> _loadBold() async {
  if (_boldFont != null) return _boldFont!;
  for (final path in const [
    r'C:\Windows\Fonts\tahomabd.ttf',
    r'C:\Windows\Fonts\segoeuib.ttf',
    r'C:\Windows\Fonts\arialbd.ttf',
  ]) {
    try {
      final f = File(path);
      if (await f.exists()) {
        return _boldFont = await _fontFromFile(path);
      }
    } catch (_) {}
  }
  return _boldFont = await _loadRegular();
}

const _navy = PdfColor.fromInt(0xFF0F172A);
const _amberBg = PdfColor.fromInt(0xFFFEF3C7);
const _grey = PdfColor.fromInt(0xFF64748B);
const _lightRow = PdfColor.fromInt(0xFFF8FAFC);
const _border = PdfColor.fromInt(0xFFE2E8F0);

pw.TextStyle _style(pw.Font font, double size, {PdfColor color = _navy}) =>
    pw.TextStyle(font: font, fontSize: size, color: color);

pw.Text _txt(
  String data,
  pw.Font font,
  double size, {
  PdfColor color = _navy,
  pw.TextAlign align = pw.TextAlign.center,
}) =>
    pw.Text(
      data,
      style: _style(font, size, color: color),
      textAlign: align,
      textDirection: pw.TextDirection.rtl,
    );

/// طباعة التقرير على سطح المكتب — ملف PDF عربي (A4 أفقي) + نافذة الطباعة.
Future<void> printFullReport({
  required String title,
  required String companyLine,
  List<({String label, String value})> stats = const [],
  required List<ReportTable> tables,
}) async {
  try {
    final regular = await _loadRegular();
    final bold = await _loadBold();
    final now = DateTime.now();
    final dateLabel =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          // ===== الرأس =====
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _navy, width: 2.5),
              ),
            ),
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _txt(title, bold, 15, align: pw.TextAlign.left),
                    pw.SizedBox(height: 4),
                    _txt(companyLine, regular, 8.5,
                        color: _grey, align: pw.TextAlign.left),
                  ],
                ),
                _txt('النظام المحاسبي المتكامل', bold, 10,
                    color: const PdfColor.fromInt(0xFFB45309),
                    align: pw.TextAlign.right),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          // ===== البطاقات الإحصائية =====
          if (stats.isNotEmpty) ...[
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in stats)
                  pw.Container(
                    width: 150,
                    padding:
                        const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: _lightRow,
                      border: pw.Border.all(color: _border),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _txt(s.label, regular, 8, color: _grey,
                            align: pw.TextAlign.right),
                        pw.SizedBox(height: 3),
                        _txt(s.value, bold, 11, align: pw.TextAlign.right),
                      ],
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
          ],
          // ===== الجداول =====
          for (final t in tables) ...[
            if (t.caption != null) ...[
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _navy,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: _txt(t.caption!, bold, 9.5, color: PdfColors.white),
              ),
            ],
            _buildTable(t, regular, bold),
            pw.SizedBox(height: 14),
          ],
          // ===== التذييل =====
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _border)),
            ),
            padding: const pw.EdgeInsets.only(top: 6),
            child: _txt(
              'تقرير مولّد تلقائياً من النظام المحاسبي المتكامل — طُبع بتاريخ $dateLabel',
              regular,
              7.5,
              color: _grey,
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: title,
      onLayout: (format) => doc.save(),
    );
  } catch (e) {
    debugPrint('فشل توليد الطباعة: $e');
  }
}

pw.Widget _buildTable(ReportTable t, pw.Font regular, pw.Font bold) {
  final rows = <pw.TableRow>[
    // رأس الجدول
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _navy),
      children: [
        for (final c in t.columns)
          pw.Padding(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
            child: _txt(c, bold, 8.5, color: PdfColors.white),
          ),
      ],
    ),
    // صفوف البيانات
    for (var i = 0; i < t.rows.length; i++)
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isEven ? _lightRow : PdfColors.white,
        ),
        children: [
          for (final cell in t.rows[i])
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: _txt(cell, regular, 8.5),
            ),
        ],
      ),
    // صف الإجماليات
    if (t.totalsRow != null)
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: _amberBg,
          border: const pw.Border(
            top: pw.BorderSide(color: PdfColor.fromInt(0xFFD97706), width: 1.5),
            bottom:
                pw.BorderSide(color: PdfColor.fromInt(0xFFD97706), width: 1.5),
          ),
        ),
        children: [
          for (final cell in t.totalsRow!)
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: _txt(cell, bold, 8.8),
            ),
        ],
      ),
  ];

  return pw.Table(
    border: pw.TableBorder.all(color: _border, width: 0.5),
    defaultColumnWidth: const pw.FlexColumnWidth(1),
    children: rows,
  );
}
