import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_card.dart';

/// Bar chart for comparing values across categories.
class BarChart extends StatelessWidget {
  final Map<String, double> data;
  final String title;
  final Color? primaryColor;
  final bool showValues;
  final String valuePrefix;
  final String valueSuffix;
  final String Function(double)? valueFormatter;
  final bool wrapInCard;

  const BarChart({
    super.key,
    required this.data,
    this.title = '',
    this.primaryColor = AppColors.primary,
    this.showValues = true,
    this.valuePrefix = '',
    this.valueSuffix = '',
    this.valueFormatter,
    this.wrapInCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final canvas = _BarChartCanvas(
      data,
      primaryColor: primaryColor ?? AppColors.primary,
      showValues: showValues,
      valuePrefix: valuePrefix,
      valueSuffix: valueSuffix,
      valueFormatter: valueFormatter,
    );

    if (!wrapInCard || title.isEmpty) {
      return canvas;
    }

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(child: canvas),
        ],
      ),
    );
  }
}

class _BarChartCanvas extends StatelessWidget {
  final Map<String, double> data;
  final Color primaryColor;
  final bool showValues;
  final String valuePrefix;
  final String valueSuffix;
  final String Function(double)? valueFormatter;

  const _BarChartCanvas(
    this.data, {
    required this.primaryColor,
    required this.showValues,
    required this.valuePrefix,
    required this.valueSuffix,
    this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(
        data,
        primaryColor,
        showValues,
        valuePrefix: valuePrefix,
        valueSuffix: valueSuffix,
        valueFormatter: valueFormatter,
      ),
      size: const Size(double.infinity, double.infinity),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final Map<String, double> data;
  final Color primaryColor;
  final bool showValues;
  final String valuePrefix;
  final String valueSuffix;
  final String Function(double)? valueFormatter;

  _BarChartPainter(
    this.data,
    Color? primaryColor,
    this.showValues, {
    this.valuePrefix = '',
    this.valueSuffix = '',
    this.valueFormatter,
  }) : primaryColor = primaryColor ?? AppColors.primary;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final categoryCount = data.keys.length;
    if (categoryCount == 0) return;

    final topPadding = showValues ? 22.0 : 8.0;
    const bottomPadding = 28.0; // Dedicated space for x-axis category labels below the baseline
    const horizontalPadding = 18.0;

    final usableWidth = (size.width - (horizontalPadding * 2)).clamp(10.0, double.infinity);
    final chartHeight = (size.height - topPadding - bottomPadding).clamp(10.0, double.infinity);
    final baselineY = size.height - bottomPadding;

    final maxValue = data.values.fold<double>(0.0, (max, v) => v > max ? v : max);
    if (maxValue <= 0) return;

    // Draw baseline
    final axisPaint = Paint()
      ..color = AppColors.glassBorder.withValues(alpha: 0.8)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(horizontalPadding, baselineY), Offset(size.width - horizontalPadding, baselineY), axisPaint);

    // Draw top reference grid line
    final gridPaint = Paint()
      ..color = AppColors.glassBorder.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(horizontalPadding, topPadding), Offset(size.width - horizontalPadding, topPadding), gridPaint);

    final barSpacing = (usableWidth / (categoryCount * 4)).clamp(8.0, 20.0);
    final totalSpacing = (categoryCount - 1) * barSpacing;
    final barWidth = ((usableWidth - totalSpacing) / categoryCount).clamp(12.0, 64.0);

    // Center the group of bars horizontally
    final totalBarsWidth = (categoryCount * barWidth) + totalSpacing;
    final startX = horizontalPadding + ((usableWidth - totalBarsWidth) / 2).clamp(0.0, double.infinity);

    int index = 0;
    for (final entry in data.entries) {
      final value = entry.value;
      final ratio = (value / maxValue).clamp(0.0, 1.0);
      final barHeight = (ratio * chartHeight).clamp(0.0, chartHeight);
      final x = startX + index * (barWidth + barSpacing);
      final y = baselineY - barHeight;

      // Draw bar with rounded top corners
      final barPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      final barRect = Rect.fromLTWH(x, y, barWidth, barHeight);
      final rrect = RRect.fromRectAndCorners(
        barRect,
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      canvas.drawRRect(rrect, barPaint);

      // Draw value label above bar if enabled
      if (showValues) {
        final formattedValue = valueFormatter != null
            ? valueFormatter!(value)
            : (valuePrefix.isEmpty && valueSuffix.isEmpty
                ? value.toStringAsFixed(0)
                : '$valuePrefix${value.toStringAsFixed(0)}$valueSuffix');

        final textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: formattedValue,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        )..layout();

        final labelX = x + (barWidth - textPainter.width) / 2;
        final labelY = (y - textPainter.height - 3).clamp(0.0, baselineY - textPainter.height);
        textPainter.paint(canvas, Offset(labelX, labelY));
      }

      // Draw X-axis category label clearly below the baseline
      final label = entry.key;
      final labelPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      )..layout(maxWidth: barWidth + barSpacing + 8);

      final categoryX = x + (barWidth - labelPainter.width) / 2;
      final categoryY = baselineY + 6.0;
      labelPainter.paint(canvas, Offset(categoryX, categoryY));

      index++;
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.showValues != showValues ||
        oldDelegate.valuePrefix != valuePrefix ||
        oldDelegate.valueSuffix != valueSuffix;
  }
}
