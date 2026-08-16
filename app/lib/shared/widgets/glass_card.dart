import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// The core visual primitive of the new "Contra kit" flat design language: a solid
// card with a rounded corner and a thin hairline border — no blur, no gradient, no
// drop shadow. Every card, nav tile, and input surface across the app uses this, so
// retuning AppColors.glassFill / glassBorder / AppRadii.card in app_theme.dart
// re-styles all of them at once.
//
// The class is still called GlassCard (not renamed) on purpose: 49 files construct
// GlassCard(...) directly, and none of them need to change for this migration —
// only what happens inside build() changes.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
    this.blurSigma = AppBlur.glass, // kept for API compatibility, intentionally unused
    this.fillColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? borderRadius;
  final double blurSigma;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadii.card;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor ?? AppColors.glassFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassBorder, width: 1.5),
        // Deliberately no boxShadow — the flat system uses color/border/spacing for
        // depth, never shadow. AppColors.glassShadow is zeroed at the source too, in
        // case anything still references it directly.
      ),
      child: child,
    );
  }
}

/// A pill-shaped flat chip — used for the role badge, status tags, small labels.
/// Same public API as before; internals now render a flat solid-or-tinted pill
/// instead of a frosted-glass one.
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        // A light tint of whatever color is passed, so chips read as "colored" per
        // the design system without needing every call site to pass two colors.
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tint),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}
