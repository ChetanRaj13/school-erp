import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'glass_card.dart';
import 'progress_ring.dart';

/// Reusable budget breakdown: per-category planned vs. actual spend with
/// progress rings. Used by both Admin Dashboard and Principal Budget screen
/// to keep the UI identical across roles.
///
/// [budgets] — list of maps from `finance.budgets` with keys:
///   `category` (String), `planned_amount` (num), `academic_year` (String)
/// [actualByCategory] — map of category name → actual spend amount
/// [title] — section header text (defaults to "Budget by Category")
class BudgetBreakdownWidget extends StatelessWidget {
  const BudgetBreakdownWidget({
    super.key,
    required this.budgets,
    required this.actualByCategory,
    this.title = 'Budget by Category',
  });

  final List<Map<String, dynamic>> budgets;
  final Map<String, double> actualByCategory;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (budgets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No budget lines set yet.'),
          )
        else
          ...budgets.map((b) {
            final planned = (b['planned_amount'] as num).toDouble();
            final actual = actualByCategory[b['category']] ?? 0.0;
            final ratio = planned == 0 ? 0.0 : (actual / planned).clamp(0.0, 1.5);
            final over = actual > planned;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Row(
                  children: [
                    ProgressRing(
                      value: ratio.clamp(0.0, 1.0),
                      centerLabel: '${(ratio * 100).toStringAsFixed(0)}%',
                      centerSubtitle: 'used',
                      size: 84,
                      strokeWidth: 8,
                      color: over ? AppColors.error : AppColors.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['category'] as String, style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '₹${actual.toStringAsFixed(0)} of ₹${planned.toStringAsFixed(0)} (${b['academic_year']})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
