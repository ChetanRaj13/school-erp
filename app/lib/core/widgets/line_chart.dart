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
  final bool wrapInCard;

  const LineChart({
    super.key,
    required this.values,
    required this.labels,
    this.title = '',
    this.chartColor = AppColors.primary,
    this.maxValue,
    this.wrapInCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final canvas = _LineChartCanvas(values: values, labels: labels, chartColor: chartColor, maxValue: maxValue);
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
    if (values.isEmpty) return;

    // Normalize labels to match values length if count differs
    final safeLabels = List<String>.generate(values.length, (i) {
      if (i < labels.length && labels[i].isNotEmpty) return labels[i];
      return 'T${i + 1}';
    });

    final padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 24);
    final usableWidth = (size.width - padding.left - padding.right).clamp(10.0, double.infinity);
    final effectiveMax = maxValue ?? values.asMap().entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    if (effectiveMax <= 0) return;

    // Draw top and bottom grid lines
    final gridPaint = Paint()..color = AppColors.glassBorder.withValues(alpha: 0.6)..strokeWidth = 1;
    canvas.drawLine(Offset(padding.left, padding.top), Offset(size.width - padding.right, padding.top), gridPaint);
    canvas.drawLine(Offset(padding.left, size.height - padding.bottom), Offset(size.width - padding.right, size.height - padding.bottom), gridPaint);

    final yPaddingTop = 18.0;
    final yPaddingBottom = 32.0;
    final usableH = (size.height - yPaddingTop - yPaddingBottom).clamp(10.0, double.infinity);

    // Draw line path and points
    if (values.length > 1) {
      final linePath = Path();
      final xStep = usableWidth / (values.length - 1);

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

      // 1. Fill area under line
      final fillPath = Path.from(linePath);
      fillPath.lineTo(points.last.dx, size.height - yPaddingBottom);
      fillPath.lineTo(points.first.dx, size.height - yPaddingBottom);
      fillPath.close();

      final areaPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = chartColor.withValues(alpha: 0.14);
      canvas.drawPath(fillPath, areaPaint);

      // 2. Draw line stroke on top
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

        // Draw score value above point (skip some value tags if too dense)
        final showVal = values.length <= 6 || i == 0 || i == values.length - 1 || (i % 2 == 0);
        if (showVal) {
          final valPainter = TextPainter(
            text: TextSpan(
              text: '${values[i].toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: chartColor),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          valPainter.paint(canvas, Offset(pt.dx - valPainter.width / 2, pt.dy - 16));
        }
      }
    } else {
      // Single data point: Draw centered circle with score
      final centerX = size.width / 2;
      final normalizedY = (values[0] / effectiveMax).clamp(0.0, 1.0);
      final centerY = size.height - yPaddingBottom - (normalizedY * usableH);
      final pt = Offset(centerX, centerY);

      // Horizontal guideline
      final dashPaint = Paint()..color = chartColor.withValues(alpha: 0.3)..strokeWidth = 1.5;
      canvas.drawLine(Offset(padding.left, centerY), Offset(size.width - padding.right, centerY), dashPaint);

      final pointPaint = Paint()..color = chartColor;
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawCircle(pt, 7, pointPaint);
      canvas.drawCircle(pt, 3.5, whitePaint);

      final valPainter = TextPainter(
        text: TextSpan(
          text: '${values[0].toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: chartColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valPainter.paint(canvas, Offset(pt.dx - valPainter.width / 2, pt.dy - 18));
    }

    // Draw labels at bottom with intelligent collision prevention
    final labelY = size.height - 20;

    if (values.length > 1) {
      final xStep = usableWidth / (values.length - 1);
      final int stepInterval = xStep < 46 ? (xStep < 28 ? 3 : 2) : 1;

      for (var i = 0; i < values.length; i++) {
        // When dense, render first, last, and every stepInterval
        final shouldRender = (i == 0 || i == values.length - 1 || (i % stepInterval == 0));
        if (!shouldRender) continue;

        final x = padding.left + i * xStep;
        final rawText = safeLabels[i];
        final labelText = _formatCleanLabel(rawText);

        final textPainter = TextPainter(
          text: TextSpan(
            text: labelText,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF5A6354)),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 60);

        // Keep label inside chart bounds
        var drawX = x - textPainter.width / 2;
        if (drawX < padding.left / 2) drawX = padding.left / 2;
        if (drawX + textPainter.width > size.width - padding.right / 2) {
          drawX = size.width - padding.right / 2 - textPainter.width;
        }

        textPainter.paint(canvas, Offset(drawX, labelY));
      }
    } else {
      final labelText = _formatCleanLabel(safeLabels[0]);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF5A6354)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, labelY));
    }
  }

  String _formatCleanLabel(String raw) {
    if (raw.isEmpty) return '';
    // YYYY-MM format like '2025-11' or '2026-02'
    final ymRegex = RegExp(r'^\d{4}-(\d{2})$');
    final ymMatch = ymRegex.firstMatch(raw);
    if (ymMatch != null) {
      final m = int.tryParse(ymMatch.group(1)!) ?? 1;
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      if (m >= 1 && m <= 12) return months[m];
    }

    // YYYY-MM-DD format like '2026-02-14'
    final ymdRegex = RegExp(r'^\d{4}-(\d{2})-(\d{2})$');
    final ymdMatch = ymdRegex.firstMatch(raw);
    if (ymdMatch != null) {
      final m = int.tryParse(ymdMatch.group(1)!) ?? 1;
      final d = ymdMatch.group(2)!;
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      if (m >= 1 && m <= 12) return '$d ${months[m]}';
    }

    return raw;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
