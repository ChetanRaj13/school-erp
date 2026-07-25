import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Waiver/scholarship requests — role-aware single screen, same pattern as
/// LeaveRequestsScreen. A parent submits for one of their linked children
/// (self_children_provider, so only real linked kids show up — same honest-gating
/// approach as ParentDashboard). Admin/principal approve or reject.
class WaiverRequestsScreen extends ConsumerStatefulWidget {
  const WaiverRequestsScreen({super.key});

  @override
  ConsumerState<WaiverRequestsScreen> createState() => _WaiverRequestsScreenState();
}

class _WaiverRequestsScreenState extends ConsumerState<WaiverRequestsScreen> {
  late Future<_WaiverData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WaiverData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final requests = await client
        .schema('finance')
        .from('waiver_requests')
        .select('id, student_id, request_type, requested_amount, reason, status, created_at')
        .order('created_at', ascending: false);
    final studentIds = (requests as List).map((r) => r['student_id']).toSet().toList();
    final students = studentIds.isEmpty
        ? []
        : await client.schema('public').from('students').select('id, full_name').inFilter('id', studentIds);
    return _WaiverData(
      requests: List<Map<String, dynamic>>.from(requests),
      nameByStudentId: {for (final s in students) s['id'] as String: s['full_name'] as String},
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

  void _refresh(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
    setState(() { _future = _load(); });
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
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
                  if (data.requests.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No requests yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          data.requests.map((r) {
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
  _WaiverData({required this.requests, required this.nameByStudentId});
  final List<Map<String, dynamic>> requests;
  final Map<String, String> nameByStudentId;
}
