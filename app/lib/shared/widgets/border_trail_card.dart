import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Wraps [child] in a card whose border shows a traveling gradient "trail"
/// while [isLoading] is true — e.g. during a data refresh/sync. Flutter port
/// of the `BorderTrail` React component. The trail runs for [loopCount]
/// laps then fades out automatically.
///
/// Usage:
/// ```dart
/// BorderTrailCard(
///   isLoading: _isSyncing,
///   borderRadius: BorderRadius.circular(12),
///   child: Padding(padding: const EdgeInsets.all(16), child: Text('Fee status')),
/// )
/// ```
class BorderTrailCard extends StatefulWidget {
  const BorderTrailCard({
    super.key,
    required this.child,
    required this.isLoading,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.trailColor = const Color(0xFF22C55E), // green-500, matches the reference component
    this.lapDuration = const Duration(seconds: 2),
    this.loopCount = 2,
  });

  final Widget child;
  final bool isLoading;
  final BorderRadius borderRadius;
  final Color trailColor;
  final Duration lapDuration;
  final int loopCount;

  @override
  State<BorderTrailCard> createState() => _BorderTrailCardState();
}

class _BorderTrailCardState extends State<BorderTrailCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _completedLaps = 0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.lapDuration);
    _controller.addStatusListener(_onStatus);
    if (widget.isLoading) _start();
  }

  @override
  void didUpdateWidget(covariant BorderTrailCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) _start();
  }

  void _start() {
    _completedLaps = 0;
    setState(() => _visible = true);
    _controller
      ..reset()
      ..repeat();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _completedLaps++;
      if (_completedLaps >= widget.loopCount) {
        _controller.stop();
        setState(() => _visible = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          widget.child,
          if (_visible)
            AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _TrailPainter(
                    progress: _controller.value,
                    color: widget.trailColor,
                    borderRadius: widget.borderRadius,
                  ),
                   size: const Size(double.infinity, double.infinity),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.progress, required this.color, required this.borderRadius});
  final double progress; // 0..1 around the perimeter
  final Color color;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    const trailLength = 0.18; // fraction of perimeter covered by the glowing segment

    final start = metrics.length * progress;
    final segment = metrics.length * trailLength;

    final extractPath = _extractWrapped(metrics, start, segment);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.0), color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(extractPath, paint);
  }

  Path _extractWrapped(ui.PathMetric metrics, double start, double length) {
    final total = metrics.length;
    final end = start + length;
    if (end <= total) {
      return metrics.extractPath(start, end);
    }
    // Wraps around the end back to the start of the perimeter.
    final firstPart = metrics.extractPath(start, total);
    final secondPart = metrics.extractPath(0, end - total);
    return Path()
      ..addPath(firstPart, Offset.zero)
      ..addPath(secondPart, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) => oldDelegate.progress != progress;
}
