import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// The core card container of the design system.
///
/// Automatically adapts its fill background and borders in both Light and Dark mode.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
    this.blurSigma = AppBlur.glass,
    this.fillColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? borderRadius;
  final double blurSigma;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? AppRadii.card;
    final defaultFill = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : AppColors.glassFill;
    final defaultBorder = isDark ? AppColors.glassBorderDark : AppColors.glassBorder;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor ?? defaultFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: defaultBorder, width: 1.5),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        child: child,
      ),
    );
  }
}

/// A pill-shaped flat chip — used for role badges, status tags, and labels.
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = color ?? (isDark ? const Color(0xFF38BDF8) : AppColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: isDark ? Border.all(color: tint.withValues(alpha: 0.4), width: 1) : null,
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
