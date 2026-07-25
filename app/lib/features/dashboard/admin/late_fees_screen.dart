import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Late fee application. finance.late_fee_rules holds the RULE (grace period +
/// flat/percentage fee); THIS SCREEN is the "engine" that actually applies it —
/// previously the rule table existed with nothing reading it. Computation happens
/// client-side (compute preview, then a real UPDATE to finance.invoices.amount_due) —
/// architecturally this would be better as a scheduled backend job for a real
/// production system, but for a hackathon demo, an explicit admin-triggered "Apply"
/// action is honest (nothing silently happens in the background) and simpler to
/// verify than a cron job neither of us can watch run.
class LateFeesScreen extends ConsumerStatefulWidget {
  const LateFeesScreen({super.key});

  @override
  ConsumerState<LateFeesScreen> createState() => _LateFeesScreenState();
}

class _LateFeesScreenState extends ConsumerState<LateFeesScreen> {
  late Future<_LateFeeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
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
    final overdue = List<Map<String, dynamic>>.from(invoicesRaw as List).where((i) {
      final due = DateTime.tryParse(i['due_date'] as String);
      final unpaid = (i['amount_due'] as num) > (i['amount_paid'] as num);
      if (due == null || !unpaid) return false;
      if (rule == null) return today.isAfter(due);
      final graceDeadline = due.add(Duration(days: rule['grace_period_days'] as int));
      return today.isAfter(graceDeadline);
    }).toList();

    final studentIds = overdue.map((i) => i['student_id']).toSet().toList();
    final students = studentIds.isEmpty
        ? []
        : await client.schema('public').from('students').select('id, full_name').inFilter('id', studentIds);
    final nameById = {for (final s in students) s['id'] as String: s['full_name'] as String};

    return _LateFeeData(rule: rule, overdueInvoices: overdue, nameByStudentId: nameById);
  }

  double _computeFee(Map<String, dynamic> rule, double remaining) {
    if (rule['fee_type'] == 'flat') return (rule['fee_value'] as num).toDouble();
    return remaining * (rule['fee_value'] as num).toDouble() / 100;
  }

  Future<void> _createRule(int graceDays, String feeType, double feeValue) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('finance').from('late_fee_rules').insert({
        'school_id': '11111111-1111-1111-1111-111111111111',
        'grace_period_days': graceDays,
        'fee_type': feeType,
        'fee_value': feeValue,
      });
      _refresh('Rule created.');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _applyFee(Map<String, dynamic> invoice, double fee) async {
    final client = ref.read(supabaseClientProvider);
    final newAmountDue = (invoice['amount_due'] as num).toDouble() + fee;
    try {
      await client.schema('finance').from('invoices').update({'amount_due': newAmountDue}).eq('id', invoice['id']);
      _refresh('Late fee of ₹${fee.toStringAsFixed(0)} applied.');
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

  void _showRuleSheet() {
    final graceController = TextEditingController(text: '7');
    String feeType = 'flat';
    final valueController = TextEditingController(text: '100');

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
                Text('Late Fee Rule', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
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
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final grace = int.tryParse(graceController.text) ?? 0;
                    final value = double.tryParse(valueController.text);
                    if (value == null) return;
                    Navigator.of(context).pop();
                    _createRule(grace, feeType, value);
                  },
                  child: const Text('Save rule'),
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
                          OutlinedButton(onPressed: _showRuleSheet, child: Text(data.rule == null ? 'Set up rule' : 'Edit rule')),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (data.rule == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('No late-fee rule set up yet — nothing will be flagged until one exists.'),
                          )
                        else
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
                        if (data.overdueInvoices.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Nothing overdue right now.'))
                        else
                          ...data.overdueInvoices.map((inv) {
                            final remaining = (inv['amount_due'] as num).toDouble() - (inv['amount_paid'] as num).toDouble();
                            final fee = data.rule == null ? 0.0 : _computeFee(data.rule!, remaining);
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
                                    if (data.rule != null)
                                      ElevatedButton(onPressed: () => _applyFee(inv, fee), child: const Text('Apply')),
                                  ],
                                ),
                              ),
                            );
                          }),
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
}

class _LateFeeData {
  _LateFeeData({required this.rule, required this.overdueInvoices, required this.nameByStudentId});
  final Map<String, dynamic>? rule;
  final List<Map<String, dynamic>> overdueInvoices;
  final Map<String, String> nameByStudentId;
}
