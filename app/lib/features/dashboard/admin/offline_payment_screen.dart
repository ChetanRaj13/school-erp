import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/receipt_generator.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Offline Payment Entry — the missing piece: right now finance.payments only ever
/// gets a row from the Razorpay webhook (real online payments) or from dummy-data SQL.
/// There was no way for an admin to record "a parent paid ₹5000 cash today." This
/// screen closes that gap: pick a student's real unpaid invoice, record what was
/// actually received, and immediately offer a real receipt — reusing the exact same
/// ReceiptGenerator already built and verified for online payments, not a separate
/// mechanism. Records who entered it (approved_by) for a real audit trail.
class OfflinePaymentScreen extends ConsumerStatefulWidget {
  const OfflinePaymentScreen({super.key});

  @override
  ConsumerState<OfflinePaymentScreen> createState() => _OfflinePaymentScreenState();
}

class _OfflinePaymentScreenState extends ConsumerState<OfflinePaymentScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadUnpaidInvoices();
  }

  Future<List<Map<String, dynamic>>> _loadUnpaidInvoices() async {
    final client = ref.read(supabaseClientProvider);
    final invoicesRaw = await client
        .schema('finance')
        .from('invoices')
        .select('id, student_id, amount_due, amount_paid, due_date, invoice_number')
        .order('due_date');
    final unpaid = List<Map<String, dynamic>>.from(invoicesRaw as List)
        .where((i) => (i['amount_due'] as num) > (i['amount_paid'] as num))
        .toList();

    final studentIds = unpaid.map((i) => i['student_id']).toSet().toList();
    final students = studentIds.isEmpty
        ? []
        : await client.schema('public').from('students').select('id, full_name, admission_number').inFilter('id', studentIds);
    final nameById = {for (final s in students) s['id'] as String: s['full_name'] as String};
    final admissionById = {for (final s in students) s['id'] as String: s['admission_number'] as String};

    for (final inv in unpaid) {
      inv['student_name'] = nameById[inv['student_id']] ?? 'Unknown';
      inv['admission_number'] = admissionById[inv['student_id']] ?? '—';
    }
    return unpaid;
  }

  Future<void> _recordPayment(Map<String, dynamic> invoice, double amount, String method, String? reference) async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    try {
      final payment = await client
          .schema('finance')
          .from('payments')
          .insert({
            'invoice_id': invoice['id'],
            'amount': amount,
            'method': method,
            'status': 'success',
            'reference_number': reference,
            'approved_by': selfStaffId,
          })
          .select('id, created_at')
          .single();

      // Atomic increment via the Postgres RPC function — replaces the previous
      // read-modify-write pattern that had a race condition.
      await client.rpc('increment_invoice_paid', params: {
        'p_invoice_id': invoice['id'],
        'p_amount': amount,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded.'), backgroundColor: AppColors.success),
      );
      setState(() { _future = _loadUnpaidInvoices(); });

      _offerReceipt(invoice, payment, amount, method);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _offerReceipt(Map<String, dynamic> invoice, Map<String, dynamic> payment, double amount, String method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment recorded'),
        content: Text('₹${amount.toStringAsFixed(0)} received from ${invoice['student_name']}. Generate a receipt now?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Later')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final client = ref.read(supabaseClientProvider);
              try {
                final url = await ReceiptGenerator.generateAndUpload(
                  client: client,
                  paymentId: payment['id'] as String,
                  studentName: invoice['student_name'] as String,
                  admissionNumber: invoice['admission_number'] as String,
                  amount: amount,
                  method: method,
                  status: 'success',
                  paidAt: DateTime.parse(payment['created_at'] as String),
                  invoiceNumber: invoice['invoice_number'] as String?,
                );
                await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Receipt generation failed: $e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Generate receipt'),
          ),
        ],
      ),
    );
  }

  void _showRecordSheet(Map<String, dynamic> invoice) {
    final remaining = (invoice['amount_due'] as num).toDouble() - (invoice['amount_paid'] as num).toDouble();
    final amountController = TextEditingController(text: remaining.toStringAsFixed(0));
    final referenceController = TextEditingController();
    String method = 'cash';

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
                Text('Record Payment — ${invoice['student_name']}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('₹$remaining remaining', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'demand_draft', child: Text('Demand Draft')),
                  ],
                  onChanged: (v) => setModalState(() => method = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount received (₹)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referenceController,
                  decoration: InputDecoration(
                    labelText: method == 'cash' ? 'Reference (optional)' : 'Cheque/DD number',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) return;
                    Navigator.of(context).pop();
                    _recordPayment(invoice, amount, method, referenceController.text.trim().isEmpty ? null : referenceController.text.trim());
                  },
                  child: const Text('Record payment'),
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
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final invoices = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Offline Payment Entry', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Record a cash, cheque, or demand draft payment received in person.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  if (invoices.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No outstanding invoices right now.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          invoices.map((inv) {
                            final remaining = (inv['amount_due'] as num).toDouble() - (inv['amount_paid'] as num).toDouble();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(inv['student_name'] as String, style: Theme.of(context).textTheme.titleMedium),
                                          Text('₹${remaining.toStringAsFixed(0)} remaining · due ${inv['due_date']}', style: Theme.of(context).textTheme.bodyMedium),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(onPressed: () => _showRecordSheet(inv), child: const Text('Record')),
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
