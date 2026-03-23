import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../ui/widgets/animated_glass_card.dart';

/// Displays an invoice and provides Print / Save PDF / Skip options.
class InvoiceView extends StatelessWidget {
  final Map<String, dynamic> invoiceData;

  const InvoiceView({super.key, required this.invoiceData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة البيع', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AnimatedGlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    invoiceData['companyName'] ?? 'الشركة',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('فاتورة بيع', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  _row('المتجر / المخزن', invoiceData['storeName'] ?? '-'),
                  _row('البائع', invoiceData['sellerName'] ?? '-'),
                  _row('المشتري', invoiceData['customerName'] ?? '-'),
                  const Divider(height: 32),
                  _row('المنتج', invoiceData['productName'] ?? '-'),
                  _row('الكمية', '${invoiceData['quantity'] ?? 0}'),
                  _row('سعر الوحدة', '${invoiceData['unitPrice'] ?? 0} د'),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع الكلي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${invoiceData['totalAmount'] ?? 0} د',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _row('التاريخ والوقت', invoiceData['dateTime'] ?? '-'),
                  if (invoiceData['notes'] != null && (invoiceData['notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _row('ملاحظات', invoiceData['notes']),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _actionBtn(context, Icons.print_rounded, 'طباعة', AppColors.primary, () => _printInvoice(context))),
                const SizedBox(width: 12),
                Expanded(child: _actionBtn(context, Icons.picture_as_pdf_rounded, 'حفظ PDF', Colors.red.shade400, () => _savePdf(context))),
                const SizedBox(width: 12),
                Expanded(child: _actionBtn(context, Icons.skip_next_rounded, 'تخطي', Colors.grey, () => Navigator.of(context).pop())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              // Align value to start (right in RTL) to be close to the label
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedGlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  /// Load Arabic-compatible fonts from Google Fonts for PDF rendering.
  Future<pw.ThemeData> _loadArabicTheme() async {
    final regular = await PdfGoogleFonts.notoNaskhArabicRegular();
    final bold = await PdfGoogleFonts.notoNaskhArabicBold();
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
    );
  }

  Future<Uint8List> _generatePdf() async {
    final doc = pw.Document();
    final arabicTheme = await _loadArabicTheme();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: arabicTheme,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(invoiceData['companyName'] ?? '', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('فاتورة بيع', style: pw.TextStyle(fontSize: 16)),
                pw.Divider(height: 30),

                _pdfRow('المتجر / المخزن', invoiceData['storeName'] ?? '-'),
                _pdfRow('البائع', invoiceData['sellerName'] ?? '-'),
                _pdfRow('المشتري', invoiceData['customerName'] ?? '-'),
                pw.Divider(height: 20),

                _pdfRow('المنتج', invoiceData['productName'] ?? '-'),
                _pdfRow('الكمية', '${invoiceData['quantity'] ?? 0}'),
                _pdfRow('سعر الوحدة', '${invoiceData['unitPrice'] ?? 0} د'),
                pw.Divider(height: 20),

                _pdfRow('المجموع الكلي', '${invoiceData['totalAmount'] ?? 0} د', bold: true),
                pw.SizedBox(height: 10),
                _pdfRow('التاريخ والوقت', invoiceData['dateTime'] ?? '-'),

                if (invoiceData['notes'] != null && (invoiceData['notes'] as String).isNotEmpty)
                  _pdfRow('ملاحظات', invoiceData['notes']),

                pw.Spacer(),
                pw.Center(child: pw.Text('شكراً لتعاملكم معنا', style: pw.TextStyle(fontSize: 14))),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    // In an RTL layout, the first child of a Row is placed on the Right.
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Label goes on the Right (First child)
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
              textDirection: pw.TextDirection.rtl),
          // Spacer
          pw.SizedBox(width: 20),
          // Value goes on the Left (Second child)
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: bold ? 18 : 14),
                textDirection: pw.TextDirection.rtl,
                textAlign: pw.TextAlign.left),
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoice(BuildContext context) async {
    try {
      final pdfData = await _generatePdf();
      await Printing.layoutPdf(onLayout: (_) => pdfData);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الطباعة: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _savePdf(BuildContext context) async {
    try {
      final pdfData = await _generatePdf();
      await Printing.sharePdf(bytes: pdfData, filename: 'invoice_${DateTime.now().millisecondsSinceEpoch}.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في حفظ PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
