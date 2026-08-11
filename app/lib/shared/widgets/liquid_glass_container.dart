import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';

/// Flutter port of the `.liquid-glass` CSS effect: a near-transparent blurred
/// surface with a subtle gradient hairline border (top/bottom brighter than
/// the sides, mimicking the CSS mask/xor border trick).
///
/// Usage:
/// ```dart
/// LiquidGlassContainer(
///   borderRadius: BorderRadius.circular(999),
///   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
///   child: Text('Begin Journey'),
/// )
/// ```
class LiquidGlassContainer extends StatelessWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = const EdgeInsets.all(16),
    this.blurSigma = 4,
    this.fillOpacity = 0.01,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final double blurSigma;
  final double fillOpacity;

  @override
  Widget build(BuildContext context) {
    final content = CustomPaint(
      painter: _GradientBorderPainter(borderRadius: borderRadius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: fillOpacity),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.1),
              blurRadius: 1,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: child,
      ),
    );

    if (kIsWeb) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );
  }
}

/// Paints a 1.4px gradient hairline border — brighter at the top and bottom
/// edges, fading to nothing at the sides — approximating the CSS
/// `linear-gradient` + `mask-composite: exclude` border trick.
class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({required this.borderRadius});
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x73FFFFFF), // rgba(255,255,255,0.45)
          Color(0x26FFFFFF), // rgba(255,255,255,0.15) @ 20%
          Color(0x00FFFFFF), // transparent @ 40%
          Color(0x00FFFFFF), // transparent @ 60%
          Color(0x26FFFFFF), // rgba(255,255,255,0.15) @ 80%
          Color(0x73FFFFFF), // rgba(255,255,255,0.45)
        ],
        stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(rrect.deflate(0.7), paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) => false;
}
