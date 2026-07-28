import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_card.dart';

/// Bar chart for comparing values across categories.
class BarChart extends StatelessWidget {
  final Map<String, double> data;
  final String title;
  final Color? primaryColor;
  final bool showValues;

  const BarChart({
    super.key,
    required this.data,
    required this.title,
    this.primaryColor = AppColors.primary,
    this.showValues = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Expanded(child: _BarChartCanvas(data, primaryColor: primaryColor ?? AppColors.primary, showValues: showValues)),
        ],
      ),
    );
  }
}

class _BarChartCanvas extends StatelessWidget {
  final Map<String, double> data;
  final Color primaryColor;
  final bool showValues;

  const _BarChartCanvas(this.data, {required this.primaryColor, required this.showValues});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BarChartPainter(data, primaryColor, showValues), size: const Size(double.infinity, double.infinity));
  }
}

class _BarChartPainter extends CustomPainter {
  final Map<String, double> data;
  final Color primaryColor;
  final bool showValues;

  _BarChartPainter(this.data, Color? primaryColor, this.showValues) : primaryColor = primaryColor ?? AppColors.primary;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final padding = EdgeInsets.symmetric(vertical: 10, horizontal: 30);
    final usableWidth = size.width - padding.left - padding.right;
    final maxValue = data.values.reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) return;

    final categoryCount = data.keys.length;
    const barSpacing = 16;
    final barWidth = (usableWidth - (categoryCount - 1) * barSpacing) / categoryCount;

    // Draw top grid line
    final gridPaint = Paint()..color = AppColors.glassBorder.withAlpha(60)..strokeWidth = 1;
    canvas.drawLine(Offset(padding.left, padding.top), Offset(size.width - padding.right, padding.top), gridPaint);

    int index = 0;
    for (final entry in data.entries) {
      final value = entry.value;
      final ratio = value / maxValue;
      const gap = 10;
      final usableH = size.height - gap * 2;
      final barHeight = ratio * usableH;
      final x = padding.left + index * (barWidth + barSpacing);
      final yFromBottom = gap;
      final y = size.height - yFromBottom - barHeight;

      // Draw bar
      final barPaint = Paint()..color = primaryColor..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), barPaint);

      // Draw value label on top of bar if enabled
      if (showValues && barHeight > 20) {
        final textPainter = TextPainter(textDirection: TextDirection.ltr)
          ..text = TextSpan(
            text: '₹${value.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF2B332A)),
          )
          ..layout(maxWidth: barWidth);
        textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, y - 15));
      }

      // Draw category label at bottom
      final label = entry.key;
      final labelY = size.height - 5;
      final labelPainter = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF5A6354)),
        )
        ..layout(maxWidth: barWidth * 0.8);
      labelPainter.paint(canvas, Offset(x + (barWidth - labelPainter.width) / 2, labelY - 25));

      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
