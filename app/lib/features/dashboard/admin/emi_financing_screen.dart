import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// EMI/Financing — the feature file's named differentiator. Lists real unpaid
/// invoices (finance.invoices where amount_due > amount_paid), lets an admin set up a
/// payment plan splitting the remaining balance into installments
/// (finance.payment_plans + finance.payment_plan_installments).
///
/// SCOPE: this creates the PLAN and its installment schedule — it does not (yet)
/// automatically mark installments 'paid' when a real payment comes in, or send
/// reminders. Those would need to hook into the existing Razorpay webhook flow
/// (services with payment reconciliation) — flagged as a real follow-up, not silently
/// implied to work end-to-end.
class EmiFinancingScreen extends ConsumerStatefulWidget {
  const EmiFinancingScreen({super.key});

  @override
  ConsumerState<EmiFinancingScreen> createState() => _EmiFinancingScreenState();
}

class _EmiFinancingScreenState extends ConsumerState<EmiFinancingScreen> {
  late Future<_EmiData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_EmiData> _load() async {
    final client = ref.read(supabaseClientProvider);

    final invoicesRaw = await client
        .schema('finance')
        .from('invoices')
        .select('id, student_id, amount_due, amount_paid, due_date')
        .order('due_date');
    final invoices = List<Map<String, dynamic>>.from(invoicesRaw as List)
        .where((i) => (i['amount_due'] as num) > (i['amount_paid'] as num))
        .toList();

    final studentIds = invoices.map((i) => i['student_id'] as String).toSet().toList();
    final students = studentIds.isEmpty
        ? []
        : await client.schema('public').from('students').select('id, full_name').inFilter('id', studentIds);
    final nameByStudentId = {for (final s in students) s['id'] as String: s['full_name'] as String};

    final plans = await client
        .schema('finance')
        .from('payment_plans')
        .select('id, invoice_id, total_installments, installment_amount, status')
        .order('created_at', ascending: false);

    return _EmiData(
      unpaidInvoices: invoices,
      nameByStudentId: nameByStudentId,
      existingPlans: List<Map<String, dynamic>>.from(plans as List),
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

      // Generate the installment schedule — monthly, starting next month.
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
              final invoiceIdsWithPlans = data.existingPlans.map((p) => p['invoice_id']).toSet();

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('EMI / Fee Financing', style: Theme.of(context).textTheme.headlineMedium),
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
}

class _EmiData {
  _EmiData({required this.unpaidInvoices, required this.nameByStudentId, required this.existingPlans});
  final List<Map<String, dynamic>> unpaidInvoices;
  final Map<String, String> nameByStudentId;
  final List<Map<String, dynamic>> existingPlans;
}
