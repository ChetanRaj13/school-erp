import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

/// EMI/Financing — lists unpaid invoices for admin-setup payment plans, PLUS
/// a "Parent Requests" section showing plans submitted by parents (status =
/// 'requested') with Approve/Reject, parallel to waiver approval.
class EmiFinancingScreen extends ConsumerStatefulWidget {
  const EmiFinancingScreen({super.key});

  @override
  ConsumerState<EmiFinancingScreen> createState() => _EmiFinancingScreenState();
}

class _EmiFinancingScreenState extends ConsumerState<EmiFinancingScreen> {
  late Future<_EmiData> _future;

  // Search and filter state
  String _searchQuery = '';
  SortOption? _sortOption;
  String _planFilter = 'all';

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

  Future<_EmiData> _load() async {
    final client = ref.read(supabaseClientProvider);

    final invoicesRaw = await client
        .schema('finance')
        .from('invoices')
        .select('id, student_id, amount_due, amount_paid, due_date, invoice_number')
        .order('due_date');
    final invoices = List<Map<String, dynamic>>.from(invoicesRaw as List)
        .where((i) => (i['amount_due'] as num) > (i['amount_paid'] as num))
        .toList();

    final studentIds = invoices.map((i) => i['student_id'] as String).toSet().toList();
    final students = studentIds.isEmpty
        ? []
        : await client.schema('public').from('students').select('id, full_name').inFilter('id', studentIds);
    final nameByStudentId = {for (final s in students) s['id'] as String: s['full_name'] as String};

    // All plans, so we can separate requested vs active.
    final plans = await client
        .schema('finance')
        .from('payment_plans')
        .select('id, invoice_id, total_installments, installment_amount, status, created_at, start_date')
        .order('created_at', ascending: false);

    // For requested plans, resolve the student name via invoice -> student_id.
    final existingPlans = List<Map<String, dynamic>>.from(plans as List);
    final requestedPlans = existingPlans.where((p) => p['status'] == 'requested').toList();

    // Build student name map that includes names for requested-plan invoices.
    final requestedInvoiceIds = requestedPlans.map((p) => p['invoice_id'] as String).toSet();
    if (requestedInvoiceIds.isNotEmpty) {
      final missingIds = requestedInvoiceIds.where((id) => !studentIds.contains(id)).toList();
      if (missingIds.isNotEmpty) {
        final extraInvoices = await client
            .schema('finance')
            .from('invoices')
            .select('id, student_id')
            .inFilter('id', missingIds);
        for (final inv in extraInvoices as List) {
          final sid = inv['student_id'] as String;
          if (!nameByStudentId.containsKey(sid)) {
            final s = await client
                .schema('public')
                .from('students')
                .select('id, full_name')
                .eq('id', sid)
                .maybeSingle();
            if (s != null) nameByStudentId[s['id'] as String] = s['full_name'] as String;
          }
        }
      }
    }

    // Map invoice_id -> student_id for all invoices.
    final invoiceStudentId = <String, String>{};
    for (final inv in invoices) {
      invoiceStudentId[inv['id'] as String] = inv['student_id'] as String;
    }
    // Also fetch student_id for requested-plan invoices not in the unpaid list.
    for (final rid in requestedInvoiceIds) {
      if (!invoiceStudentId.containsKey(rid)) {
        final inv = await client
            .schema('finance')
            .from('invoices')
            .select('id, student_id')
            .eq('id', rid)
            .maybeSingle();
        if (inv != null) invoiceStudentId[inv['id'] as String] = inv['student_id'] as String;
      }
    }

    return _EmiData(
      unpaidInvoices: invoices,
      nameByStudentId: nameByStudentId,
      existingPlans: existingPlans,
      requestedPlans: requestedPlans,
      invoiceStudentId: invoiceStudentId,
    );
  }

