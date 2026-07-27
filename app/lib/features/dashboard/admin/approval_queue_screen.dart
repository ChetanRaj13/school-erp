import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Real approval queue — finance.purchase_orders, finance.vendor_payments,
/// finance.payroll_runs, all filtered to status='pending_approval'. Approve/Reject
/// buttons perform REAL updates (status change + approved_by set to the signed-in
/// staff's own id), gated by the admin_approve_* RLS policies added specifically for
/// this screen — only principal/admin roles can actually write, enforced server-side
/// by Postgres, not just hidden client-side.
///
/// "Digital signature/approval" from the feature file is represented here as
/// approved_by = the approving staff member's own linked staff.id — a real,
/// attributable record of who approved what, not a literal signature-capture UI
/// (that would need a drawing/signature-pad widget, a separate, smaller feature this
/// doesn't attempt).
class ApprovalQueueScreen extends ConsumerStatefulWidget {
  /// When [filter] is:
  /// - null (default): show all pending items (POs, vendor payments, payroll).
  /// - 'hr': show only payroll items (HR workspace).
  /// - 'finance': show only POs + vendor payments (Finance workspace).
  const ApprovalQueueScreen({super.key, this.filter});

  final String? filter;

  @override
  ConsumerState<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends ConsumerState<ApprovalQueueScreen> {
  late Future<_QueueData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_QueueData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final filter = widget.filter;

    // When filter is null, load everything. When 'hr', only payroll. When 'finance',
    // only POs + vendor payments.
    final loadPo = filter == null || filter == 'finance';
    final loadVp = filter == null || filter == 'finance';
    final loadPayroll = filter == null || filter == 'hr';

    final futures = <Future<dynamic>>[];
    final futuresMeta = <String>[];

    if (loadPo) {
      futures.add(client
          .schema('finance')
          .from('purchase_orders')
          .select('id, description, amount, requested_by, created_at')
          .eq('status', 'pending_approval')
          .order('created_at'));
      futuresMeta.add('po');
    }
    if (loadVp) {
      futures.add(client
          .schema('finance')
          .from('vendor_payments')
          .select('id, amount, method, purchase_order_id, created_at')
          .eq('status', 'pending_approval')
          .order('created_at'));
      futuresMeta.add('vp');
    }
    if (loadPayroll) {
      futures.add(client
          .schema('finance')
          .from('payroll_runs')
          .select('id, employee_id, pay_period, gross_amount, net_amount, created_at')
          .eq('status', 'pending_approval')
          .order('created_at'));
      futuresMeta.add('payroll');
    }

    final results = await Future.wait(futures);

    // Resolve staff names for display — separate fetch + client-side join, same
    // deliberate choice as teacher_dashboard.dart (avoids fragile cross-schema
    // PostgREST embeds).
    final staff = await client.schema('public').from('staff').select('id, full_name');
    final nameById = <String, String>{for (final s in staff as List) s['id'] as String: s['full_name'] as String};

    List<Map<String, dynamic>> posList = [];
    List<Map<String, dynamic>> vpList = [];
    List<Map<String, dynamic>> payrollList = [];

    for (var i = 0; i < results.length; i++) {
      final items = List<Map<String, dynamic>>.from(results[i] as List);
      switch (futuresMeta[i]) {
        case 'po':
          posList = items;
        case 'vp':
          vpList = items;
        case 'payroll':
          payrollList = items;
      }
    }

    return _QueueData(
      purchaseOrders: posList,
      vendorPayments: vpList,
      payrollRuns: payrollList,
      staffNameById: nameById,
    );
  }

  Future<void> _decide({
    required String schemaTable, // 'purchase_orders' | 'vendor_payments' | 'payroll_runs'
    required String id,
    required bool approve,
  }) async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);

    if (selfStaffId == null) {
      _showSnack('Your account must be linked to a staff record to approve items.', isError: true);
      return;
    }

    try {
      final update = {
        'status': approve ? 'approved' : 'rejected',
        if (schemaTable != 'payroll_runs') 'approved_by': selfStaffId,
        // NOTE: payroll_runs has no approved_by column in the live schema — verified,
        // not assumed. Only purchase_orders and vendor_payments track it.
      };
      await client.schema('finance').from(schemaTable).update(update).eq('id', id);
      _showSnack(approve ? 'Approved.' : 'Rejected.');
      setState(() { _future = _load(); });
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_QueueData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              final totalPending = data.purchaseOrders.length + data.vendorPayments.length + data.payrollRuns.length;

              // Title changes based on filter mode.
              final title = widget.filter == 'hr'
                  ? 'HR Approvals'
                  : widget.filter == 'finance'
                      ? 'Finance Approvals'
                      : 'Approval Queue';

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.headlineMedium),
                          GlassChip(label: '$totalPending pending', icon: Icons.pending_actions_outlined, color: AppColors.warning),
                        ],
                      ),
                    ),
                  ),
                  if (totalPending == 0)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Nothing pending approval right now.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (data.purchaseOrders.isNotEmpty) ...[
                            _sectionLabel(context, 'Purchase Orders'),
                            ...data.purchaseOrders.map((po) => _ApprovalCard(
                                  title: po['description'] as String,
                                  subtitle: 'Requested by ${data.staffNameById[po['requested_by']] ?? 'Unknown'}',
                                  amount: (po['amount'] as num).toDouble(),
                                  onApprove: () => _decide(schemaTable: 'purchase_orders', id: po['id'] as String, approve: true),
                                  onReject: () => _decide(schemaTable: 'purchase_orders', id: po['id'] as String, approve: false),
                                )),
                            const SizedBox(height: 8),
                          ],
                          if (data.vendorPayments.isNotEmpty) ...[
                            _sectionLabel(context, 'Vendor Payments'),
                            ...data.vendorPayments.map((vp) => _ApprovalCard(
                                  title: 'Vendor payment · ${vp['method']}',
                                  subtitle: 'PO #${(vp['purchase_order_id'] as String).substring(0, 8)}',
                                  amount: (vp['amount'] as num).toDouble(),
                                  onApprove: () => _decide(schemaTable: 'vendor_payments', id: vp['id'] as String, approve: true),
                                  onReject: () => _decide(schemaTable: 'vendor_payments', id: vp['id'] as String, approve: false),
                                )),
                            const SizedBox(height: 8),
                          ],
                          if (data.payrollRuns.isNotEmpty) ...[
                            _sectionLabel(context, 'Payroll'),
                            ...data.payrollRuns.map((p) => _ApprovalCard(
                                  title: '${data.staffNameById[p['employee_id']] ?? 'Unknown'} · ${p['pay_period']}',
                                  subtitle: 'Net pay',
                                  amount: (p['net_amount'] as num).toDouble(),
                                  onApprove: () => _decide(schemaTable: 'payroll_runs', id: p['id'] as String, approve: true),
                                  onReject: () => _decide(schemaTable: 'payroll_runs', id: p['id'] as String, approve: false),
                                )),
                          ],
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

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onApprove,
    required this.onReject,
  });

  final String title;
  final String subtitle;
  final double amount;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                Text('₹${amount.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                    label: const Text('Reject', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueData {
  _QueueData({
    required this.purchaseOrders,
    required this.vendorPayments,
    required this.payrollRuns,
    required this.staffNameById,
  });

  final List<Map<String, dynamic>> purchaseOrders;
  final List<Map<String, dynamic>> vendorPayments;
  final List<Map<String, dynamic>> payrollRuns;
  final Map<String, String> staffNameById;
}
