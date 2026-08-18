import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/dashboard/dashboard_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bar_chart.dart';
import '../../../../core/widgets/line_chart.dart';
import '../../../../core/widgets/kpi_card.dart';
import '../../../../core/widgets/pie_chart.dart';
import '../../../../core/widgets/activity_items.dart';
import '../../../../core/widgets/dashboard_widgets.dart';
import '../../../shared/widgets/budget_breakdown_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Redesigned Executive Dashboard for Admin Role
///
/// Features KPI cards, charts (fee collection trend, revenue vs expenses, budget utilization),
/// and comprehensive widgets (recent activities, pending tasks, approval queue, fee deadlines,
/// top defaulters, quick actions) in a glassmorphic design consistent with the school ERP theme.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardSummary = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: WarmBackdrop(
        child: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, scrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('School ERP Executive Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text('Admin Overview · ${DateTime.now().toString()}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      ]),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 28, color: AppColors.primary),
                        onPressed: () => ref.invalidate(dashboardSummaryProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: CustomScrollView(
              slivers: [
                // ────────────────────────
                // KPI Cards Section
                // ────────────────────────
                SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final summary = dashboardSummary.value;
                    if (summary == null) return const SliverToBoxAdapter(child: SizedBox());

                    final kpis = <KpiCard>[
                      KpiCard(
                        icon: Icons.school_outlined,
                        label: 'Total Students',
                        value: '${summary.totalStudents.toString()}',
                        changeIndicator: '+2.1%',
                      ),
                      KpiCard(
                        icon: Icons.groups_outlined,
                        label: 'Total Staff',
                        value: '${summary.totalStaff.toString()}',
                        changeIndicator: '+1.5%',
                      ),
                      KpiCard(
                        icon: Icons.person_outline,
                        label: 'Active Teachers',
                        value: '${summary.activeTeachers.toString()}',
                        changeIndicator: '+0.8%',
                        accentColor: AppColors.success,
                      ),
                      KpiCard(
                        icon: Icons.monetization_on_outlined,
                        label: 'Monthly Revenue',
                        value: '₹${summary.monthlyRevenue.toStringAsFixed(0)}',
                        changeIndicator: '+12.3%',
                        accentColor: AppColors.success,
                      ),
                      KpiCard(
                        icon: Icons.account_balance_outlined,
                        label: 'Outstanding Fees',
                        value: '₹${summary.outstandingFees.toStringAsFixed(0)}',
                        changeIndicator: '-5.2%',
                        accentColor: AppColors.warning,
                      ),
                      KpiCard(
                        icon: Icons.attach_money_outlined,
                        label: 'Monthly Collections',
                        value: '₹${summary.monthlyCollections.toStringAsFixed(0)}',
                        changeIndicator: '+8.7%',
                        accentColor: AppColors.success,
                      ),
                      KpiCard(
                        icon: Icons.shopping_cart_outlined,
                        label: 'Total Expenses',
                        value: '₹${summary.totalExpenses.toStringAsFixed(0)}',
                        changeIndicator: '+3.4%',
                      ),
                      KpiCard(
                        icon: Icons.category_outlined,
                        label: 'Budget Utilization',
                        value: '${summary.budgetUtilization.round().toString()}%',
                        progressValue: summary.budgetUtilization / 100,
                        accentColor: summary.budgetUtilization > 80 ? AppColors.error : AppColors.primary,
                      ),
                    ];

                    if (index < kpis.length) {
                      return kpis[index];
                    }
                    return const SliverToBoxAdapter(child: SizedBox());
                  },
                  childCount: 8,
                )),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ────────────────────────
                // Charts Section
                // ────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Financial Analytics', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFeeTrendChart(ref),
                          const SizedBox(width: 16),
                          _buildRevenueVsExpenseChart(ref),
                          const SizedBox(width: 16),
                          _buildMonthlyCashFlowChart(ref),
                          const SizedBox(width: 16),
                          _buildBudgetUtilizationChart(ref),
                          const SizedBox(width: 16),
                          _buildStudentAdmissionChart(ref),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ────────────────────────
                // Budget by Category (reused from Principal Budget Screen)
                // ────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Budget by Category', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _BudgetBreakdownSection(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ────────────────────────
                // Widgets Section
                // ────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('Operational Widgets', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.6,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final summary = dashboardSummary.value;
                    if (summary == null) return const SliverToBoxAdapter(child: SizedBox());

                    switch (index) {
                      case 0:
                        return ApprovalQueueSummary(
                          totalPending: summary.pendingApprovals,
                          items: [],
                        );
                      case 1:
                        return SystemAlertsWidget(alerts: summary.systemAlerts);
                      case 2:
                        return RecentActivityList(activities: summary.recentActivities);
                      case 3:
                        return UpcomingFeeDeadlines(deadlines: summary.upcomingDeadlines);
                      case 4:
                        return TopFeeDefaulters(defaulters: summary.topDefaulters);
                      case 5:
                        return QuickActionsPanel();
                      default:
                        return const SliverToBoxAdapter(child: SizedBox());
                    }
                  },
                  childCount: 6,
                )),

                // ────────────────────────
                // Quick Actions Panel (expanded)
                // ────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: QuickActionsExpanded(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeeTrendChart(WidgetRef ref) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final revenueData = [45000, 52000, 48000, 61000, 55000, 72000].map((e) => e.toDouble()).toList();

    return LineChart(
      values: revenueData,
      labels: months,
      title: 'Fee Collection Trend',
      chartColor: AppColors.primary,
      maxValue: 80000,
    );
  }

  Widget _buildRevenueVsExpenseChart(WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider).value;
    final totalExpenses = summary?.totalExpenses ?? 0;
    final expenseData = {
      'Staff Salaries': totalExpenses * 0.5,
      'Academic Supplies': totalExpenses * 0.25,
      'Facilities & Maintenance': totalExpenses * 0.15,
      'Technology': totalExpenses * 0.10,
    };

    return BarChart(
      data: expenseData,
      title: 'Expense Breakdown',
      valuePrefix: '₹',
      primaryColor: AppColors.secondary,
    );
  }

  Widget _buildMonthlyCashFlowChart(WidgetRef ref) {
    return PieChart(
      data: {'Payments Received': 65, 'Expenses Paid': 35},
      title: 'Payment Method Distribution',
      colors: [AppColors.success, AppColors.warning],
    );
  }

  Widget _buildBudgetUtilizationChart(WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider).value;
    final values = (summary?.budgetUtilization ?? 0) > 0 ? [summary!.budgetUtilization] : [0.0];

    return LineChart(
      values: values,
      labels: summary != null ? ['Current'] : [],
      title: 'Budget Utilization',
      chartColor: (summary?.budgetUtilization ?? 0) > 80 ? AppColors.error : AppColors.primary,
      maxValue: 100,
    );
  }

  Widget _buildStudentAdmissionChart(WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider).value;
    final students = summary?.totalStudents ?? 0;
    return BarChart(
      data: {'Primary': (students ~/ 3).toDouble(), 'Secondary': (students ~/ 3).toDouble(), 'Senior Secondary': (students ~/ 3).toDouble()},
      title: 'Student Distribution by Level',
      valuePrefix: '',
      primaryColor: AppColors.primary,
    );
  }
}

