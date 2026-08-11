// Export utilities for budget data - PDF and CSV/Excel formats

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../../features/dashboard/principal/models/budget_models.dart';

/// Generates a PDF budget report for the current view
class BudgetPDFExporter {
  static Future<String> generateBudgetReport({
    required String title,
    required List<BudgetKPI> kpis,
    required List<BudgetCategory> categories,
    required BudgetForecast? forecast,
    required String fiscalYear,
    required DateTime generatedAt,
  }) async {
    final pdf = pw.Document();

    // Add KPI page
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(title, fiscalYear, generatedAt),
            pw.SizedBox(height: 16),
            _buildKPISection(kpis),
            pw.SizedBox(height: 20),
            _buildCategoriesTable(categories),
            if (forecast != null) ...[
              pw.SizedBox(height: 20),
              _buildForecastSection(forecast),
            ],
          ],
        ),
      ),
    );

    await pdf.save();
    return 'budget_report_${fiscalYear}_${DateFormat('yyyyMMdd_HHmmss').format(generatedAt)}.pdf';
  }

  static pw.Widget _buildHeader(String title, String fiscalYear, DateTime generatedAt) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Budget Report', style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Fiscal Year: $fiscalYear', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Generated: ${DateFormat('MMM d, yyyy - HH:mm').format(generatedAt)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKPISection(List<BudgetKPI> kpis) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        border: pw.Border.all(color: PdfColors.blueGrey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Key Performance Indicators', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kpis.map((kpi) => pw.Container(
              width: 110,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(kpi.label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    kpi.value,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _getKPIColor(kpi.status)),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  static PdfColor _getKPIColor(String status) {
    if (status == 'critical') return PdfColors.red;
    if (status == 'warning') return PdfColors.orange;
    return PdfColors.green;
  }

  static pw.Widget _buildCategoriesTable(List<BudgetCategory> categories) {
    final totalPlanned = categories.fold<double>(0.0, (sum, c) => sum + c.planned);
    final totalActual = categories.fold<double>(0.0, (sum, c) => sum + c.actual);
    final totalVariance = totalPlanned - totalActual;
    final totalUtil = totalPlanned > 0 ? (totalActual / totalPlanned * 100) : 0.0;

    return pw.Padding(
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Budget by Category', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                children: [
                  _cell('Category', isHeader: true),
                  _cell('Planned', isHeader: true),
                  _cell('Actual', isHeader: true),
                  _cell('Variance', isHeader: true),
                  _cell('Utilization', isHeader: true),
                ],
              ),
              ...categories.map((cat) => pw.TableRow(
                children: [
                  _cell(cat.category),
                  _cell('\$${cat.planned.toStringAsFixed(0)}'),
                  _cell('\$${cat.actual.toStringAsFixed(0)}'),
                  _cell(
                    '\$${(cat.planned - cat.actual).toStringAsFixed(0)}',
                    color: cat.planned >= cat.actual ? PdfColors.green : PdfColors.red,
                  ),
                  _cell('${(cat.utilization * 100).toStringAsFixed(1)}%'),
                ],
              )),
              // Total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _cell('Total', isHeader: true),
                  _cell('\$${totalPlanned.toStringAsFixed(0)}', isHeader: true),
                  _cell('\$${totalActual.toStringAsFixed(0)}', isHeader: true),
                  _cell('\$${totalVariance.toStringAsFixed(0)}', isHeader: true),
                  _cell('${totalUtil.toStringAsFixed(1)}%', isHeader: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildForecastSection(BudgetForecast forecast) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Forecast Analysis', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
          pw.SizedBox(height: 12),
          pw.Text('Monthly Burn Rate: \$${forecast.currentMonthlyBurn.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Projected End-of-Year Spending: \$${forecast.projectedEndOfYear.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Remaining Period: ${forecast.remainingPeriodMonths} months', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Expected Utilization: ${forecast.expectedUtilizationPercent.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Status: ${forecast.isOnTrack ? 'On Track' : 'Over Projected'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: forecast.isOnTrack ? PdfColors.green : PdfColors.red),
          ),
        ],
      ),
    );
  }
}

// CSV Exporter for Excel compatibility
class BudgetCSSEExporter {
  static String generateCSV(List<BudgetLine> budgets, Map<String, double> actualByCategory, String fiscalYear) {
    final lines = <String>[];

    // Header
    lines.add('category,academic_year,planned_amount,actual_spend,variance,utilization_percent');

    // Data rows
    for (final budget in budgets) {
      final actual = actualByCategory[budget.category] ?? 0.0;
      final variance = budget.plannedAmount - actual;
      final utilization = budget.plannedAmount > 0 ? (actual / budget.plannedAmount * 100) : 0.0;

      lines.add(
        '"${escapeCSV(budget.category)}","${budget.academicYear}",${budget.plannedAmount.toStringAsFixed(2)},${actual.toStringAsFixed(2)},${variance.toStringAsFixed(2)},${utilization.toStringAsFixed(1)}',
      );
    }

    // Summary
    if (budgets.isNotEmpty) {
      final totalPlanned = budgets.map((b) => b.plannedAmount).reduce((a, b) => a + b);
      final totalActual = actualByCategory.values.isEmpty ? 0.0 : actualByCategory.values.reduce((a, b) => a + b);
      lines.add('');
      lines.add('TOTAL,,,${totalPlanned.toStringAsFixed(2)},${totalActual.toStringAsFixed(2)},${(totalPlanned - totalActual).toStringAsFixed(2)},${totalPlanned > 0 ? (totalActual / totalPlanned * 100).toStringAsFixed(1) : "0.0"}%');
    }

    return lines.join('\n');
  }

  static String escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return value.replaceAll('"', '""');
    }
    return value;
  }
}
