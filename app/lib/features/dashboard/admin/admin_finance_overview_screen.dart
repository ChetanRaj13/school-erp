import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bar_chart.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Finance workspace overview for admin — real data only.
///
/// Fee collection (collected/pending/overdue), revenue vs expense vs budget,
/// purchase-order pipeline by status, EMI plans active, pending waivers count.
class AdminFinanceOverviewScreen extends ConsumerWidget {
  const AdminFinanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_FinanceOverviewData>(
            future: _load(client),
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
                      child: Text('Finance Overview', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),

                  // ── Fee Collection ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Fee Collection', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                      ),
                      delegate: SliverChildListDelegate([
                        StatCard(
                          label: 'Collected',
                          value: '₹${data.feeCollected.toStringAsFixed(0)}',
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                        ),
                        StatCard(
                          label: 'Pending',
                          value: '₹${data.feePending.toStringAsFixed(0)}',
                          icon: Icons.hourglass_empty_outlined,
                          color: AppColors.warning,
                        ),
                        StatCard(
                          label: 'Overdue',
                          value: '₹${data.feeOverdue.toStringAsFixed(0)}',
                          icon: Icons.error_outline,
                          color: AppColors.error,
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── Revenue vs Expense vs Budget ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Revenue vs Expense vs Budget', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                      ),
                      delegate: SliverChildListDelegate([
                        StatCard(
                          label: 'Total Revenue',
                          value: '₹${data.totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.trending_up_outlined,
                          color: AppColors.success,
                        ),
                        StatCard(
                          label: 'Total Expenses',
                          value: '₹${data.totalExpenses.toStringAsFixed(0)}',
                          icon: Icons.trending_down_outlined,
                          color: AppColors.error,
                        ),
                        StatCard(
                          label: 'Budget Remaining',
                          value: '₹${data.budgetRemaining.toStringAsFixed(0)}',
                          icon: Icons.account_balance_outlined,
                          color: data.budgetRemaining >= 0 ? AppColors.primary : AppColors.error,
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── Purchase-Order Pipeline ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Purchase-Order Pipeline', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                      ),
                      delegate: SliverChildListDelegate([
                        StatCard(
                          label: 'Pending Approval',
                          value: '${data.poPendingApproval}',
                          icon: Icons.pending_actions_outlined,
                          color: AppColors.warning,
                        ),
                        StatCard(
                          label: 'Approved (unpaid)',
                          value: '${data.poApproved}',
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                        ),
                        StatCard(
                          label: 'Paid',
                          value: '${data.poPaid}',
                          icon: Icons.payments_outlined,
                        ),
                        StatCard(
                          label: 'Rejected',
                          value: '${data.poRejected}',
                          icon: Icons.cancel_outlined,
                          color: AppColors.error,
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── EMI & Waivers ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('EMI & Waivers', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                      ),
                      delegate: SliverChildListDelegate([
                        StatCard(
                          label: 'Active EMI Plans',
                          value: '${data.emiActive}',
                          icon: Icons.credit_score_outlined,
                          color: AppColors.primary,
                        ),
                        StatCard(
                          label: 'Pending Waivers',
                          value: '${data.waiversPending}',
                          icon: Icons.volunteer_activism_outlined,
                          color: AppColors.warning,
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── Revenue Trend (historical years) ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Revenue by Academic Year', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  if (data.revenueTrend.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverToBoxAdapter(
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No historical revenue data available.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverToBoxAdapter(
                        child: SizedBox(
                          height: 200,
                          child: BarChart(
                            data: {
                              for (final r in data.revenueTrend) r.academicYear: r.totalCollected,
                            },
                            title: 'Total Collected',
                            showValues: true,
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── Budget Variance ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Budget Variance by Category', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  if (data.budgetVariance.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverToBoxAdapter(
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No budget variance data available.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverToBoxAdapter(
                        child: GlassCard(
                          padding: const EdgeInsets.all(0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 16,
                              headingRowColor: WidgetStateProperty.all(AppColors.glassBorder),
                              columns: const [
                                DataColumn(label: Text('Category')),
                                DataColumn(label: Text('Year'), numeric: true),
                                DataColumn(label: Text('Planned'), numeric: true),
                                DataColumn(label: Text('Actual'), numeric: true),
                                DataColumn(label: Text('% Used'), numeric: true),
                              ],
                              rows: data.budgetVariance.map((bv) {
                                final overBudget = bv.pctOfBudget > 110;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(bv.category)),
                                    DataCell(Text(bv.academicYear)),
                                    DataCell(Text('₹${bv.plannedAmount.toStringAsFixed(0)}')),
                                    DataCell(Text('₹${bv.actualSpend.toStringAsFixed(0)}')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (overBudget)
                                            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                                          if (overBudget) const SizedBox(width: 4),
                                          Text(
                                            '${bv.pctOfBudget.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: overBudget ? AppColors.error : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_FinanceOverviewData> _load(SupabaseClient client) async {
    // ── Fee collection from invoices ──
    // invoices table columns: id, amount_due, amount_paid, due_date
    // (no 'status' or 'total_amount' column — derive state from these)
    final invoiceRows = await client
        .schema('finance')
        .from('invoices')
        .select('id, amount_due, amount_paid, due_date');
    final invoiceList = List<Map<String, dynamic>>.from(invoiceRows as List);
    final now = DateTime.now();

    double feeCollected = 0;
    double feePending = 0;
    double feeOverdue = 0;
    for (final inv in invoiceList) {
      final amountDue = (inv['amount_due'] as num?)?.toDouble() ?? 0;
      final amountPaid = (inv['amount_paid'] as num?)?.toDouble() ?? 0;
      final dueDate = inv['due_date'] != null
          ? DateTime.tryParse(inv['due_date'].toString())
          : null;
      final remaining = amountDue - amountPaid;

      // Fully paid → count toward collected
      if (remaining <= 0) {
        feeCollected += amountPaid;
        continue;
      }
      // Overdue: due date passed and still unpaid
      if (dueDate != null && dueDate.isBefore(now)) {
        feeOverdue += remaining;
      } else {
        feePending += remaining;
      }
    }

    // ── Revenue from payments ──
    final paymentRows = await client
        .schema('finance')
        .from('payments')
        .select('id, amount, status');
    final paymentList = List<Map<String, dynamic>>.from(paymentRows as List);
    final totalRevenue = paymentList
        // payment_status enum values: pending, processing, success, failed, refunded
        .where((p) => p['status'] == 'success')
        .fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble());

    // ── Expenses from vendor_payments (paid only) ──
    final vpRows = await client
        .schema('finance')
        .from('vendor_payments')
        .select('id, amount, status');
    final vpList = List<Map<String, dynamic>>.from(vpRows as List);
    final totalExpenses = vpList
        .where((v) => v['status'] == 'paid')
        .fold<double>(0, (sum, v) => sum + (v['amount'] as num).toDouble());

    // ── Budget ──
    final budgetRows = await client
        .schema('finance')
        .from('budgets')
        .select('id, planned_amount');
    final budgetList = List<Map<String, dynamic>>.from(budgetRows as List);
    final totalBudget = budgetList.fold<double>(
        0, (sum, b) => sum + (b['planned_amount'] as num).toDouble());
    final budgetRemaining = totalBudget - totalExpenses;

    // ── PO pipeline ──
    final poRows = await client
        .schema('finance')
        .from('purchase_orders')
        .select('id, status');
    final poList = List<Map<String, dynamic>>.from(poRows as List);
    int poPendingApproval = 0, poApproved = 0, poPaid = 0, poRejected = 0;
    for (final po in poList) {
      switch (po['status']) {
        case 'pending_approval':
          poPendingApproval++;
        case 'approved':
          poApproved++;
        case 'paid':
          poPaid++;
        case 'rejected':
          poRejected++;
      }
    }

    // ── Payment plans (EMI) ──
    final emiRows = await client
        .schema('finance')
        .from('payment_plans')
        .select('id, status');
    final emiList = List<Map<String, dynamic>>.from(emiRows as List);
    final emiActive = emiList.where((e) => e['status'] == 'active').length;

    // ── Pending waivers ──
    final waiverRows = await client
        .schema('finance')
        .from('waiver_requests')
        .select('id, status');
    final waiverList = List<Map<String, dynamic>>.from(waiverRows as List);
    final waiversPending = waiverList.where((w) => w['status'] == 'pending').length;

    // ── Revenue trend (school-wide, historical years) ──
    List<_RevenueTrendPoint> revenueTrend = [];
    try {
      final trendRes = await client.schema('analytics').rpc('get_revenue_trend');
      final trendList = List<Map<String, dynamic>>.from(trendRes as List);
      revenueTrend = trendList.map((r) => _RevenueTrendPoint(
        academicYear: (r['academic_year'] as String?) ?? '',
        totalCollected: (r['total_collected'] as num?)?.toDouble() ?? 0,
        pctLate: (r['pct_late'] as num?)?.toDouble() ?? 0,
      )).toList();
    } catch (_) {
      // RPC may not exist or user lacks permission
    }

    // ── Budget variance (school-wide) ──
    List<_BudgetVarianceRow> budgetVariance = [];
    try {
      final varRes = await client.schema('analytics').rpc('get_budget_variance');
      final varList = List<Map<String, dynamic>>.from(varRes as List);
      budgetVariance = varList.map((r) => _BudgetVarianceRow(
        category: (r['category'] as String?) ?? '',
        academicYear: (r['academic_year'] as String?) ?? '',
        plannedAmount: (r['planned_amount'] as num?)?.toDouble() ?? 0,
        actualSpend: (r['actual_spend'] as num?)?.toDouble() ?? 0,
        pctOfBudget: (r['pct_of_budget'] as num?)?.toDouble() ?? 0,
      )).toList();
    } catch (_) {
      // RPC may not exist or user lacks permission
    }

    return _FinanceOverviewData(
      feeCollected: feeCollected,
      feePending: feePending,
      feeOverdue: feeOverdue,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      budgetRemaining: budgetRemaining,
      poPendingApproval: poPendingApproval,
      poApproved: poApproved,
      poPaid: poPaid,
      poRejected: poRejected,
      emiActive: emiActive,
      waiversPending: waiversPending,
      revenueTrend: revenueTrend,
      budgetVariance: budgetVariance,
    );
  }
}

class _FinanceOverviewData {
  const _FinanceOverviewData({
    required this.feeCollected,
    required this.feePending,
    required this.feeOverdue,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.budgetRemaining,
    required this.poPendingApproval,
    required this.poApproved,
    required this.poPaid,
    required this.poRejected,
    required this.emiActive,
    required this.waiversPending,
    required this.revenueTrend,
    required this.budgetVariance,
  });

  final double feeCollected;
  final double feePending;
  final double feeOverdue;
  final double totalRevenue;
  final double totalExpenses;
  final double budgetRemaining;
  final int poPendingApproval;
  final int poApproved;
  final int poPaid;
  final int poRejected;
  final int emiActive;
  final int waiversPending;
  final List<_RevenueTrendPoint> revenueTrend;
  final List<_BudgetVarianceRow> budgetVariance;
}

class _RevenueTrendPoint {
  const _RevenueTrendPoint({required this.academicYear, required this.totalCollected, required this.pctLate});
  final String academicYear;
  final double totalCollected;
  final double pctLate;
}

class _BudgetVarianceRow {
  const _BudgetVarianceRow({required this.category, required this.academicYear, required this.plannedAmount, required this.actualSpend, required this.pctOfBudget});
  final String category;
  final String academicYear;
  final double plannedAmount;
  final double actualSpend;
  final double pctOfBudget;
}
