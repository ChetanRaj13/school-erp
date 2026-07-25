import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Budget — planned vs. actual spend, per category. finance.budgets holds the PLANNED
/// amount per category/academic_year; "actual" is computed live from real
/// finance.purchase_orders (grouped by category) — not stored anywhere, always fresh.
///
/// HONEST SCOPE: only purchase-order spend is included in "actual" — payroll isn't
/// categorized the same way (it's per-employee, not per-category), so it's shown as a
/// separate total rather than folded into the category breakdown. A more complete
/// budget view would need a consistent category taxonomy across both, which doesn't
/// exist yet — flagged rather than silently mixed together incorrectly.
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  late Future<_BudgetData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BudgetData> _load() async {
    final client = ref.read(supabaseClientProvider);

    final budgets = await client
        .schema('finance')
        .from('budgets')
        .select('id, category, academic_year, planned_amount')
        .order('category');

    final orders = await client.schema('finance').from('purchase_orders').select('category, amount, status');
    final actualByCategory = <String, double>{};
    for (final o in orders as List) {
      final cat = (o['category'] as String?) ?? 'uncategorized';
      actualByCategory[cat] = (actualByCategory[cat] ?? 0) + (o['amount'] as num).toDouble();
    }

    final payrollRows = await client.schema('finance').from('payroll_runs').select('net_amount');
    double totalPayroll = 0;
    for (final p in payrollRows as List) {
      totalPayroll += (p['net_amount'] as num).toDouble();
    }

    return _BudgetData(
      budgets: List<Map<String, dynamic>>.from(budgets as List),
      actualByCategory: actualByCategory,
      totalPayroll: totalPayroll,
    );
  }

  Future<void> _addBudgetLine(String category, String year, double amount) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('finance').from('budgets').insert({
        'school_id': '11111111-1111-1111-1111-111111111111',
        'category': category,
        'academic_year': year,
        'planned_amount': amount,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget line added.'), backgroundColor: AppColors.success),
      );
      setState(() { _future = _load(); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  void _showAddSheet() {
    final categoryController = TextEditingController();
    final yearController = TextEditingController(text: '2026-27');
    final amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New Budget Line', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category (e.g. "supplies")')),
              const SizedBox(height: 12),
              TextField(controller: yearController, decoration: const InputDecoration(labelText: 'Academic year')),
              const SizedBox(height: 12),
              TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Planned amount (₹)')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || categoryController.text.trim().isEmpty) return;
                  Navigator.of(context).pop();
                  _addBudgetLine(categoryController.text.trim(), yearController.text.trim(), amount);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_BudgetData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Budget', style: Theme.of(context).textTheme.headlineMedium),
                          ElevatedButton.icon(onPressed: _showAddSheet, icon: const Icon(Icons.add, size: 18), label: const Text('New line')),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        GlassCard(
                          child: Row(
                            children: [
                              const Icon(Icons.payments_outlined, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Payroll (all-time)', style: Theme.of(context).textTheme.bodyMedium),
                                    Text('₹${data.totalPayroll.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleLarge),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('By Category', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        if (data.budgets.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No budget lines set yet.'))
                        else
                          ...data.budgets.map((b) {
                            final planned = (b['planned_amount'] as num).toDouble();
                            final actual = data.actualByCategory[b['category']] ?? 0;
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
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BudgetData {
  _BudgetData({required this.budgets, required this.actualByCategory, required this.totalPayroll});
  final List<Map<String, dynamic>> budgets;
  final Map<String, double> actualByCategory;
  final double totalPayroll;
}
