import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/background_preset_provider.dart';
import '../../core/theme/background_presets.dart';

/// UPDATED: real preset images now exist, each with a separate desktop and mobile
/// version (a 16:9 landscape image and a 9:16 portrait image showing the SAME scene,
/// not one image stretched/cropped to fit both). This picks the right one based on
/// actual screen width at render time — 800px is the breakpoint (a plain width check
/// is enough here; it doesn't need to match RoleShell's own nav breakpoint exactly,
/// since this is a purely visual decision, not a layout one).
///
/// Falls back to the original procedural hill/tree painter if a preset has no image
/// path set (kept for robustness / any future preset added before its real art
/// exists), or if the image somehow fails to load.
class WarmBackdrop extends ConsumerWidget {
  const WarmBackdrop({super.key, required this.child});

  final Widget child;

  static const double _desktopBreakpoint = 800;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetId = ref.watch(backgroundPresetProvider);
    final preset = presetById(presetId);
    final isWide = MediaQuery.of(context).size.width >= _desktopBreakpoint;
    final imagePath = isWide ? preset.imagePathDesktop : preset.imagePathMobile;

    return Stack(
      children: [
        Positioned.fill(
          child: imagePath != null
              ? Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _ProceduralBackdrop(preset: preset),
                )
              : _ProceduralBackdrop(preset: preset),
        ),
        child,
      ],
    );
  }
}

/// The original abstract geometric backdrop — soft hill silhouettes + glow, tinted
/// per preset. Used as a fallback, not the primary path, now that real images exist.
class _ProceduralBackdrop extends StatelessWidget {
  const _ProceduralBackdrop({required this.preset});
  final BackgroundPreset preset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: preset.baseColor),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [preset.glowColor.withValues(alpha: 0.35), preset.glowColor.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 260),
              painter: _HillPainter(color: preset.hillColor.withValues(alpha: 0.25), heightFactor: 0.55, waveOffset: 0.0),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 200),
              painter: _HillPainter(color: preset.hillColor.withValues(alpha: 0.16), heightFactor: 0.4, waveOffset: 0.3),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 140),
              painter: _HillPainter(color: AppColors.backgroundAlt, heightFactor: 0.6, waveOffset: 0.6),
            ),
          ),
          Positioned(
            bottom: 24, left: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _TreeSilhouette(height: 46, color: preset.hillColor.withValues(alpha: 0.30)),
                const SizedBox(width: 8),
                _TreeSilhouette(height: 64, color: preset.hillColor.withValues(alpha: 0.22)),
                const SizedBox(width: 6),
                _TreeSilhouette(height: 38, color: preset.hillColor.withValues(alpha: 0.30)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HillPainter extends CustomPainter {
  _HillPainter({required this.color, required this.heightFactor, required this.waveOffset});
  final Color color;
  final double heightFactor;
  final double waveOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    final baseY = size.height * (1 - heightFactor);
    path.moveTo(0, size.height);
    path.lineTo(0, baseY + 20);
    path.quadraticBezierTo(size.width * (0.25 + waveOffset * 0.1), baseY - 30, size.width * 0.5, baseY);
    path.quadraticBezierTo(size.width * (0.75 - waveOffset * 0.1), baseY + 30, size.width, baseY - 10);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HillPainter oldDelegate) => oldDelegate.color != color;
}

class _TreeSilhouette extends StatelessWidget {
  const _TreeSilhouette({required this.height, required this.color});
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: height * 0.6, child: CustomPaint(painter: _TreePainter(color: color)));
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(0, size.height * 0.7)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.4, size.height * 0.7, size.width * 0.2, size.height * 0.3), paint);
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) => oldDelegate.color != color;
}
