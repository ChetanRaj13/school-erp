import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// HR workspace overview for admin — real data only.
///
/// Staff headcount by role (from public.staff table), leave request summary
/// (finance.leave_requests), payroll summary (finance.payroll_runs).
///
/// HONEST GAP: public.staff_attendance has zero rows anywhere in the database.
/// We show "not yet in use" for any attendance-derived metric rather than
/// fabricating a percentage.
class AdminHrmOverviewScreen extends ConsumerWidget {
  const AdminHrmOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_HrmOverviewData>(
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
                      child: Text('HR Overview', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),

                  // ── Staff Headcount by Role ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Staff Headcount', style: Theme.of(context).textTheme.titleMedium),
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
                          label: 'Total Staff',
                          value: '${data.totalStaff}',
                          icon: Icons.groups_outlined,
                        ),
                        ...data.headcountByRole.entries.map((e) => StatCard(
                              label: e.key,
                              value: '${e.value}',
                              icon: Icons.person_outline,
                            )),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── Leave Request Summary ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Leave Requests', style: Theme.of(context).textTheme.titleMedium),
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
                          label: 'Pending',
                          value: '${data.leavePending}',
                          icon: Icons.hourglass_empty_outlined,
                          color: AppColors.warning,
                        ),
                        StatCard(
                          label: 'Approved (this month)',
                          value: '${data.leaveApprovedMonth}',
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                        ),
                        StatCard(
                          label: 'Rejected (this month)',
                          value: '${data.leaveRejectedMonth}',
                          icon: Icons.cancel_outlined,
                          color: AppColors.error,
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── Payroll Summary ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Payroll Summary', style: Theme.of(context).textTheme.titleMedium),
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
                          value: '${data.payrollPending}',
                          icon: Icons.pending_actions_outlined,
                          color: AppColors.warning,
                        ),
                        StatCard(
                          label: 'Paid This Month',
                          value: '₹${data.payrollPaidThisMonth.toStringAsFixed(0)}',
                          icon: Icons.payments_outlined,
                          color: AppColors.success,
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // ── Staff Attendance ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Staff Attendance', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverToBoxAdapter(
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.textSecondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Not yet in use', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'staff_attendance table exists but has no rows. '
                                      'Once staff begin logging attendance, summary stats will appear here.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Future<_HrmOverviewData> _load(SupabaseClient client) async {
    // ── Staff headcount ──
    final staffRows = await client
        .schema('public')
        .from('staff')
        .select('id, role');
    final staffList = List<Map<String, dynamic>>.from(staffRows as List);
    final totalStaff = staffList.length;
    final headcountByRole = <String, int>{};
    for (final s in staffList) {
      final role = (s['role'] as String?) ?? 'Unknown';
      headcountByRole[role] = (headcountByRole[role] ?? 0) + 1;
    }

    // ── Leave requests ──
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

    final leaveRows = await client
        .schema('finance')
        .from('leave_requests')
        .select('id, status, created_at');
    final leaveList = List<Map<String, dynamic>>.from(leaveRows as List);
    final leavePending = leaveList.where((r) => r['status'] == 'pending').length;
    final leaveApprovedMonth = leaveList.where((r) =>
        r['status'] == 'approved' &&
        (r['created_at'] as String).compareTo(monthStart) >= 0).length;
    final leaveRejectedMonth = leaveList.where((r) =>
        r['status'] == 'rejected' &&
        (r['created_at'] as String).compareTo(monthStart) >= 0).length;

    // ── Payroll ──
    final payrollRows = await client
        .schema('finance')
        .from('payroll_runs')
        .select('id, status, net_amount, pay_period, created_at');
    final payrollList = List<Map<String, dynamic>>.from(payrollRows as List);
    final payrollPending = payrollList.where((r) => r['status'] == 'pending_approval').length;
    final payrollPaidThisMonth = payrollList
        .where((r) =>
            r['status'] == 'paid' &&
            (r['created_at'] as String).compareTo(monthStart) >= 0)
        .fold<double>(0, (sum, r) => sum + (r['net_amount'] as num).toDouble());

    return _HrmOverviewData(
      totalStaff: totalStaff,
      headcountByRole: headcountByRole,
      leavePending: leavePending,
      leaveApprovedMonth: leaveApprovedMonth,
      leaveRejectedMonth: leaveRejectedMonth,
      payrollPending: payrollPending,
      payrollPaidThisMonth: payrollPaidThisMonth,
    );
  }
}

class _HrmOverviewData {
  const _HrmOverviewData({
    required this.totalStaff,
    required this.headcountByRole,
    required this.leavePending,
    required this.leaveApprovedMonth,
    required this.leaveRejectedMonth,
    required this.payrollPending,
    required this.payrollPaidThisMonth,
  });

  final int totalStaff;
  final Map<String, int> headcountByRole;
  final int leavePending;
  final int leaveApprovedMonth;
  final int leaveRejectedMonth;
  final int payrollPending;
  final double payrollPaidThisMonth;
}
