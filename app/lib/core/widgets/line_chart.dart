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
      final linePath = Path();
      final xStep = usableWidth / (values.length - 1);
      final yPaddingTop = 15.0;
      final yPaddingBottom = 25.0;
      final usableH = size.height - yPaddingTop - yPaddingBottom;

      final points = <Offset>[];
      for (int i = 0; i < values.length; i++) {
        final x = padding.left + i * xStep;
        final normalizedY = (values[i] / effectiveMax).clamp(0.0, 1.0);
        final y = size.height - yPaddingBottom - (normalizedY * usableH);
        points.add(Offset(x, y));

        if (i == 0) {
          linePath.moveTo(x, y);
        } else {
          linePath.lineTo(x, y);
        }
      }

      // 1. Fill area under line using a copy of the path
      final fillPath = Path.from(linePath);
      fillPath.lineTo(points.last.dx, size.height - yPaddingBottom);
      fillPath.lineTo(points.first.dx, size.height - yPaddingBottom);
      fillPath.close();

      final areaPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = chartColor.withOpacity(0.15);
      canvas.drawPath(fillPath, areaPaint);

      // 2. Draw line stroke ON TOP (ONLY linePath, not closed fillPath!)
      final linePaint = Paint()
        ..color = chartColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, linePaint);

      // 3. Draw points and value badges on top
      for (int i = 0; i < points.length; i++) {
        final pt = points[i];
        final pointPaint = Paint()..color = chartColor;
        final whitePaint = Paint()..color = Colors.white;
        canvas.drawCircle(pt, 5, pointPaint);
        canvas.drawCircle(pt, 2.5, whitePaint);
      }
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
