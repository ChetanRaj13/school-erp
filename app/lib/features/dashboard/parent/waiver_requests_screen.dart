import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

/// Waiver/scholarship requests — role-aware single screen, same pattern as
/// LeaveRequestsScreen. A parent submits for one of their linked children
/// (self_children_provider, so only real linked kids show up). Admin/principal
/// approve or reject. Now with enhanced search/filter/sorting.
class WaiverRequestsScreen extends ConsumerStatefulWidget {
  const WaiverRequestsScreen({super.key});

  @override
  ConsumerState<WaiverRequestsScreen> createState() => _WaiverRequestsScreenState();
}

class _WaiverRequestsScreenState extends ConsumerState<WaiverRequestsScreen> {
  late Future<_WaiverData> _future;

  // Search and filter state
  String _searchQuery = '';
  SortOption? _sortOption;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _sortOption = SortOptions.sortByDate;
    _future = _load();
  }

  Future<void> _refresh([String? message]) async {
    setState(() { _future = _load(); });
    if (message != null) {
      _showSnack(message);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
  }

  Future<_WaiverData> _load() async {
    final client = ref.read(supabaseClientProvider);

    final requests = await client
        .schema('finance')
        .from('waiver_requests')
        .select('id, student_id, request_type, requested_amount, reason, status, created_at, disbursed_at, invoice_id')
        .order('created_at', ascending: false);

    final studentIds = (requests as List).map((r) => r['student_id']).toSet().toList();
    final students = studentIds.isEmpty
        ? []
        : await client.schema('public').from('students').select('id, full_name, admission_number').inFilter('id', studentIds);

    return _WaiverData(
      requests: List<Map<String, dynamic>>.from(requests),
      nameByStudentId: {for (final s in students) s['id'] as String: s['full_name'] as String},
      admissionNumberById: {for (final s in students) s['id'] as String: (s['admission_number'] as String?) ?? ''},
    );
  }

  Future<void> _submit(String studentId, String type, double amount, String reason) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('finance').from('waiver_requests').insert({
        'student_id': studentId,
        'request_type': type,
        'requested_amount': amount,
        'reason': reason,
        'status': 'pending',
      });
      _refresh('Request submitted.');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _decide(String requestId, bool approve) async {
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('finance').from('waiver_requests').update({
        'status': approve ? 'approved' : 'rejected',
        'approved_by': selfStaffId,
      }).eq('id', requestId);
      _refresh(approve ? 'Approved.' : 'Rejected.');
    } catch (e) {
      _showError(e);
    }
  }

  /// Disburse an approved scholarship/waiver request.
  /// Reduces invoice.amount_due by requested_amount and sets disbursed_at = now().
  Future<void> _disburse(Map<String, dynamic> request) async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);

    String? invoiceId = request['invoice_id'] as String?;
    Map<String, dynamic>? invoice;

    if (invoiceId != null) {
      invoice = await _getInvoiceData(invoiceId);
    } else {
      // Auto-find student's latest unpaid invoice
      try {
        final invs = await client
            .schema('finance')
            .from('invoices')
            .select('id, amount_due, amount_paid')
            .eq('student_id', request['student_id'] as String)
            .order('due_date', ascending: false);
        final list = List<Map<String, dynamic>>.from(invs as List);
        if (list.isNotEmpty) {
          invoice = list.first;
          invoiceId = invoice['id'] as String;
          await client
              .schema('finance')
              .from('waiver_requests')
              .update({'invoice_id': invoiceId})
              .eq('id', request['id'] as String);
        }
      } catch (_) {}
    }

    final requestedAmount = (request['requested_amount'] as num).toDouble();
    final outstanding = invoice != null
        ? ((invoice['amount_due'] as num?)?.toDouble() ?? 0) -
            ((invoice['amount_paid'] as num?)?.toDouble() ?? 0)
        : requestedAmount;

    final actualAmount = requestedAmount <= outstanding ? requestedAmount : outstanding;

    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Waiver Disbursement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmationRow('Requested Amount', '₹${requestedAmount.toStringAsFixed(0)}'),
            if (invoice != null)
              _confirmationRow('Outstanding Balance', '₹${outstanding.toStringAsFixed(0)}'),
            const Divider(height: 16),
            _confirmationRow(
              'Amount to Disburse',
              '₹${actualAmount.toStringAsFixed(0)}',
              bold: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Disburse')),
        ],
      ),
    );

    if (confirmed != true) return;

    // Try RPC first
    if (selfStaffId != null && invoiceId != null) {
      try {
        final result = await client.rpc('disburse_waiver', params: {
          'p_request_id': request['id'] as String,
          'p_staff_id': selfStaffId,
        });
        final resultMap = result as Map<String, dynamic>;
        if (resultMap['success'] == true) {
          _refresh(resultMap['message'] as String);
          return;
        }
      } catch (_) {}
    }

    // Update invoice and waiver request
    try {
      if (invoiceId != null && invoice != null) {
        final currentDue = (invoice['amount_due'] as num).toDouble();
        final newDue = (currentDue - actualAmount).clamp(0.0, double.infinity);
        await client
            .schema('finance')
            .from('invoices')
            .update({'amount_due': newDue})
            .eq('id', invoiceId);
      }

      final remainingWaiver = requestedAmount - actualAmount;

      if (remainingWaiver > 0) {
        // Update waiver requested_amount to remaining balance so it can be disbursed again in the future!
        await client.schema('finance').from('waiver_requests').update({
          'requested_amount': remainingWaiver,
        }).eq('id', request['id'] as String);

        _refresh('Disbursed ₹${actualAmount.toStringAsFixed(0)} to clear outstanding balance. Remaining ₹${remainingWaiver.toStringAsFixed(0)} waiver balance is retained for future invoices.');
      } else {
        await client.schema('finance').from('waiver_requests').update({
          'disbursed_at': DateTime.now().toIso8601String(),
        }).eq('id', request['id'] as String);

        _refresh('Disbursement applied: invoice due reduced by ₹${actualAmount.toStringAsFixed(0)}.');
      }
    } catch (e) {
      _showError(e);
    }
  }

  Widget _confirmationRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  /// Fetch outstanding balance for a linked invoice (used for pre-check display).
  Future<Map<String, dynamic>?> _getInvoiceData(String? invoiceId) async {
    if (invoiceId == null) return null;
    final client = ref.read(supabaseClientProvider);
    try {
      return await client
          .schema('finance')
          .from('invoices')
          .select('id, amount_due, amount_paid')
          .eq('id', invoiceId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }



  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
  }

  // Filter and sort helpers for waiver requests
  List<Map<String, dynamic>> _filterRequests(List<Map<String, dynamic>> requests, Map<String, String> nameMap) {
    var filtered = requests;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        final studentName = (nameMap[r['student_id']] ?? '').toLowerCase();
        final reason = (r['reason'] as String?)?.toLowerCase() ?? '';
        return studentName.contains(query) || reason.contains(query) || (r['request_type']?.toString().contains(query) ?? false);
      }).toList();
    }

    // Status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((r) => r['status'] == _filterStatus).toList();
    }

    // Sorting
    if (_sortOption != null) {
      filtered = ListSorter.sortItems(filtered, _sortOption!, true).toList();
    }

    return filtered;
  }

  void _showRequestSheet(List<LinkedChild> children) {
    if (children.isEmpty) return;
    LinkedChild selectedChild = children.first;
    String type = 'scholarship';
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                Text('Request Scholarship / Waiver', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (children.length > 1)
                  DropdownButtonFormField<LinkedChild>(
                    initialValue: selectedChild,
                    decoration: const InputDecoration(labelText: 'Child'),
                    items: children.map((c) => DropdownMenuItem(value: c, child: Text(c.fullName))).toList(),
                    onChanged: (v) => setModalState(() => selectedChild = v!),
                  )
                else
                  Text('For: ${selectedChild.fullName}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'scholarship', child: Text('Scholarship')),
                    DropdownMenuItem(value: 'waiver', child: Text('Fee Waiver')),
                    DropdownMenuItem(value: 'grant', child: Text('Grant')),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Requested amount (₹)')),
                const SizedBox(height: 12),
                TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null) return;
                    Navigator.of(context).pop();
                    _submit(selectedChild.studentId, type, amount, reasonController.text.trim());
                  },
                  child: const Text('Submit request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final canDecide = role == UserRole.admin || role == UserRole.principal;
    final childrenAsync = role == UserRole.parent ? ref.watch(selfChildrenProvider) : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_WaiverData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;

              final filteredRequests = _filterRequests(data.requests, data.nameByStudentId);

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Scholarships & Waivers', style: Theme.of(context).textTheme.headlineMedium),
                          if (childrenAsync != null)
                            childrenAsync.when(
                              data: (children) => ElevatedButton.icon(
                                onPressed: children.isEmpty ? null : () => _showRequestSheet(children),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Request'),
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Search and filter controls
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: SearchFilterBar(
                        title: 'Requests',
                        hintText: 'Search by student name, reason, or type...',
                        onSearch: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        sorts: [
                          SortOptions.sortByDate,
                          SortOptions.sortByAmount,
                        ],
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

                  if (filteredRequests.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No requests yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          filteredRequests.map((r) {
                            final status = r['status'] as String;
                            final statusColor = switch (status) {
                              'approved' => AppColors.success,
                              'rejected' => AppColors.error,
                              _ => AppColors.warning,
                            };
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(data.nameByStudentId[r['student_id']] ?? 'Unknown', style: Theme.of(context).textTheme.titleMedium),
                                        GlassChip(label: status, color: statusColor),
                                      ],
                                    ),
                                    Text('${r['request_type']} · ₹${(r['requested_amount'] as num).toStringAsFixed(0)}', style: Theme.of(context).textTheme.bodyMedium),
                                    if ((r['reason'] as String?)?.isNotEmpty ?? false)
                                      Text(r['reason'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                    if (canDecide && status == 'pending') ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(child: OutlinedButton(onPressed: () => _decide(r['id'] as String, false), child: const Text('Reject'))),
                                          const SizedBox(width: 10),
                                          Expanded(child: ElevatedButton(onPressed: () => _decide(r['id'] as String, true), child: const Text('Approve'))),
                                        ],
                                      ),
                                    ],
                                    // Disburse button: approved but not yet disbursed.
                                    if (canDecide && status == 'approved' && r['disbursed_at'] == null) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _disburse(r),
                                          icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                                          label: const Text('Disburse'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                    // Already disbursed indicator.
                                    if (status == 'approved' && r['disbursed_at'] != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          GlassChip(
                                            label: 'Disbursed & Applied',
                                            icon: Icons.check_circle_outline,
                                            color: AppColors.success,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Applied on ${r['disbursed_at'].toString().split('T').first}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
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
}

class _WaiverData {
  _WaiverData({
    required this.requests,
    required this.nameByStudentId,
    required this.admissionNumberById,
  });

  final List<Map<String, dynamic>> requests;
  final Map<String, String> nameByStudentId;
  final Map<String, String> admissionNumberById;
}

