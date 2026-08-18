import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generates PDFs for two related but distinct documents:
/// - generateAndUpload: a payment RECEIPT (proof of payment received) — unchanged
///   from earlier tonight.
/// - generateGstInvoiceAndUpload: a proper GST-format TAX INVOICE — new. These are
///   not the same document: a tax invoice needs the seller's GSTIN, an itemized tax
///   breakdown, and a place of supply, which a simple receipt doesn't.
///
/// HONEST NOTE ON GST APPLICABILITY: school tuition is commonly GST-EXEMPT under
/// Indian tax law; ancillary services (transport, hostel, etc.) often aren't. This
/// builds the generation MECHANISM regardless — whether a specific fee should actually
/// carry GST is a real tax-compliance question for the school to confirm, not
/// something this code decides. Right now every invoice in the system defaults to
/// gst_rate=0 (confirmed via direct query) — nothing has real GST applied yet, so this
/// invoice type will show a ₹0 tax line until a real GST rate is actually entered
/// somewhere upstream (Fee Management's invoice creation, or a future edit screen).
class ReceiptGenerator {
  static Future<String> generateAndUpload({
    required SupabaseClient client,
    required String paymentId,
    required String studentName,
    required String admissionNumber,
    required double amount,
    required String method,
    required String status,
    required DateTime paidAt,
    String? invoiceNumber,
    double? gstRate,
    double? gstAmount,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Payment Receipt', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Demo Public School', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              pw.Divider(height: 24),
              _row('Receipt for', studentName),
              _row('Admission No.', admissionNumber),
              if (invoiceNumber != null) _row('Invoice No.', invoiceNumber),
              _row('Payment ID', paymentId.length >= 8 ? paymentId.substring(0, 8) : paymentId),
              _row('Date', '${paidAt.year}-${paidAt.month.toString().padLeft(2, '0')}-${paidAt.day.toString().padLeft(2, '0')}'),
              _row('Method', method.toUpperCase()),
              _row('Status', status.toUpperCase()),
              pw.Divider(height: 24),
              _row('Amount', 'INR ${amount.toStringAsFixed(2)}', bold: true),
              if (gstRate != null && gstRate > 0) _row('GST (${gstRate.toStringAsFixed(0)}%)', 'INR ${(gstAmount ?? 0).toStringAsFixed(2)}'),
              pw.SizedBox(height: 24),
              pw.Text('This is a system-generated receipt.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
            ],
          ),
        ),
      ),
    );

    final Uint8List bytes = await doc.save();
    final path = 'receipt-$paymentId.pdf';
    try {
      await client.storage.from('receipts').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true));
      return await client.storage.from('receipts').createSignedUrl(path, 3600);
    } catch (_) {
      // Fallback to data URL
      return 'data:application/pdf;base64,${Uri.encodeComponent(doc.toString())}';
    }
  }

  /// A proper GST-format tax invoice — itemized, with a clear tax breakdown line.
  /// Distinct document from the payment receipt above.
  static Future<String> generateGstInvoiceAndUpload({
    required SupabaseClient client,
    required String invoiceId,
    required String invoiceNumber,
    required String studentName,
    required String admissionNumber,
    required String feeStructureName,
    required double baseAmount,
    required double gstRate,
    required DateTime issuedAt,
    String schoolGstin = 'GSTIN NOT CONFIGURED', // real value must be set by the school
  }) async {
    final path = 'tax-invoice-$invoiceId.pdf';

    // 1. Try pulling existing signed URL if file already exists in Storage
    try {
      final existingUrl = await client.storage.from('receipts').createSignedUrl(path, 3600);
      if (existingUrl.isNotEmpty && !existingUrl.contains('error')) {
        return existingUrl;
      }
    } catch (_) {}

    // 2. Generate PDF document if not present yet
    final gstAmount = baseAmount * gstRate / 100;
    final total = baseAmount + gstAmount;
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Tax Invoice', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Demo Public School', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              pw.Text('GSTIN: $schoolGstin', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              pw.Divider(height: 24),
              _row('Invoice No.', invoiceNumber),
              _row('Bill to', studentName),
              _row('Admission No.', admissionNumber),
              _row('Date', '${issuedAt.year}-${issuedAt.month.toString().padLeft(2, '0')}-${issuedAt.day.toString().padLeft(2, '0')}'),
              pw.Divider(height: 24),
              pw.Text('Description', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              _row(feeStructureName, 'INR ${baseAmount.toStringAsFixed(2)}'),
              _row('GST (${gstRate.toStringAsFixed(1)}%)', 'INR ${gstAmount.toStringAsFixed(2)}'),
              pw.Divider(height: 16),
              _row('Total', 'INR ${total.toStringAsFixed(2)}', bold: true),
              pw.SizedBox(height: 24),
              pw.Text(
                gstRate == 0
                    ? 'This item is not subject to GST.'
                    : 'This is a system-generated tax invoice.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
              ),
            ],
          ),
        ),
      ),
    );

    final Uint8List bytes = await doc.save();

    // 3. Upload with upsert fallback
    try {
      await client.storage.from('receipts').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
      );
    } catch (_) {
      // If upload fails (e.g. RLS upsert error), attempt creating signed URL directly
    }

    return await client.storage.from('receipts').createSignedUrl(path, 3600);
  }

  static pw.Widget _row(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
