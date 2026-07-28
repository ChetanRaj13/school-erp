import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_card.dart';

/// Simple line chart using CustomPainter to visualize trends over time.
class LineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String title;
  final Color chartColor;
  final double? maxValue;

  const LineChart({
    super.key,
    required this.values,
    required this.labels,
    required this.title,
    this.chartColor = AppColors.primary,
    this.maxValue,
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
          Expanded(child: _LineChartCanvas(values: values, labels: labels, chartColor: chartColor, maxValue: maxValue)),
        ],
      ),
    );
  }
}

class _LineChartCanvas extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color chartColor;
  final double? maxValue;

  const _LineChartCanvas({required this.values, required this.labels, required this.chartColor, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(values, labels, chartColor, maxValue),
      size: const Size(double.infinity, double.infinity),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color chartColor;
  final double? maxValue;

  _LineChartPainter(this.values, this.labels, this.chartColor, this.maxValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || labels.length != values.length) return;

    final padding = EdgeInsets.symmetric(vertical: 10, horizontal: 20);
    final usableWidth = size.width - padding.left - padding.right;
    final effectiveMax = maxValue ?? values.asMap().entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (effectiveMax <= 0) return;

    // Draw top and bottom grid lines
    final paint = Paint()..color = AppColors.glassBorder.withAlpha(60)..strokeWidth = 1;
    canvas.drawLine(Offset(padding.left, padding.top), Offset(size.width - padding.right, padding.top), paint);
    canvas.drawLine(Offset(padding.left, size.height - padding.bottom), Offset(size.width - padding.right, size.height - padding.bottom), paint);

    // Draw line path
    if (values.length > 1) {
      final path = Path();
      final xStep = usableWidth / (values.length - 1);

      for (int i = 0; i < values.length; i++) {
        final x = padding.left + i * xStep;
        final normalizedY = values[i] / effectiveMax;
        final yPaddingTop = 10;
        final yPaddingBottom = 10;
        final usableH = size.height - yPaddingTop * 2;
        final y = size.height - yPaddingBottom - normalizedY * usableH;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }

        // Draw point
        final pointPaint = Paint()..color = chartColor..strokeWidth = 3;
        canvas.drawCircle(Offset(x, y), 4, pointPaint);
      }

      // Fill area under line
      path.lineTo(size.width - padding.bottom, size.height - padding.bottom);
      path.lineTo(padding.left, size.height - padding.bottom);
      path.close();

      final areaPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = chartColor.withOpacity(0.15);
      canvas.drawPath(path, areaPaint);

      // Redraw main line on top
      final linePaint = Paint()..color = chartColor..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawPath(path, linePaint);
    }

    // Draw labels at bottom
    const textPadding = 15;
    final labelY = size.height - textPadding;

    final visibleLabels = <int>{0, labels.length - 1};
    if (labels.length >= 3) {
      visibleLabels.add(labels.length ~/ 2);
    }

    for (var i = 0; i < values.length; i++) {
      if (!visibleLabels.contains(i)) continue;

      final x = padding.left + (usableWidth / (values.length - 1)) * i;
      final labelText = labels[i];
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(fontSize: 11, color: Color(0xFF5A6354)),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 40);
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, labelY));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
