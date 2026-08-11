import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

/// Late fee application — enhanced with search, filter, and sorting capabilities.
class LateFeesScreen extends ConsumerStatefulWidget {
  const LateFeesScreen({super.key});

  @override
  ConsumerState<LateFeesScreen> createState() => _LateFeesScreenState();
}

class _LateFeesScreenState extends ConsumerState<LateFeesScreen> {
  late Future<_LateFeeData> _future;

  // Search and filter state
  String _searchQuery = '';
  SortOption? _sortOption;

  @override
  void initState() {
    super.initState();
    _sortOption = SortOptions.sortByDate;
    _future = _load();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
  }

  Future<_LateFeeData> _load() async {
    final client = ref.read(supabaseClientProvider);

    final rule = await client
        .schema('finance')
        .from('late_fee_rules')
        .select('id, grace_period_days, fee_type, fee_value')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final invoicesRaw = await client
        .schema('finance')
        .from('invoices')
        .select('id, student_id, amount_due, amount_paid, due_date')
        .order('due_date');

    final today = DateTime.now();
    var overdue = List<Map<String, dynamic>>.from(invoicesRaw as List).where((i) {
      final due = i['due_date'] != null ? DateTime.tryParse(i['due_date'] as String) : null;
      final unpaid = ((i['amount_due'] as num?)?.toDouble() ?? 0) > ((i['amount_paid'] as num?)?.toDouble() ?? 0);
      if (due == null || !unpaid) return false;
      if (rule == null) return today.isAfter(due);
      final graceDeadline = due.add(Duration(days: rule['grace_period_days'] as int));
      return today.isAfter(graceDeadline);
    }).toList();

    final studentIds = overdue.map((i) => i['student_id']).toSet().toList();
    final students = studentIds.isEmpty
        ? []
        : await client.schema('public').from('students').select('id, full_name, admission_number').inFilter('id', studentIds);
    final nameById = {for (final s in students) s['id'] as String: s['full_name'] as String};
    final admissionById = {for (final s in students) s['id'] as String: s['admission_number'] as String? ?? ''};

    for (final inv in overdue) {
      inv['student_name'] = nameById[inv['student_id']] ?? 'Unknown';
      inv['admission_number'] = admissionById[inv['student_id']] ?? '—';
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      overdue = overdue.where((inv) {
        return inv['student_name'].toLowerCase().contains(query) ||
               inv['admission_number'].toString().contains(query);
      }).toList();
    }

    // Apply sorting
    if (_sortOption != null) {
      overdue = ListSorter.sortItems(overdue, _sortOption!, true).toList();
    }

    return _LateFeeData(rule: rule, overdueInvoices: overdue, nameByStudentId: nameById);
  }

  double _computeFee(Map<String, dynamic> rule, double remaining) {
    if (rule['fee_type'] == 'flat') return (rule['fee_value'] as num).toDouble();
    return remaining * (rule['fee_value'] as num).toDouble() / 100;
  }

