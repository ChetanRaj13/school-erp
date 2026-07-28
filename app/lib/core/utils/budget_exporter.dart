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
          children: [
            _buildHeader(context, title, fiscalYear, generatedAt),
            pw.Expanded(child: _buildKPISection(context, kpis)),
            pw.SizedBox(height: 20),
            _buildCategoriesTable(context, categories),
            if (forecast != null) ...[
              pw.SizedBox(height: 20),
              _buildForecastSection(context, forecast),
            ],
          ],
        ),
      ),
    );

    // Add audit trail page (brief)
    // TODO: Include detailed audit trail in separate page

    final bytes = pdf.save();
    // Return path where file was saved or the bytes
    // In practice, you'd save this to a file or provide download
    return 'budget_report_$fiscalYear_${DateFormat('yyyyMMdd_HHmmss').format(generatedAt)}.pdf';
  }

  static pw.Widget _buildHeader(BuildContext context, String title, String fiscalYear, DateTime generatedAt) {
    return pw.Padding(
      padding: const EdgeInsets.all(16),
      child: pw.Row(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Budget Report', style: pw.TextStyle(fontSize: 16, color: pw.Colors.grey)),
            ],
          ),
          pw.Expanded(
            child: pw.Alignment(
              alignment: pw.Alignment.topRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Fiscal Year: $fiscalYear', style: pw.TextStyle(fontSize: 14)),
                  pw.Text('Generated: ${DateFormat('MMM d, yyyy - HH:mm').format(generatedAt)}', style: pw.TextStyle(fontSize: 12, color: pw.Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKPISection(BuildContext context, List<BudgetKPI> kpis) {
    return pw.Container(
      padding: const EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: pw.Colors.blueGrey.shade50, border: pw.Border.all(pw.Colors.blueGrey.shade300)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Key Performance Indicators', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Grid.count(
            4,
            children: kpis.map((kpi) => pw.Card(
              child: pw.Padding(
                padding: const EdgeInsets.all(12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(kpi.label, style: pw.TextStyle(fontSize: 12, color: pw.Colors.grey)),
                    pw.SizedBox(height: 8),
                    pw.Text(kpi.value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _getKPIColor(kpi.status))),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Color _getKPIColor(String status) {
    if (status == 'critical') return pw.Colors.red;
    if (status == 'warning') return pw.Colors.orange;
    return pw.Colors.green;
  }

  static pw.Widget _buildCategoriesTable(BuildContext context, List<BudgetCategory> categories) {
    return pw.Padding(
      padding: const EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Budget by Category', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: pw.Colors.grey.shade300),
            children: [
              pw.TableRow(
                children: [
                  pw.Cell(child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, backgroundColor: pw.Colors.blueGrey))),
                  pw.Cell(child: pw.Text('Planned', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, backgroundColor: pw.Colors.blueGrey))),
                  pw.Cell(child: pw.Text('Actual', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, backgroundColor: pw.Colors.blueGrey))),
                  pw.Cell(child: pw.Text('Variance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, backgroundColor: pw.Colors.blueGrey))),
                  pw.Cell(child: pw.Text('Utilization', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, backgroundColor: pw.Colors.blueGrey))),
                ],
              ),
              ...categories.map((cat) => pw.TableRow(
                children: [
                  pw.Cell(child: pw.Text(cat.category)),
                  pw.Cell(child: pw.Text('\$${cat.planned.toStringAsFixed(0)}')),
                  pw.Cell(child: pw.Text('\$${cat.actual.toStringAsFixed(0)}')),
                  pw.Cell(child: pw.Text('\$${(cat.planned - cat.actual).toStringAsFixed(0)}',
                    style: pw.TextStyle(color: cat.planned >= cat.actual ? pw.Colors.green : pw.Colors.red))),
                  pw.Cell(child: pw.Text('${(cat.utilization * 100).toStringAsFixed(1)}%')),
                ],
              )),
              // Total row
              pw.TableRow(
                children: [
                  pw.Cell(child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Cell(child: pw.Text('\$${categories.fold(0, (sum, c) => sum + c.planned).toStringAsFixed(0)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Cell(child: pw.Text('\$${categories.fold(0, (sum, c) => sum + c.actual).toStringAsFixed(0)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Cell(child: pw.Text('\$${(categories.fold(0, (sum, c) => sum + c.planned) - categories.fold(0, (sum, c) => sum + c.actual)).toStringAsFixed(0)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Cell(child: pw.Text('',)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildForecastSection(BuildContext context, BudgetForecast forecast) {
    return pw.Padding(
      padding: const EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: pw.Colors.amber.shade50, border: pw.Border.all(pw.Colors.amber.shade300)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Forecast Analysis', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: pw.Colors.amber.darkenBy(0.5))),
          pw.SizedBox(height: 12),
          pw.Text('Monthly Burn Rate: \$${forecast.currentMonthlyBurn.toStringAsFixed(0)}'),
          pw.Text('Projected End-of-Year Spending: \${forecast.projectedEndOfYear.toStringAsFixed(0)}'),
          pw.Text('Remaining Period: ${forecast.remainingPeriodMonths} months'),
          pw.Text('Expected Utilization: ${forecast.expectedUtilizationPercent.toStringAsFixed(1)}%'),
          pw.Text('Status: ${forecast.isOnTrack ? 'On Track' : 'Over Projected'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: forecast.isOnTrack ? pw.Colors.green : pw.Colors.red)),
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
      final utilization = budget.plannedAmount > 0 ? (actual / budget.plannedAmount * 100) : 0;

      lines.add(
        '"${budget.category.replaceDoubleQuotes('"')}","${budget.academicYear}",${budget.plannedAmount.toStringAsFixed(2)},${actual.toStringAsFixed(2)},${variance.toStringAsFixed(2)},${utilization.toStringAsFixed(1)}',
      );
    }

    // Summary
    final totalPlanned = budgets.map((b) => b.plannedAmount).reduce((a, b) => a + b);
    final totalActual = actualByCategory.values.reduce((a, b) => a + b);
    lines.add('');
    lines.add('TOTAL,,,${totalPlanned.toStringAsFixed(2)},${totalActual.toStringAsFixed(2)},${(totalPlanned - totalActual).toStringAsFixed(2)},${(totalActual / totalPlanned * 100).toStringAsFixed(1)}%');

    return '\n'.join(lines);
  }

  static String escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '\"' + value.replaceAll('"', '""') + '\"';
    }
    return value;
  }
}

extension StringExtension on String {
  String replaceDoubleQuotes(String replace) {
    return this.replaceAll('"', replace);
  }
}
