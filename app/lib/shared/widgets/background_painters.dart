import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/background_theme_provider.dart';

/// Renders geometric dot matrix or minimal vector landscape artwork.
class BackgroundPatternWidget extends StatelessWidget {
  const BackgroundPatternWidget({
    super.key,
    required this.type,
    this.accentColor,
    this.isDark = false,
  });

  final BackgroundPatternType type;
  final Color? accentColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case BackgroundPatternType.none:
        return const SizedBox.shrink();
      case BackgroundPatternType.dotMatrix:
        return CustomPaint(
          painter: _DotMatrixPainter(
            dotColor: accentColor ?? const Color(0xFF94A3B8).withValues(alpha: 0.25),
          ),
          size: Size.infinite,
        );
      case BackgroundPatternType.alpinePeaks:
        return CustomPaint(
          painter: _AlpinePeaksPainter(),
          size: Size.infinite,
        );
      case BackgroundPatternType.desertDunes:
        return CustomPaint(
          painter: _DesertDunesPainter(),
          size: Size.infinite,
        );
      case BackgroundPatternType.forestLake:
        return CustomPaint(
          painter: _ForestLakePainter(),
          size: Size.infinite,
        );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. PATTERN PAINTERS
// ═════════════════════════════════════════════════════════════════════════════

class _DotMatrixPainter extends CustomPainter {
  _DotMatrixPainter({required this.dotColor});
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const radius = 1.3;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter oldDelegate) => oldDelegate.dotColor != dotColor;
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. MINIMAL VECTOR LANDSCAPE PAINTERS
// ═════════════════════════════════════════════════════════════════════════

class _AlpinePeaksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft morning sun glow
    final sunPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.65, -0.6),
        radius: 0.45,
        colors: [
          const Color(0xFFFDE68A).withValues(alpha: 0.35),
          const Color(0xFFFEF3C7).withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sunPaint);

    // Distant mountain range
    final bgMountains = Path()
      ..moveTo(0, h * 0.72)
      ..lineTo(w * 0.15, h * 0.58)
      ..lineTo(w * 0.32, h * 0.68)
      ..lineTo(w * 0.52, h * 0.52)
      ..lineTo(w * 0.72, h * 0.65)
      ..lineTo(w * 0.88, h * 0.48)
      ..lineTo(w, h * 0.60)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final bgPaint = Paint()
      ..color = const Color(0xFFBAE6FD).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bgMountains, bgPaint);

    // Mid mountain range
    final midMountains = Path()
      ..moveTo(0, h * 0.80)
      ..lineTo(w * 0.22, h * 0.65)
      ..lineTo(w * 0.42, h * 0.76)
      ..lineTo(w * 0.68, h * 0.60)
      ..lineTo(w * 0.85, h * 0.72)
      ..lineTo(w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final midPaint = Paint()
      ..color = const Color(0xFF7DD3FC).withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawPath(midMountains, midPaint);

    // Foreground rolling ridge with mist
    final fgRidge = Path()
      ..moveTo(0, h * 0.86)
      ..cubicTo(w * 0.25, h * 0.82, w * 0.45, h * 0.90, w * 0.75, h * 0.84)
      ..cubicTo(w * 0.88, h * 0.82, w * 0.95, h * 0.88, w, h * 0.86)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fgPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fgRidge, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _AlpinePeaksPainter oldDelegate) => false;
}

class _DesertDunesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Atmospheric warm sunset glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.3, -0.7),
        radius: 0.55,
        colors: [
          const Color(0xFFFDE68A).withValues(alpha: 0.40),
          const Color(0xFFFED7AA).withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);

    // Background Dune 1
    final dune1 = Path()
      ..moveTo(0, h * 0.65)
      ..cubicTo(w * 0.35, h * 0.55, w * 0.65, h * 0.75, w, h * 0.60)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      dune1,
      Paint()
        ..color = const Color(0xFFFDE68A).withValues(alpha: 0.30)
        ..style = PaintingStyle.fill,
    );

    // Mid Dune 2
    final dune2 = Path()
      ..moveTo(0, h * 0.76)
      ..cubicTo(w * 0.40, h * 0.82, w * 0.60, h * 0.68, w, h * 0.74)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      dune2,
      Paint()
        ..color = const Color(0xFFFCD34D).withValues(alpha: 0.28)
        ..style = PaintingStyle.fill,
    );

    // Foreground Dune 3
    final dune3 = Path()
      ..moveTo(0, h * 0.85)
      ..cubicTo(w * 0.30, h * 0.80, w * 0.70, h * 0.92, w, h * 0.84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      dune3,
      Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _DesertDunesPainter oldDelegate) => false;
}

class _ForestLakePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Distant mountain silhouette
    final mountains = Path()
      ..moveTo(0, h * 0.68)
      ..lineTo(w * 0.20, h * 0.58)
      ..lineTo(w * 0.45, h * 0.66)
      ..lineTo(w * 0.70, h * 0.55)
      ..lineTo(w * 0.90, h * 0.64)
      ..lineTo(w, h * 0.60)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      mountains,
      Paint()
        ..color = const Color(0xFFA7F3D0).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );

    // Pine treeline
    final treePaint = Paint()
      ..color = const Color(0xFF059669).withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    const treeCount = 24;
    final treeSpacing = w / treeCount;
    final treeBaseline = h * 0.78;

    for (int i = 0; i <= treeCount; i++) {
      final x = i * treeSpacing;
      final treeHeight = 28.0 + (math.sin(i * 1.5) * 12.0);
      final treePath = Path()
        ..moveTo(x, treeBaseline)
        ..lineTo(x - 8, treeBaseline)
        ..lineTo(x, treeBaseline - treeHeight)
        ..lineTo(x + 8, treeBaseline)
        ..close();
      canvas.drawPath(treePath, treePaint);
    }

    // Reflective calm water surface
    final lake = Path()
      ..moveTo(0, treeBaseline)
      ..lineTo(w, treeBaseline)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final lakePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6EE7B7).withValues(alpha: 0.18),
          const Color(0xFFA7F3D0).withValues(alpha: 0.30),
        ],
      ).createShader(Rect.fromLTWH(0, treeBaseline, w, h - treeBaseline));
    canvas.drawPath(lake, lakePaint);
  }

  @override
  bool shouldRepaint(covariant _ForestLakePainter oldDelegate) => false;
}
