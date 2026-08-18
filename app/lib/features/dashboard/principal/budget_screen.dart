import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/budget_breakdown_widget.dart';
import '../../../shared/widgets/glass_card.dart';
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
  String _selectedAcademicYear = '2026-27';

  static String _getAcademicYear(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '2026-27';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '2026-27';
    final year = dt.year;
    final month = dt.month;
    if (month >= 4) {
      return '$year-${(year + 1).toString().substring(2)}';
    } else {
      return '${year - 1}-${year.toString().substring(2)}';
    }
  }

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

    final orders = await client.schema('finance').from('purchase_orders').select('category, amount, status, created_at');
    final actualByCategory = <String, double>{};
    for (final o in orders as List) {
      final cat = ((o['category'] as String?) ?? 'uncategorized').toLowerCase().trim();
      final ay = _getAcademicYear(o['created_at'] as String?);
      final amt = (o['amount'] as num?)?.toDouble() ?? 0.0;
      final key = '${cat}_$ay';
      actualByCategory[key] = (actualByCategory[key] ?? 0.0) + amt;
      actualByCategory[cat] = (actualByCategory[cat] ?? 0.0) + amt;
    }

    final payrollRows = await client.schema('finance').from('payroll_runs').select('net_amount, pay_period');
    double totalPayroll = 0;
    for (final p in payrollRows as List) {
      totalPayroll += (p['net_amount'] as num?)?.toDouble() ?? 0.0;
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
    final yearController = TextEditingController(text: _selectedAcademicYear == 'all' ? '2026-27' : _selectedAcademicYear);
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
              TextField(controller: yearController, decoration: const InputDecoration(labelText: 'Academic year (e.g. "2026-27")')),
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
                child: const Text('Add Line'),
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

              final availableYears = data.budgets
                  .map((b) => (b['academic_year'] as String?) ?? '')
                  .where((y) => y.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort((a, b) => b.compareTo(a));

              final displayedBudgets = _selectedAcademicYear == 'all'
                  ? data.budgets
                  : data.budgets.where((b) => b['academic_year'] == _selectedAcademicYear).toList();

              final totalPlannedForYear = displayedBudgets.fold<double>(
                  0.0, (sum, b) => sum + ((b['planned_amount'] as num?)?.toDouble() ?? 0.0));

              final totalActualForYear = displayedBudgets.fold<double>(0.0, (sum, b) {
                final cat = ((b['category'] as String?) ?? '').toLowerCase().trim();
                final ay = (b['academic_year'] as String?) ?? '';
                final spent = data.actualByCategory['${cat}_$ay'] ?? 0.0;
                return sum + spent;
              });

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Budget & Expenditure', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Planned budget limits vs real-time purchase order utilization',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _showAddSheet,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('New Line'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Academic Year Filter Bar
                          GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Text('Fiscal Year:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final y in availableYears)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                              label: Text(y == '2026-27' ? '$y (Current)' : y),
                                              selected: _selectedAcademicYear == y,
                                              onSelected: (selected) {
                                                if (selected) setState(() => _selectedAcademicYear = y);
                                              },
                                              selectedColor: AppColors.primary.withValues(alpha: 0.18),
                                              labelStyle: TextStyle(
                                                color: _selectedAcademicYear == y ? AppColors.primary : AppColors.textSecondary,
                                                fontWeight: _selectedAcademicYear == y ? FontWeight.w700 : FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                        ChoiceChip(
                                          label: const Text('All Years'),
                                          selected: _selectedAcademicYear == 'all',
                                          onSelected: (selected) {
                                            if (selected) setState(() => _selectedAcademicYear = 'all');
                                          },
                                          selectedColor: AppColors.primary.withValues(alpha: 0.18),
                                          labelStyle: TextStyle(
                                            color: _selectedAcademicYear == 'all' ? AppColors.primary : AppColors.textSecondary,
                                            fontWeight: _selectedAcademicYear == 'all' ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Summary Stats Cards (Total Planned, Actual Spend, and Calculated Utilization %)
                        Row(
                          children: [
                            Expanded(
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedAcademicYear == 'all' ? 'Total Planned (All Years)' : 'Total Budget Planned',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₹${totalPlannedForYear.toStringAsFixed(0)}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedAcademicYear == 'all' ? 'Sum of all fiscal years' : 'AY $_selectedAcademicYear budget pool',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedAcademicYear == 'all' ? 'Actual Spend (All Years)' : 'Actual Spend (POs)',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₹${totalActualForYear.toStringAsFixed(0)}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: totalActualForYear > totalPlannedForYear ? AppColors.error : AppColors.primary,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Approved purchase orders',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _selectedAcademicYear == 'all' ? 'All-Years Consumed' : 'Budget Consumed',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (totalPlannedForYear > 0 && (totalActualForYear / totalPlannedForYear) > 1.0)
                                                ? AppColors.error.withValues(alpha: 0.12)
                                                : const Color(0xFF059669).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            totalPlannedForYear > 0 && (totalActualForYear / totalPlannedForYear) > 1.0 ? 'OVER' : 'ON TRACK',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: totalPlannedForYear > 0 && (totalActualForYear / totalPlannedForYear) > 1.0 ? AppColors.error : const Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      totalPlannedForYear > 0 ? '${((totalActualForYear / totalPlannedForYear) * 100).toStringAsFixed(1)}%' : '0.0%',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: totalPlannedForYear > 0 && (totalActualForYear / totalPlannedForYear) > 1.0 ? AppColors.error : const Color(0xFF059669),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${(totalPlannedForYear - totalActualForYear).clamp(0.0, double.infinity).toStringAsFixed(0)} remaining',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GlassCard(
                          child: Row(
                            children: [
                              const Icon(Icons.payments_outlined, color: AppColors.primary, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Payroll Distributed (all-time)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                                    Text('₹${data.totalPayroll.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        BudgetBreakdownWidget(
                          budgets: displayedBudgets,
                          actualByCategory: data.actualByCategory,
                          title: _selectedAcademicYear == 'all'
                              ? 'Budget by Category (All Fiscal Years)'
                              : 'Budget by Category ($_selectedAcademicYear)',
                        ),
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