// ────────────────────────────────────────────────
// Sub-widget implementations
// ────────────────────────────────────────────────

class SystemAlertsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;

  const SystemAlertsWidget({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_outlined, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text('System Alerts', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            Text('No active alerts', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: alerts.map((alert) => SystemAlert(
                message: alert['message'] as String,
                isWarning: alert['isWarning'] as bool,
              )).toList(),
            ),
        ],
      ),
    );
  }
}

class RecentActivityList extends StatelessWidget {
  final List<Map<String, dynamic>> activities;

  const RecentActivityList({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_activity_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Recent Activities', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No recent activity'))
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: activities.map((act) {
                return RecentActivityItem(
                  action: act['action'] as String,
                  description: act['description'] as String,
                  timestamp: act['timestamp'] as DateTime,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class QuickActionsPanel extends StatelessWidget {
  const QuickActionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _QuickActionButton(
                icon: Icons.add_shopping_cart_outlined,
                label: 'New Invoice',
                route: '/admin/fees/create',
              ),
              _QuickActionButton(
                icon: Icons.pending_actions_outlined,
                label: 'Approve PO',
                route: '/admin/approvals/finance',
              ),
              _QuickActionButton(
                icon: Icons.add_circle_outline,
                label: 'New Fee Structure',
                route: '/admin/fees/structure',
              ),
              _QuickActionButton(
                icon: Icons.receipt_long_outlined,
                label: 'Add Payment',
                route: '/admin/payments/add',
              ),
              _QuickActionButton(
                icon: Icons.assignment_outlined,
                label: 'View Attendance',
                route: '/admin/omr',
              ),
              _QuickActionButton(
                icon: Icons.notifications_active_outlined,
                label: 'Send Announcement',
                route: '/admin/announcements/new',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _QuickActionButton({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => GoRouter.of(context).push(route),
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
        elevation: 0,
      ),
    );
  }
}

class QuickActionsExpanded extends StatelessWidget {
  const QuickActionsExpanded({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions (All)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final actions = [
                (Icons.settings_outlined, 'Configure Settings', '/settings'),
                (Icons.group_add_outlined, 'Add Student', '/admin/enrollment'),
                (Icons.person_add_alt_outlined, 'Add Staff', '/admin/payroll'),
                (Icons.medical_services_outlined, 'Fee Waivers', '/admin/waivers'),
                (Icons.credit_score_outlined, 'EMI Plans', '/admin/emi'),
                (Icons.account_balance_wallet_outlined, 'Budget Planning', '/admin/budget'),
                (Icons.storefront_outlined, 'Manage Vendors', '/admin/vendors'),
                (Icons.fact_check_outlined, 'Document Review', '/admin/documents'),
                (Icons.document_scanner_outlined, 'OMR Attendance', '/admin/omr'),
                (Icons.calendar_view_week_outlined, 'Weekly Timetable', '/admin/timetable'),
                (Icons.campaign_outlined, 'Announcements', '/admin/announcements'),
                (Icons.mail_outline, 'Messages', '/admin/messages'),
              ];

              if (index >= actions.length) return const SizedBox();

              final (icon, label, route) = actions[index];
              return InkWell(
                onTap: () => context.go(route),
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 28, color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Self-contained budget breakdown section for the Admin Dashboard.
/// Loads budgets + actual spend data and delegates rendering to the shared
/// [BudgetBreakdownWidget] — identical to the Principal Budget screen.
class _BudgetBreakdownSection extends ConsumerStatefulWidget {
  const _BudgetBreakdownSection();

  @override
  ConsumerState<_BudgetBreakdownSection> createState() => _BudgetBreakdownSectionState();
}

class _BudgetBreakdownSectionState extends ConsumerState<_BudgetBreakdownSection> {
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

    final orders = await client
        .schema('finance')
        .from('purchase_orders')
        .select('category, amount, status, created_at');
    final actualByCategory = <String, double>{};
    for (final o in orders as List) {
      final cat = ((o['category'] as String?) ?? 'uncategorized').toLowerCase().trim();
      final dtStr = o['created_at'] as String?;
      String ay = '2026-27';
      if (dtStr != null && dtStr.isNotEmpty) {
        final dt = DateTime.tryParse(dtStr);
        if (dt != null) {
          ay = dt.month >= 4 ? '${dt.year}-${(dt.year + 1).toString().substring(2)}' : '${dt.year - 1}-${dt.year.toString().substring(2)}';
        }
      }
      final amt = (o['amount'] as num?)?.toDouble() ?? 0.0;
      final key = '${cat}_$ay';
      actualByCategory[key] = (actualByCategory[key] ?? 0.0) + amt;
      actualByCategory[cat] = (actualByCategory[cat] ?? 0.0) + amt;
    }

    return _BudgetData(
      budgets: List<Map<String, dynamic>>.from(budgets as List),
      actualByCategory: actualByCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BudgetData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('Failed to load budget data')),
          );
        }
        final data = snapshot.data!;
        return BudgetBreakdownWidget(
          budgets: data.budgets,
          actualByCategory: data.actualByCategory,
        );
      },
    );
  }
}

class _BudgetData {
  _BudgetData({required this.budgets, required this.actualByCategory});
  final List<Map<String, dynamic>> budgets;
  final Map<String, double> actualByCategory;
}
