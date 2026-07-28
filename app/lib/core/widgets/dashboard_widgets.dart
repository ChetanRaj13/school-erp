import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_card.dart';

/// Pending Approvals Summary Widget with quick action buttons
class ApprovalQueueSummary extends ConsumerWidget {
  final int totalPending;
  final List<Map<String, dynamic>> items;

  const ApprovalQueueSummary({
    super.key,
    required this.totalPending,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions_outlined, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('Approval Queue', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          if (totalPending > 0)
            Text('$totalPending items requiring attention', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (items.isNotEmpty) ..._buildApprovalList(context, items),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Nothing to approve right now.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildApprovalList(BuildContext context, List<Map<String, dynamic>> items) {
    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['type'] as String, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${item['amount']?.toStringAsFixed(2) ?? ''}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.view_list_outlined, size: 18, color: AppColors.primary),
                tooltip: 'View details',
                onPressed: () => GoRouter.of(context).go(item['route'] as String),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

/// Upcoming Fee Deadlines Widget
class UpcomingFeeDeadlines extends StatelessWidget {
  final List<Map<String, dynamic>> deadlines;

  const UpcomingFeeDeadlines({super.key, required this.deadlines});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Upcoming Deadlines', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (deadlines.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No upcoming deadlines.'))
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: deadlines.map((d) {
                final dueDate = DateTime.tryParse(d['due_date'] as String);
                final daysUntil = dueDate != null ? DateTime.now().difference(dueDate).inDays : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: daysUntil <= 3 ? AppColors.error.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                        child: Icon(
                          daysUntil <= 3 ? Icons.warning_rounded : Icons.calendar_today_rounded,
                          size: 16,
                          color: daysUntil <= 3 ? AppColors.error : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['studentName'] as String, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                             Text('₹${(d['amountDue'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'} · Due ${_formatDate(dueDate ?? DateTime.now())}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year.toString().substring(2)}';
  }
}

/// Top Fee Defaulters Widget
class TopFeeDefaulters extends StatelessWidget {
  final List<Map<String, dynamic>> defaulters;

  const TopFeeDefaulters({super.key, required this.defaulters});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.money_off_outlined, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text('Top Defaulters', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (defaulters.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No defaulters recorded.'))
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: defaulters.map((d) {
                final index = defaulters.indexOf(d) + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == 1 ? AppColors.primary.withOpacity(0.2) : AppColors.glassFill,
                          border: Border.all(color: index == 1 ? AppColors.primary : AppColors.glassBorder),
                        ),
                        child: Center(
                          child: Text(
                            '$index',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: index == 1 ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['studentName'] as String, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                             Text('₹${(d['amountDue'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
