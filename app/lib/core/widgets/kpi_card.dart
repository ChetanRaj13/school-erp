import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_card.dart';

/// A KPI (Key Performance Indicator) card with icon, label, value, and optional change indicator.
class KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? changeIndicator; // e.g., '+5.2%', '-2.1%'
  final Color? accentColor;
  final double? progressValue; // For showing utilization gauge (0.0-1.0)

  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.changeIndicator,
    this.accentColor,
    this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progressValue != null)
            SizedBox(
              height: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                child: LinearProgressIndicator(
                  value: progressValue!,
                  backgroundColor: AppColors.glassFill.withAlpha(80),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
              ),
            ),
          if (progressValue != null) const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          if (changeIndicator != null) ...[
            const SizedBox(height: 4),
            Text(
              changeIndicator!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: changeIndicator!.startsWith('+') ? AppColors.success : AppColors.error,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stat grid layout for displaying multiple KPI cards responsively.
class KpiGrid extends StatelessWidget {
  final List<KpiCard> cards;
  final int crossAxisCount;

  const KpiGrid({
    super.key,
    required this.cards,
    this.crossAxisCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => cards[index],
        childCount: cards.length,
      ),
    );
  }
}
