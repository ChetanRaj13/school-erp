import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Leave requests — role-aware in a single screen rather than two separate ones,
/// since the underlying data (public.leave_requests) and the RLS shape are the same,
/// just the allowed ACTIONS differ: any staff member can submit their OWN request
/// (self_insert_leave_request RLS policy — not role-scoped, just self-scoped), while
/// only admin/principal can approve/reject (admin_approve_leave_requests policy).
class LeaveRequestsScreen extends ConsumerStatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  ConsumerState<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends ConsumerState<LeaveRequestsScreen> {
  late Future<_LeaveData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LeaveData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final requests = await client
        .schema('public')
        .from('leave_requests')
        .select('id, staff_id, start_date, end_date, reason, status, created_at')
        .order('created_at', ascending: false);
    final staff = await client.schema('public').from('staff').select('id, full_name');
    return _LeaveData(
      requests: List<Map<String, dynamic>>.from(requests as List),
      nameById: {for (final s in staff as List) s['id'] as String: s['full_name'] as String},
    );
  }

  Future<void> _submitRequest(DateTime start, DateTime end, String reason) async {
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    if (selfStaffId == null) {
      _showSnack('Your account must be linked to a staff record to request leave.', isError: true);
      return;
    }
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('public').from('leave_requests').insert({
        'staff_id': selfStaffId,
        'start_date': start.toIso8601String().split('T').first,
        'end_date': end.toIso8601String().split('T').first,
        'reason': reason,
        'status': 'pending',
      });
      _showSnack('Leave request submitted.');
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    }
  }

  Future<void> _decide(String requestId, bool approve) async {
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('public').from('leave_requests').update({
        'status': approve ? 'approved' : 'rejected',
        'approved_by': selfStaffId,
      }).eq('id', requestId);
      _showSnack(approve ? 'Approved.' : 'Rejected.');
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
    setState(() { _future = _load(); });
  }

  void _showRequestSheet() {
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 1));
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
                Text('Request Leave', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start date'),
                  subtitle: Text('${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: start, firstDate: DateTime.now(), lastDate: DateTime(2027),
                    );
                    if (picked != null) setModalState(() => start = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End date'),
                  subtitle: Text('${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: end, firstDate: start, lastDate: DateTime(2027),
                    );
                    if (picked != null) setModalState(() => end = picked);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _submitRequest(start, end, reasonController.text.trim());
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
    final canApprove = role == UserRole.admin || role == UserRole.principal;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_LeaveData>(
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
                          Text('Leave Requests', style: Theme.of(context).textTheme.headlineMedium),
                          ElevatedButton.icon(
                            onPressed: _showRequestSheet,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Request leave'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (data.requests.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No leave requests yet.')),
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
                                        Text(
                                          data.nameById[r['staff_id']] ?? 'Unknown',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        GlassChip(label: status, color: statusColor),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${r['start_date']} → ${r['end_date']}', style: Theme.of(context).textTheme.bodyMedium),
                                    if ((r['reason'] as String?)?.isNotEmpty ?? false) ...[
                                      const SizedBox(height: 4),
                                      Text(r['reason'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                    ],
                                    if (canApprove && status == 'pending') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _decide(r['id'] as String, false),
                                              child: const Text('Reject'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _decide(r['id'] as String, true),
                                              child: const Text('Approve'),
                                            ),
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

class _LeaveData {
  _LeaveData({required this.requests, required this.nameById});
  final List<Map<String, dynamic>> requests;
  final Map<String, String> nameById;
}
