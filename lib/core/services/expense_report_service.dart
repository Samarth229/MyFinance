import 'dart:math';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../repositories/personal_expense_repository.dart';

class ExpenseReportService {
  final _repo = PersonalExpenseRepository();

  // Category colors for pie chart
  static const _categoryColors = [
    PdfColors.blue800,
    PdfColors.orange800,
    PdfColors.purple800,
    PdfColors.teal800,
    PdfColors.green800,
    PdfColors.red800,
    PdfColors.amber800,
  ];

  Future<void> generateAndShare() async {
    final data = await _repo.getLast6MonthsGrouped();
    final selfByMonth = await _repo.getSelfAmountsByMonth();
    final pdf = pw.Document();

    // Load app logo
    final logoData = await rootBundle.load('assets/logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    // Grand total across all 6 months per category
    final grandMap = <String, double>{};
    for (final monthData in data.values) {
      for (final entry in monthData.entries) {
        grandMap[entry.key] = (grandMap[entry.key] ?? 0) + entry.value.total;
      }
    }
    final selfGrandTotal = selfByMonth.values.fold(0.0, (a, b) => a + b);
    final grandTotal =
        grandMap.values.fold(0.0, (a, b) => a + b) + selfGrandTotal;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final widgets = <pw.Widget>[];

          // ── Header ──────────────────────────────────────────────────────────
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('388E3C'),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(logoImage, width: 44, height: 44),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DebtTrack - Personal Expense Report',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated on: ${_formatDate(DateTime.now())}   |   Last 6 months report',
                        style: pw.TextStyle(
                            color: PdfColors.grey300, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          widgets.add(pw.SizedBox(height: 24));

          // ── Per-month tables ─────────────────────────────────────────────
          for (final monthEntry in data.entries) {
            final monthName = monthEntry.key;
            final categories = monthEntry.value;
            final selfAmount = selfByMonth[monthName] ?? 0.0;

            if (categories.isEmpty && selfAmount == 0) continue;

            final monthTotal =
                categories.values.fold(0.0, (a, b) => a + b.total) +
                    selfAmount;

            widgets.add(
              pw.Text(monthName,
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
            );
            widgets.add(pw.SizedBox(height: 6));

            widgets.add(
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColor.fromHex('BDBDBD'), width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(110),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('E8F5E9')),
                    children: [
                      _cell('Type', bold: true),
                      _cell('Description', bold: true),
                      _cell('Total Amount',
                          bold: true,
                          align: pw.Alignment.centerRight),
                    ],
                  ),
                  ...categories.entries.map((catEntry) {
                    final descs = catEntry.value.descriptions;
                    return pw.TableRow(
                      children: [
                        _cell(catEntry.key),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: descs
                                .map((d) => pw.Text(d,
                                    style:
                                        const pw.TextStyle(fontSize: 9)))
                                .toList(),
                          ),
                        ),
                        _cell('Rs.${_fmt(catEntry.value.total)}',
                            align: pw.Alignment.centerRight),
                      ],
                    );
                  }),
                  // ── Self row ──────────────────────────────────────────────
                  if (selfAmount > 0)
                    pw.TableRow(
                      children: [
                        _cell('Self'),
                        _cell('Amount Spent on self during Splits'),
                        _cell('Rs.${_fmt(selfAmount)}',
                            align: pw.Alignment.centerRight),
                      ],
                    ),
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('F1F8E9')),
                    children: [
                      _cell('Month Total', bold: true),
                      _cell(''),
                      _cell('Rs.${_fmt(monthTotal)}',
                          bold: true,
                          align: pw.Alignment.centerRight),
                    ],
                  ),
                ],
              ),
            );

            widgets.add(pw.SizedBox(height: 20));
          }

          // ── Grand total table ────────────────────────────────────────────
          widgets.add(pw.Divider(color: PdfColor.fromHex('388E3C')));
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(
            pw.Text('6-Month Grand Summary',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
          );
          widgets.add(pw.SizedBox(height: 6));

          final categoryList = grandMap.entries.toList();
          // Include self in pie chart data
          final pieList = [
            ...categoryList,
            if (selfGrandTotal > 0)
              MapEntry('Self', selfGrandTotal),
          ];
          final pieTotal =
              pieList.fold(0.0, (a, b) => a + b.value);

          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('BDBDBD'), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(),
                1: const pw.FixedColumnWidth(100),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('E8F5E9')),
                  children: [
                    _cell('Type', bold: true),
                    _cell('6-Month Total',
                        bold: true, align: pw.Alignment.centerRight),
                  ],
                ),
                ...categoryList.map((e) => pw.TableRow(
                      children: [
                        _cell(e.key),
                        _cell('Rs.${_fmt(e.value)}',
                            align: pw.Alignment.centerRight),
                      ],
                    )),
                // ── Self row in grand summary ─────────────────────────────
                if (selfGrandTotal > 0)
                  pw.TableRow(
                    children: [
                      _cell('Self'),
                      _cell('Rs.${_fmt(selfGrandTotal)}',
                          align: pw.Alignment.centerRight),
                    ],
                  ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('388E3C')),
                  children: [
                    _cell('Grand Total', bold: true, white: true),
                    _cell('Rs.${_fmt(grandTotal)}',
                        bold: true,
                        white: true,
                        align: pw.Alignment.centerRight),
                  ],
                ),
              ],
            ),
          );

          // ── Pie Chart ────────────────────────────────────────────────────
          if (pieTotal > 0 && pieList.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 24));
            widgets.add(
              pw.Text('Expense Breakdown',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
            );
            widgets.add(pw.SizedBox(height: 12));

            widgets.add(
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Pie chart
                  pw.SizedBox(
                    width: 150,
                    height: 150,
                    child: pw.CustomPaint(
                      size: const PdfPoint(150, 150),
                      painter: (canvas, size) {
                        _drawPieChart(canvas, size, pieList, pieTotal);
                      },
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Legend
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: pieList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final cat = entry.value;
                      final pct =
                          (cat.value / pieTotal * 100).toStringAsFixed(1);
                      final color = _categoryColors[
                          idx % _categoryColors.length];
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 12,
                              height: 12,
                              decoration: pw.BoxDecoration(
                                color: color,
                                borderRadius: const pw.BorderRadius.all(
                                    pw.Radius.circular(2)),
                              ),
                            ),
                            pw.SizedBox(width: 6),
                            pw.Text(
                              '${cat.key}  $pct%  (Rs.${_fmt(cat.value)})',
                              style:
                                  const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }

          return widgets;
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'DebtTrack_Expense_Report.pdf',
    );
  }

  void _drawPieChart(PdfGraphics canvas, PdfPoint size,
      List<MapEntry<String, double>> categories, double total) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final radius = min(cx, cy) - 4;
    const steps = 60; // segments per full circle for smooth arc

    double startAngle = -pi / 2; // start from top

    for (int i = 0; i < categories.length; i++) {
      final sweepAngle = (categories[i].value / total) * 2 * pi;
      final color = _categoryColors[i % _categoryColors.length];

      canvas.setFillColor(color);
      canvas.moveTo(cx, cy);

      // Draw arc as many small line segments
      final segCount = max(1, (sweepAngle / (2 * pi) * steps).round());
      for (int s = 0; s <= segCount; s++) {
        final angle = startAngle + sweepAngle * s / segCount;
        canvas.lineTo(cx + radius * cos(angle), cy + radius * sin(angle));
      }

      canvas.closePath();
      canvas.fillPath();

      // White divider line
      canvas.setStrokeColor(PdfColors.white);
      canvas.setLineWidth(1.5);
      canvas.moveTo(cx, cy);
      canvas.lineTo(
          cx + radius * cos(startAngle), cy + radius * sin(startAngle));
      canvas.strokePath();

      startAngle += sweepAngle;
    }
  }

  pw.Widget _cell(String text,
      {bool bold = false,
      bool white = false,
      pw.Alignment align = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight:
                bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: white ? PdfColors.white : PdfColors.black,
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
