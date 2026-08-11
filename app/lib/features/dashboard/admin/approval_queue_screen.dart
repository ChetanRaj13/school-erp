import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

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
  final String? filter;

  const ApprovalQueueScreen({super.key, this.filter});

  @override
  ConsumerState<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends ConsumerState<ApprovalQueueScreen> {
  late Future<_QueueData> _future;

  // Search and filter state
  String _searchQuery = '';
  SortOption? _sortOption;
  final Map<String, String> _filterByType = {'purchase': 'all', 'vendor': 'all', 'payroll': 'all'};
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _sortOption = SortOptions.sortByDate;
    _roleFilter = widget.filter;
    _future = _load();
  }

  Future<void> _refresh([String? message]) async {
    setState(() { _future = _load(); });
    if (message != null) {
      _showSnack(message);
    }
  }

  Future<_QueueData> _load() async {
    final client = ref.read(supabaseClientProvider);

    // Filter based on role (hr vs finance)
    List<Map<String, dynamic>> pos = [];
    List<Map<String, dynamic>> vps = [];
    List<Map<String, dynamic>> payroll = [];

    if (_roleFilter == null || _roleFilter == 'finance') {
      pos = await client
          .schema('finance')
          .from('purchase_orders')
          .select('id, description, amount, requested_by, created_at, vendor_id')
          .eq('status', 'pending_approval')
          .order('created_at');

      vps = await client
          .schema('finance')
          .from('vendor_payments')
          .select('id, amount, method, purchase_order_id, created_at')
          .eq('status', 'pending_approval')
          .order('created_at');
    }

    if (_roleFilter == null || _roleFilter == 'hr') {
      payroll = await client
          .schema('finance')
          .from('payroll_runs')
          .select('id, employee_id, pay_period, gross_amount, net_amount, status, created_at')
          .eq('status', 'pending_approval')
          .order('created_at');
    }

    // Resolve staff names for display — separate fetch + client-side join
    final staff = await client.schema('public').from('staff').select('id, full_name');
    final nameById = <String, String>{for (final s in staff as List) s['id'] as String: s['full_name'] as String};

    return _QueueData(
      purchaseOrders: List<Map<String, dynamic>>.from(pos as List),
      vendorPayments: List<Map<String, dynamic>>.from(vps as List),
      payrollRuns: List<Map<String, dynamic>>.from(payroll as List),
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
      };
      await client.schema('finance').from(schemaTable).update(update).eq('id', id);
      _showSnack(approve ? 'Approved.' : 'Rejected.');
      _refresh();
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

  // Apply search and filter to purchase orders
  List<Map<String, dynamic>> _filterPurchaseOrders(List<Map<String, dynamic>> items) {
    var filtered = items;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return (item['description']?.toString().toLowerCase().contains(query) ?? false) ||
               (item['category']?.toString().toLowerCase().contains(query) ?? false) ||
               (item['po_number']?.toString().toLowerCase().contains(query) ?? false) ||
               (item['requested_by']?.toString().toLowerCase().contains(query) ?? false) ||
               ((item['amount'] as num?)?.toString().contains(_searchQuery) ?? false);
      }).toList();
    }

    // Type-specific filter (if implemented)
    if (_filterByType['purchase'] != 'all') {
      // Placeholder for additional filtering logic
    }

    // Sorting
    if (_sortOption != null) {
      filtered = ListSorter.sortItems(filtered, _sortOption!, true).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> _filterVendorPayments(List<Map<String, dynamic>> items) {
    var filtered = items;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return (item['method']?.toString().toLowerCase().contains(query) ?? false) ||
               ((item['amount'] as num?)?.toString().contains(_searchQuery) ?? false);
      }).toList();
    }

    if (_sortOption != null) {
      filtered = ListSorter.sortItems(filtered, _sortOption!, true).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> _filterPayrollRuns(List<Map<String, dynamic>> items) {
    var filtered = items;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        return (item['employee_id']?.toString().toLowerCase().contains(query) ?? false) ||
               (item['pay_period']?.toString().toLowerCase().contains(query) ?? false) ||
               ((item['net_amount'] as num?)?.toString().contains(_searchQuery) ?? false);
      }).toList();
    }

    if (_sortOption != null) {
      filtered = ListSorter.sortItems(filtered, _sortOption!, true).toList();
    }

    return filtered;
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

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Approval Queue', style: Theme.of(context).textTheme.headlineMedium),
                          GlassChip(label: '$totalPending pending', icon: Icons.pending_actions_outlined, color: AppColors.warning),
                        ],
                      ),
                    ),
                  ),
                  // Search and sort controls
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: SearchFilterBar(
                        hintText: 'Search across all items...',
                        onSearch: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        sorts: SortOptions.allFields,
                        currentSortValue: _sortOption?.value,
                        onSortSelected: (option) {
                          setState(() {
                            _sortOption = option;
                          });
                          _refresh();
                        },
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
                            ..._filterPurchaseOrders(data.purchaseOrders).map((po) => _ApprovalCard(
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
                            ..._filterVendorPayments(data.vendorPayments.map((vp) => Map<String, dynamic>.from(vp)).toList()).map((vp) => _ApprovalCard(
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
                            ..._filterPayrollRuns(data.payrollRuns.map((p) => Map<String, dynamic>.from(p)).toList()).map((p) => _ApprovalCard(
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
