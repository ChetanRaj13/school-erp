import 'package:flutter/material.dart';

import 'dart:math';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_card.dart';

/// Pie chart for displaying distribution percentages.
class PieChart extends StatelessWidget {
  final Map<String, double> data;
  final String title;
  final List<Color> colors;

  const PieChart({
    super.key,
    required this.data,
    required this.title,
    this.colors = const [AppColors.primary, AppColors.warning, AppColors.error, AppColors.success, AppColors.secondary],
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
          Expanded(child: _PieChartCanvas(data, colors)),
        ],
      ),
    );
  }
}

class _PieChartCanvas extends StatelessWidget {
  final Map<String, double> data;
  final List<Color> colors;

  const _PieChartCanvas(this.data, this.colors);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PieChartPainter(data, colors), size: const Size(double.infinity, double.infinity));
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;

  _PieChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 20;

    // Calculate total
    final total = data.values.reduce((a, b) => a + b);
    if (total <= 0) return;

    double startAngle = -pi / 2; // Start from top (12 o'clock)

    int index = 0;
    for (final entry in data.entries) {
      final value = entry.value;
      final angle = (value / total) * 2 * pi;

      final arcEndAngle = startAngle + angle;

      // Select color (cycle through if more categories than colors)
      final color = colors[index % colors.length];
      final segmentPaint = Paint()..color = color..style = PaintingStyle.fill;

      // Draw the arc segment
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..addArc(Rect.fromCircle(center: center, radius: radius), startAngle, angle)
        ..close();

      canvas.drawPath(path, segmentPaint);

      // Draw percentage label in the middle of the arc
      final midAngle = startAngle + angle / 2;
      final labelRadius = radius * 0.7;
      final labelX = center.dx + labelRadius * cos(midAngle);
      final labelY = center.dy + labelRadius * sin(midAngle);

      final percentText = '${(value / total * 100).round()}%';
      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: percentText,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      );
      textPainter.layout(maxWidth: 60);
      textPainter.paint(canvas, Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2));

      startAngle = arcEndAngle;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
