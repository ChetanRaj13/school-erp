import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

class LeaveRequestsScreen extends ConsumerStatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  ConsumerState<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends ConsumerState<LeaveRequestsScreen> {
  late Future<_LeaveData> _future;

  // Search, Filter, Sort state
  String _searchQuery = '';
  String _selectedStatus = 'all';
  SortOption _sortOption = const SortOption(value: 'date_desc', label: 'Date: Newest First', icon: Icons.calendar_today);

  static const _sortOptions = [
    SortOption(value: 'date_desc', label: 'Date: Newest First', icon: Icons.calendar_today),
    SortOption(value: 'date_asc', label: 'Date: Oldest First', icon: Icons.calendar_today_outlined),
    SortOption(value: 'name_asc', label: 'Staff Name: A → Z', icon: Icons.sort_by_alpha),
    SortOption(value: 'name_desc', label: 'Staff Name: Z → A', icon: Icons.sort_by_alpha),
  ];

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

  List<Map<String, dynamic>> _applyFilterAndSort(List<Map<String, dynamic>> source, Map<String, String> nameById) {
    var list = source.where((r) {
      final staffName = nameById[r['staff_id']] ?? 'Staff';
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final reason = (r['reason'] as String? ?? '').toLowerCase();
        if (!staffName.toLowerCase().contains(q) && !reason.contains(q)) {
          return false;
        }
      }
      if (_selectedStatus != 'all' && r['status'] != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      final nameA = nameById[a['staff_id']] ?? '';
      final nameB = nameById[b['staff_id']] ?? '';
      switch (_sortOption.value) {
        case 'date_asc':
          final dA = a['start_date'] as String? ?? '';
          final dB = b['start_date'] as String? ?? '';
          return dA.compareTo(dB);
        case 'date_desc':
          final dA = a['start_date'] as String? ?? '';
          final dB = b['start_date'] as String? ?? '';
          return dB.compareTo(dA);
        case 'name_asc':
          return nameA.compareTo(nameB);
        case 'name_desc':
          return nameB.compareTo(nameA);
        default:
          return 0;
      }
    });

    return list;
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
              final displayedList = _applyFilterAndSort(data.requests, data.nameById);

              final filterGroups = <FilterGroup>[
                FilterGroup(
                  title: 'Status',
                  currentValue: _selectedStatus,
                  options: const [
                    FilterOption(value: 'all', label: 'All Requests'),
                    FilterOption(value: 'pending', label: 'Pending Approval'),
                    FilterOption(value: 'approved', label: 'Approved'),
                    FilterOption(value: 'rejected', label: 'Rejected'),
                  ],
                ),
              ];

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
                            label: const Text('Request'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: SearchFilterBar(
                        hintText: 'Search by staff name or reason...',
                        onSearch: (val) => setState(() => _searchQuery = val),
                        filterGroups: filterGroups,
                        onFilterChanged: (group) {
                          setState(() => _selectedStatus = group.currentValue ?? 'all');
                        },
                        sorts: _sortOptions,
                        currentSortValue: _sortOption.value,
                        onSortSelected: (option) => setState(() => _sortOption = option),
                      ),
                    ),
                  ),
                  if (displayedList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          _searchQuery.isNotEmpty || _selectedStatus != 'all'
                              ? 'No matching leave requests found.'
                              : 'No leave requests yet.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          displayedList.map((r) {
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