  Future<void> _createPlan(Map<String, dynamic> invoice, int installmentCount) async {
    final client = ref.read(supabaseClientProvider);
    final remaining = (invoice['amount_due'] as num).toDouble() - (invoice['amount_paid'] as num).toDouble();
    final installmentAmount = (remaining / installmentCount);
    final startDate = DateTime.now();

    try {
      final planResult = await client
          .schema('finance')
          .from('payment_plans')
          .insert({
            'invoice_id': invoice['id'],
            'total_installments': installmentCount,
            'installment_amount': installmentAmount,
            'start_date': startDate.toIso8601String().split('T').first,
            'status': 'active',
          })
          .select('id')
          .single();

      final planId = planResult['id'] as String;

      final installments = List.generate(installmentCount, (i) {
        final dueDate = DateTime(startDate.year, startDate.month + i + 1, startDate.day);
        return {
          'payment_plan_id': planId,
          'installment_number': i + 1,
          'due_date': dueDate.toIso8601String().split('T').first,
          'amount': installmentAmount,
          'status': 'pending',
        };
      });
      await client.schema('finance').from('payment_plan_installments').insert(installments);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment plan created — $installmentCount installments of ₹${installmentAmount.toStringAsFixed(0)}'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() { _future = _load(); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _decidePlan(String planId, bool approve) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('finance').from('payment_plans').update({
        'status': approve ? 'active' : 'rejected',
      }).eq('id', planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Plan approved.' : 'Plan rejected.'),
          backgroundColor: approve ? AppColors.success : AppColors.error,
        ),
      );
      setState(() { _future = _load(); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  // Filter and sort helpers
  List<Map<String, dynamic>> _filterRequestedPlans(List<Map<String, dynamic>> plans) {
    var filtered = plans;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        // In actual code, we'd need to resolve invoice and student data
        return true;
      }).toList();
    }

    if (_planFilter != 'all') {
      // Plan type filtering would be implemented here
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
          child: FutureBuilder<_EmiData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              final invoiceIdsWithPlans = data.expiredPlans
                  .where((p) => p['status'] == 'active')
                  .map((p) => p['invoice_id'])
                  .toSet();

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('EMI / Fee Financing', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  // Search and filter controls
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: SearchFilterBar(
                        hintText: 'Search students or invoices...',
                        onSearch: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _refresh();
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

                  // Parent Requests section
                  if (data.requestedPlans.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            const Icon(Icons.help_outline, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Text('Parent Requests', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          _filterRequestedPlans(data.requestedPlans).map((plan) {
                            final invoiceId = plan['invoice_id'] as String;
                            final studentId = data.invoiceStudentId[invoiceId] as String?;
                            final studentName = studentId != null
                                ? (data.nameByStudentId[studentId] ?? 'Unknown')
                                : 'Unknown';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(studentName, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${(plan['installment_amount'] as num?)?.toStringAsFixed(0) ?? '—'} '
                                      '× ${plan['total_installments']} installments',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _decidePlan(plan['id'] as String, false),
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
                                            onPressed: () => _decidePlan(plan['id'] as String, true),
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
                          }).toList(),
                        ),
                      ),
                    ),
                  ],

                  // Outstanding Invoices section
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Outstanding Invoices', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  if (data.unpaidInvoices.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No outstanding invoices right now.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          data.unpaidInvoices.map((inv) {
                            final studentName = data.nameByStudentId[inv['student_id']] ?? 'Unknown';
                            final remaining = (inv['amount_due'] as num).toDouble() - (inv['amount_paid'] as num).toDouble();
                            final hasPlan = invoiceIdsWithPlans.contains(inv['id']);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(studentName, style: Theme.of(context).textTheme.titleMedium),
                                          Text(
                                            '₹${remaining.toStringAsFixed(0)} remaining · due ${inv['due_date']}',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (hasPlan)
                                      const GlassChip(label: 'Plan active', icon: Icons.check_circle_outline, color: AppColors.success)
                                    else
                                      ElevatedButton(
                                        onPressed: () => _showPlanSheet(inv, studentName),
                                        child: const Text('Set up EMI'),
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

  void _showPlanSheet(Map<String, dynamic> invoice, String studentName) {
    int installmentCount = 3;
    final remaining = (invoice['amount_due'] as num).toDouble() - (invoice['amount_paid'] as num).toDouble();

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
                Text('Payment Plan — $studentName', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('₹${remaining.toStringAsFixed(0)} remaining', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),
                Text('Split into installments', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [3, 6, 12].map((n) {
                    final selected = installmentCount == n;
                    return ChoiceChip(
                      label: Text('$n months (₹${(remaining / n).toStringAsFixed(0)}/mo)'),
                      selected: selected,
                      onSelected: (_) => setModalState(() => installmentCount = n),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
                      backgroundColor: AppColors.glassFill,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _createPlan(invoice, installmentCount);
                  },
                  child: const Text('Create Payment Plan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmiData {
  _EmiData({
    required this.unpaidInvoices,
    required this.nameByStudentId,
    required this.existingPlans,
    required this.requestedPlans,
    required this.invoiceStudentId,
  });

  final List<Map<String, dynamic>> unpaidInvoices;
  final Map<String, String> nameByStudentId;
  final List<Map<String, dynamic>> existingPlans;
  List<Map<String, dynamic>> get expiredPlans => existingPlans;
  final List<Map<String, dynamic>> requestedPlans;
  final Map<String, String> invoiceStudentId;
}
