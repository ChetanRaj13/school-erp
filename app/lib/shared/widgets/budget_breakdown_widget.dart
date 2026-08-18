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
    final isAllYears = title.contains('All Fiscal Years');
    List<Map<String, dynamic>> effectiveBudgets = budgets;

    if (isAllYears && budgets.isNotEmpty) {
      final categoryMap = <String, Map<String, dynamic>>{};
      for (final b in budgets) {
        final cat = ((b['category'] as String?) ?? 'uncategorized').toLowerCase().trim();
        final planned = (b['planned_amount'] as num?)?.toDouble() ?? 0.0;
        if (!categoryMap.containsKey(cat)) {
          categoryMap[cat] = {
            'category': (b['category'] as String?) ?? 'uncategorized',
            'planned_amount': planned,
            'academic_year': 'All Years Combined',
          };
        } else {
          categoryMap[cat]!['planned_amount'] = (categoryMap[cat]!['planned_amount'] as double) + planned;
        }
      }
      effectiveBudgets = categoryMap.values.toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (effectiveBudgets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No budget lines set for this period.'),
          )
        else
          ...effectiveBudgets.map((b) {
            final cat = (b['category'] as String?) ?? 'uncategorized';
            final catLower = cat.toLowerCase().trim();
            final ay = (b['academic_year'] as String?) ?? '';
            final planned = (b['planned_amount'] as num?)?.toDouble() ?? 0.0;

            // Lookup spend matching category and academic year first, fallback to all-years category sum
            final actual = isAllYears
                ? (actualByCategory[catLower] ?? actualByCategory[cat] ?? 0.0)
                : (actualByCategory['${catLower}_$ay'] ??
                    actualByCategory[catLower] ??
                    actualByCategory[cat] ??
                    0.0);

            final rawRatio = planned == 0 ? 0.0 : (actual / planned);
            final percent = (rawRatio * 100).round();
            final over = actual > planned;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Row(
                  children: [
                    ProgressRing(
                      value: rawRatio.clamp(0.0, 1.0),
                      centerLabel: '$percent%',
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
                          Row(
                            children: [
                              Text(
                                cat.toUpperCase(),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: over ? AppColors.error.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  over ? 'OVER BUDGET' : 'ON TRACK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: over ? AppColors.error : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${actual.toStringAsFixed(0)} spent of ₹${planned.toStringAsFixed(0)} planned (${b['academic_year']})',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: rawRatio.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: AppColors.glassBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                over ? AppColors.error : AppColors.primary,
                              ),
                            ),
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
