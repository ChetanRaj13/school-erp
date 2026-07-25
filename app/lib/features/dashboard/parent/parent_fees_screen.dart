import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/receipt_generator.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Parent Fees — due amounts, due dates, real payment history, downloadable receipts
/// (reuses the exact same ReceiptGenerator already verified for Admin), and an EMI
/// self-request.
///
/// HONEST GAP, stated directly in the UI, not hidden: "Pay Online" does NOT open a
/// real Razorpay checkout. Only a webhook (which RECEIVES payment confirmation from
/// Razorpay) has ever been verified in this project — there's no confirmed
/// order-creation backend endpoint for the app to call first. Faking a "payment
/// successful" flow client-side would be a genuine security hole (anyone could mark
/// their own fee paid without paying) — so this button is deliberately disabled with
/// a clear explanation rather than pretending to work.
class ParentFeesScreen extends ConsumerStatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  ConsumerState<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends ConsumerState<ParentFeesScreen> {
  String? _selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(selfChildrenProvider);
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (children) {
              if (children.isEmpty) {
                return const Center(child: Text('No children linked to your account yet.'));
              }
              final selected = children.firstWhere((c) => c.studentId == _selectedStudentId, orElse: () => children.first);

              return FutureBuilder<_FeesData>(
                future: _load(client, selected.studentId),
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
                          child: Text('Fees — ${selected.fullName}', style: Theme.of(context).textTheme.headlineMedium),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Text('Outstanding', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 10),
                            if (data.unpaidInvoices.isEmpty)
                              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nothing due right now.'))
                            else
                              ...data.unpaidInvoices.map((inv) {
                                final remaining = (inv['amount_due'] as num).toDouble() - (inv['amount_paid'] as num).toDouble();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GlassCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('₹${remaining.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineMedium),
                                            Text('due ${inv['due_date']}', style: Theme.of(context).textTheme.bodyMedium),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => _showEmiRequestSheet(inv, remaining),
                                                child: const Text('Request EMI'),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Tooltip(
                                                message: 'Online payment isn\'t fully wired up yet — please pay via the school office for now.',
                                                child: ElevatedButton(
                                                  onPressed: null,
                                                  child: const Text('Pay Online'),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            const SizedBox(height: 24),
                            Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 10),
                            if (data.paymentHistory.isEmpty)
                              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No payments recorded yet.'))
                            else
                              ...data.paymentHistory.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: GlassCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('₹${(p['amount'] as num).toStringAsFixed(0)} · ${p['method']}'),
                                                Text('${p['created_at']}'.split('T').first, style: Theme.of(context).textTheme.bodySmall),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                                            tooltip: 'Download receipt',
                                            onPressed: () => _downloadReceipt(p, selected.fullName, selected.admissionNumber),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_FeesData> _load(SupabaseClient client, String studentId) async {
    final invoicesRaw = await client
        .schema('finance')
        .from('invoices')
        .select('id, amount_due, amount_paid, due_date, invoice_number')
        .eq('student_id', studentId)
        .order('due_date');
    final invoices = List<Map<String, dynamic>>.from(invoicesRaw as List);
    final unpaid = invoices.where((i) => (i['amount_due'] as num) > (i['amount_paid'] as num)).toList();

    final invoiceIds = invoices.map((i) => i['id']).toList();
    final payments = invoiceIds.isEmpty
        ? []
        : await client.schema('finance').from('payments').select('id, invoice_id, amount, method, status, created_at').inFilter('invoice_id', invoiceIds).order('created_at', ascending: false);

    return _FeesData(unpaidInvoices: unpaid, paymentHistory: List<Map<String, dynamic>>.from(payments));
  }

  Future<void> _downloadReceipt(Map<String, dynamic> payment, String studentName, String admissionNumber) async {
    final client = ref.read(supabaseClientProvider);
    try {
      final url = await ReceiptGenerator.generateAndUpload(
        client: client,
        paymentId: payment['id'] as String,
        studentName: studentName,
        admissionNumber: admissionNumber,
        amount: (payment['amount'] as num).toDouble(),
        method: payment['method'] as String,
        status: payment['status'] as String,
        paidAt: DateTime.parse(payment['created_at'] as String),
      );
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  void _showEmiRequestSheet(Map<String, dynamic> invoice, double remaining) {
    int installments = 3;
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
                Text('Request Payment Plan', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('₹${remaining.toStringAsFixed(0)} remaining', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [3, 6, 12].map((n) {
                    final sel = installments == n;
                    return ChoiceChip(
                      label: Text('$n months (₹${(remaining / n).toStringAsFixed(0)}/mo)'),
                      selected: sel,
                      onSelected: (_) => setModalState(() => installments = n),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textPrimary),
                      backgroundColor: AppColors.glassFill,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your request goes to the school office for approval — this doesn\'t create an active plan immediately.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _submitEmiRequest(invoice, installments, remaining);
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

  Future<void> _submitEmiRequest(Map<String, dynamic> invoice, int installments, double remaining) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('finance').from('payment_plans').insert({
        'invoice_id': invoice['id'],
        'total_installments': installments,
        'installment_amount': remaining / installments,
        'start_date': DateTime.now().toIso8601String().split('T').first,
        'status': 'requested',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted — awaiting school approval.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }
}

class _FeesData {
  _FeesData({required this.unpaidInvoices, required this.paymentHistory});
  final List<Map<String, dynamic>> unpaidInvoices;
  final List<Map<String, dynamic>> paymentHistory;
}