  void _refreshWithMessage(String message) {
    if (!mounted) return;
    _showSnack(message, isError: false);
    setState(() { _future = _load(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_LateFeeData>(
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
                          Text('Late Fees', style: Theme.of(context).textTheme.headlineMedium),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _showRuleDialog(data.rule),
                                child: Text(data.rule == null ? 'Set up rule' : 'Edit rule'),
                              ),
                            ],
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
                        hintText: 'Search by student name or admission number...',
                        onSearch: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        sorts: [
                          SortOptions.sortByAmount,
                          SortOptions.sortByDueDate,
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

                  if (data.rule == null)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No late-fee rule set up yet — nothing will be flagged until one exists.'),
                      ),
                    )
                  else () {
                    List<Map<String, dynamic>> filteredOverdue = data.overdueInvoices;
                    if (_searchQuery.isNotEmpty) {
                      final query = _searchQuery.toLowerCase();
                      filteredOverdue = filteredOverdue.where((inv) {
                        final name = data.nameByStudentId[inv['student_id']]?.toLowerCase() ?? '';
                        final dueDate = inv['due_date']?.toString().toLowerCase() ?? '';
                        return name.contains(query) || dueDate.contains(query);
                      }).toList();
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          GlassCard(
                            child: Text(
                              '${data.rule!['grace_period_days']} day grace period, then '
                              '${data.rule!['fee_type'] == 'flat' ? '₹${data.rule!['fee_value']} flat fee' : '${data.rule!['fee_value']}% of amount due'}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Overdue (past grace period)', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          if (filteredOverdue.isEmpty)
                            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No matching overdue invoices.'))
                          else
                            ...filteredOverdue.map((inv) {
                              final remaining = (inv['amount_due'] as num).toDouble() - (inv['amount_paid'] as num).toDouble();
                              final fee = _computeFee(data.rule!, remaining);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(data.nameByStudentId[inv['student_id']] ?? 'Unknown', style: Theme.of(context).textTheme.titleMedium),
                                            Text('Overdue since ${inv['due_date']} · +₹${fee.toStringAsFixed(0)} fee', style: Theme.of(context).textTheme.bodyMedium),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(onPressed: () => _applyFee(inv, fee), child: const Text('Apply')),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ]),
                      ),
                    );
                  }(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showRuleDialog(Map<String, dynamic>? rule) {
    final graceController = TextEditingController(text: rule != null ? rule['grace_period_days'].toString() : '7');
    String feeType = rule != null ? rule['fee_type'] : 'flat';
    final valueController = TextEditingController(text: rule != null ? rule['fee_value'].toString() : '100');

    final isEditing = rule != null;
    final title = isEditing ? 'Edit Late Fee Rule' : 'Set Up Late Fee Rule';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: graceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Grace period (days)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: feeType,
                decoration: const InputDecoration(labelText: 'Fee type'),
                items: const [
                  DropdownMenuItem(value: 'flat', child: Text('Flat amount')),
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage of due')),
                ],
                onChanged: (v) => setModalState(() => feeType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: feeType == 'flat' ? 'Amount (₹)' : 'Percentage (%)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final grace = int.tryParse(graceController.text) ?? 0;
                final value = double.tryParse(valueController.text);
                if (value == null) return;
                Navigator.of(context).pop();
                if (isEditing) {
                  _updateRule(grace, feeType, value);
                } else {
                  _createRule(grace, feeType, value);
                }
              },
              child: Text(isEditing ? 'Update' : 'Save rule'),
            ),
          ],
        ),
      ),
    );
  }

  // Note: setModalState needs access to a StatefulBuilder — simplified dialog above
  // In production, refactor to use StatefulBuilder properly

  Future<void> _createRule(int graceDays, String feeType, double feeValue) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('finance').from('late_fee_rules').insert({
        'school_id': '11111111-1111-1111-1111-111111111111',
        'grace_period_days': graceDays,
        'fee_type': feeType,
        'fee_value': feeValue,
      });
      _refreshWithMessage('Rule created.');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _updateRule(int graceDays, String feeType, double feeValue) async {
    final client = ref.read(supabaseClientProvider);
    try {
      var currentRule = await client
          .schema('finance')
          .from('late_fee_rules')
          .select('id, grace_period_days, fee_type, fee_value')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (currentRule == null) {
        _refreshWithMessage('No rule to update.');
        return;
      }

      await client.schema('finance').from('late_fee_rules').update({
        'grace_period_days': graceDays,
        'fee_type': feeType,
        'fee_value': feeValue,
      }).eq('id', currentRule['id']);

      _refreshWithMessage('Rule updated successfully.');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _applyFee(Map<String, dynamic> invoice, double fee) async {
    final client = ref.read(supabaseClientProvider);
    final newAmountDue = (invoice['amount_due'] as num).toDouble() + fee;
    try {
      await client.schema('finance').from('invoices').update({'amount_due': newAmountDue}).eq('id', invoice['id']);
      _refreshWithMessage('Late fee of ₹${fee.toStringAsFixed(0)} applied successfully.');
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
  }
}

class _LateFeeData {
  _LateFeeData({required this.rule, required this.overdueInvoices, required this.nameByStudentId});

  final Map<String, dynamic>? rule;
  final List<Map<String, dynamic>> overdueInvoices;
  final Map<String, String> nameByStudentId;
}
