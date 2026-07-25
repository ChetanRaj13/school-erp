import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// The core visual primitive of this design language: a frosted-glass panel — blurred
/// backdrop + semi-transparent warm-white fill + soft border + soft shadow. Every card,
/// nav bar, and input surface in the redesigned screens should use this rather than a
/// plain Card, to keep the glass effect consistent everywhere instead of
/// hand-implemented per screen.
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
    final radius = borderRadius ?? AppRadii.card;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fillColor ?? AppColors.glassFill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.glassBorder, width: 1),
            boxShadow: const [
              BoxShadow(color: AppColors.glassShadow, blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A pill-shaped glass chip — used for the role badge, status tags, small labels.
/// Same glass treatment as GlassCard but pre-shaped for inline/compact use.
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppBlur.glass, sigmaY: AppBlur.glass),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color ?? AppColors.primary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
