import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Stat card primitive adapting dynamically to light and dark theme mode.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = color ?? (isDark ? const Color(0xFF38BDF8) : AppColors.primary);
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.backgroundAlt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: isDark ? Border.all(color: AppColors.glassBorderDark, width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tint),
            ),
          ],
        ],
      ),
    );
  }
}
