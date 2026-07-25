import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/receipt_generator.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Admin front page (the shell sidebar's "Overview" item). Kept to genuinely
/// important-at-a-glance info only: the recent-payments feed with per-payment receipt
/// generation. The Quick Links list that used to live here has moved into the persistent
/// sidebar (see nav_config.dart + role_shell.dart) — this page no longer duplicates them.
/// Receipt-generation data logic is UNCHANGED from before (real PDF + storage upload).
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadRecentPayments(client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final payments = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text('Admin Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Text('Recent Payments', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        if (payments.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No payments recorded yet.'))
                        else
                          ...payments.map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('₹${(p['amount'] as num).toStringAsFixed(2)} — ${p['method']}', style: Theme.of(context).textTheme.titleMedium),
                                            Text('Status: ${p['status']} · ${_formatDate(p['created_at'] as String?)}', style: Theme.of(context).textTheme.bodyMedium),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                                        tooltip: 'Generate receipt',
                                        onPressed: () => _generateReceipt(context, client, p),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        const SizedBox(height: 16),
                        Text(
                          'Use the sidebar to reach approvals, payroll, vendors, and all operations.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
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

  Future<List<Map<String, dynamic>>> _loadRecentPayments(SupabaseClient client) async {
    final result = await client
        .schema('finance')
        .from('payments')
        .select('id, invoice_id, amount, method, status, created_at')
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<void> _generateReceipt(BuildContext context, SupabaseClient client, Map<String, dynamic> payment) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating receipt...')));
    try {
      final invoice = await client
          .schema('finance')
          .from('invoices')
          .select('student_id, invoice_number, gst_rate, gst_amount')
          .eq('id', payment['invoice_id'])
          .maybeSingle();

      String studentName = 'Unknown';
      String admissionNumber = '—';
      if (invoice != null) {
        final student = await client
            .schema('public')
            .from('students')
            .select('full_name, admission_number')
            .eq('id', invoice['student_id'])
            .maybeSingle();
        if (student != null) {
          studentName = student['full_name'] as String;
          admissionNumber = student['admission_number'] as String;
        }
      }

      final url = await ReceiptGenerator.generateAndUpload(
        client: client,
        paymentId: payment['id'] as String,
        studentName: studentName,
        admissionNumber: admissionNumber,
        amount: (payment['amount'] as num).toDouble(),
        method: payment['method'] as String,
        status: payment['status'] as String,
        paidAt: DateTime.parse(payment['created_at'] as String),
        invoiceNumber: invoice?['invoice_number'] as String?,
        gstRate: (invoice?['gst_rate'] as num?)?.toDouble(),
        gstAmount: (invoice?['gst_amount'] as num?)?.toDouble(),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate receipt: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}
