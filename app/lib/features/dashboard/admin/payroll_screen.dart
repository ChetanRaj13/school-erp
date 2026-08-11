import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

/// Payroll management — enhanced with search, filter, and sorting capabilities.
class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  late Future<_PayrollData> _future;

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

  Future<_PayrollData> _load() async {
    final client = ref.read(supabaseClientProvider);

    final runs = await client
        .schema('finance')
        .from('payroll_runs')
        .select('id, employee_id, pay_period, gross_amount, deductions, net_amount, status, created_at')
        .order('created_at', ascending: false);

    final staff = await client.schema('public').from('staff').select('id, full_name, monthly_salary');

    return _PayrollData(
      runs: List<Map<String, dynamic>>.from(runs as List),
      staff: List<Map<String, dynamic>>.from(staff as List),
    );
  }

  Future<void> _createRun(Map<String, dynamic> employee, String payPeriod, double deductions) async {
    final client = ref.read(supabaseClientProvider);
    final gross = (employee['monthly_salary'] as num?)?.toDouble() ?? 0;

    try {
      await client.schema('finance').from('payroll_runs').insert({
        'school_id': '11111111-1111-1111-1111-111111111111',
        'employee_id': employee['id'],
        'pay_period': payPeriod,
        'gross_amount': gross,
        'deductions': deductions,
        'status': 'pending_approval',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payroll run created — sent to Approval Queue.'), backgroundColor: AppColors.success),
      );
      setState(() { _future = _load(); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showCreateSheet(List<Map<String, dynamic>> staff) {
    Map<String, dynamic>? selectedEmployee = staff.isNotEmpty ? staff.first : null;
    final payPeriodController = TextEditingController(text: 'July 2026');
    final deductionsController = TextEditingController(text: '0');

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
                Text('New Payroll Run', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedEmployee,
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: staff
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text('${s['full_name']} (₹${s['monthly_salary'] ?? 0}/mo)'),
                          ))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedEmployee = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: payPeriodController,
                  decoration: const InputDecoration(labelText: 'Pay period (e.g. "July 2026")'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deductionsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Deductions (₹)'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: selectedEmployee == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _createRun(
                            selectedEmployee!,
                            payPeriodController.text.trim(),
                            double.tryParse(deductionsController.text) ?? 0,
                          );
                        },
                  child: const Text('Create & Send for Approval'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterPayrollRuns(List<Map<String, dynamic>> runs, Map<String, String> nameById) {
    var filtered = runs;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((run) {
        final employeeName = (nameById[run['employee_id']] ?? '').toLowerCase();
        final payPeriod = (run['pay_period'] as String? ?? '').toLowerCase();
        final status = (run['status'] as String? ?? '').toLowerCase();
        return employeeName.contains(query) ||
               payPeriod.contains(query) ||
               status.contains(query) ||
               run['net_amount'].toString().contains(_searchQuery);
      }).toList();
    }

    // Status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((run) => run['status'] == _filterStatus).toList();
    }

    // Sorting
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
          child: FutureBuilder<_PayrollData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              final nameById = <String, String>{for (final s in data.staff) s['id'] as String: s['full_name'] as String};

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Payroll', style: Theme.of(context).textTheme.headlineMedium),
                          ElevatedButton.icon(
                            onPressed: () => _showCreateSheet(data.staff),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New run'),
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
                        hintText: 'Search by employee name or pay period...',
                        onSearch: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        sorts: [
                          SortOptions.sortByAmount,
                          SortOptions.sortByDate,
                        ],
                        currentSortValue: _sortOption?.value,
                        onSortSelected: (option) {
                          setState(() {
                            _sortOption = option;
                            _future = _load();
                          });
                        },
                      ),
                    ),
                  ),

                  if (data.runs.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No payroll runs yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          _filterPayrollRuns(data.runs, nameById).map((run) {
                            final status = run['status'] as String;
                            final statusColor = switch (status) {
                              'paid' => AppColors.success,
                              'approved' => AppColors.primary,
                              'pending_approval' => AppColors.warning,
                              'rejected' => AppColors.error,
                              _ => AppColors.textSecondary,
                            };
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nameById[run['employee_id']] ?? 'Unknown', style: Theme.of(context).textTheme.titleMedium),
                                          Text(run['pay_period'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${(run['net_amount'] as num).toStringAsFixed(0)}',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        GlassChip(label: status.replaceAll('_', ' '), color: statusColor),
                                      ],
                                    ),
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

class _PayrollData {
  _PayrollData({required this.runs, required this.staff});

  final List<Map<String, dynamic>> runs;
  final List<Map<String, dynamic>> staff;
}
