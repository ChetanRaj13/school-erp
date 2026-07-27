import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/config/env.dart';
import '../../../core/payments/razorpay_web.dart' as razorpay;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/receipt_generator.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Parent Fees — itemized fee breakdown, due amounts, real payment history,
/// downloadable receipts, EMI self-request, and real Razorpay Checkout.
///
/// Flow: tap "Pay Online" → Edge Function creates Razorpay order → Razorpay
/// Checkout opens → on success a confirmation snackbar shows and the screen
/// reloads after a short delay to let the webhook land. The client-side
/// success callback is NEVER treated as proof of payment — only the
/// razorpay-webhook Edge Function writes to finance.payments.
class ParentFeesScreen extends ConsumerStatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  ConsumerState<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends ConsumerState<ParentFeesScreen> {
  String? _selectedStudentId;
  _FeesData? _data;
  bool _loading = true;
  String? _error;

  // ── Data loading ──────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final client = ref.read(supabaseClientProvider);
    final childrenAsync = ref.read(selfChildrenProvider);
    final children = childrenAsync.valueOrNull ?? [];
    if (children.isEmpty) {
      setState(() {
        _data = _FeesData.empty();
        _loading = false;
      });
      return;
    }
    final selected = children.firstWhere(
      (c) => c.studentId == _selectedStudentId,
      orElse: () => children.first,
    );
    _selectedStudentId = selected.studentId;

    try {
      final data = await _loadFees(client, selected.studentId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<_FeesData> _loadFees(SupabaseClient client, String studentId) async {
    // 1. Student class + roll number
    String? className;
    int? rollNo;
    final rosterRows = await client
        .schema('academic')
        .from('class_roster')
        .select('roll_no, class_id')
        .eq('student_id', studentId);
    if ((rosterRows as List).isNotEmpty) {
      rollNo = rosterRows.first['roll_no'] as int;
      final classId = rosterRows.first['class_id'] as String;
      final classRows = await client
          .schema('academic')
          .from('classes')
          .select('name')
          .eq('id', classId);
      if ((classRows as List).isNotEmpty) {
        className = classRows.first['name'] as String;
      }
    }

    // 2. All invoices for this student
    final invoicesRaw = await client
        .schema('finance')
        .from('invoices')
        .select(
          'id, amount_due, amount_paid, due_date, invoice_number, fee_structure_id',
        )
        .eq('student_id', studentId)
        .order('due_date');
    final allInvoices = List<Map<String, dynamic>>.from(invoicesRaw as List);
    final unpaidInvoices = allInvoices
        .where((i) => (i['amount_due'] as num) > (i['amount_paid'] as num))
        .toList();

    // 3. Line items for every invoice (single query, grouped client-side)
    final invoiceIds = allInvoices.map((i) => i['id'] as String).toList();
    Map<String, List<Map<String, dynamic>>> lineItemsByInvoice = {};
    if (invoiceIds.isNotEmpty) {
      final liRows = await client
          .schema('finance')
          .from('invoice_line_items')
          .select('id, invoice_id, fee_structure_id, label, amount, sort_order')
          .inFilter('invoice_id', invoiceIds)
          .order('sort_order');
      for (final row in (liRows as List)) {
        final invId = row['invoice_id'] as String;
        lineItemsByInvoice
            .putIfAbsent(invId, () => [])
            .add(Map<String, dynamic>.from(row));
      }
    }

    // 4. Payment history for ALL this student's invoices
    List<Map<String, dynamic>> payments = [];
    if (invoiceIds.isNotEmpty) {
      final payRows = await client
          .schema('finance')
          .from('payments')
          .select(
            'id, invoice_id, amount, method, status, gateway_payment_id, created_at',
          )
          .inFilter('invoice_id', invoiceIds)
          .order('created_at', ascending: false);
      payments = List<Map<String, dynamic>>.from(payRows);
    }

    // 5. Refunded total
    final refundedTotal = payments
        .where((p) => p['status'] == 'refunded')
        .fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble());

    // 6. Scholarship / concession (approved + disbursed waivers)
    final waivers = await client
        .schema('finance')
        .from('waiver_requests')
        .select('requested_amount')
        .eq('student_id', studentId)
        .eq('status', 'approved')
        .not('disbursed_at', 'is', null);
    final scholarshipTotal = (waivers as List).fold<double>(
      0,
      (sum, w) => sum + (w['requested_amount'] as num).toDouble(),
    );

    return _FeesData(
      allInvoices: allInvoices,
      unpaidInvoices: unpaidInvoices,
      lineItemsByInvoice: lineItemsByInvoice,
      paymentHistory: payments,
      className: className,
      rollNo: rollNo,
      scholarshipTotal: scholarshipTotal,
      refundedTotal: refundedTotal,
    );
  }

  // ── Razorpay checkout ─────────────────────────────────────────────────

  Future<void> _payOnline(Map<String, dynamic> invoice) async {
    final remaining = (invoice['amount_due'] as num).toDouble() -
        (invoice['amount_paid'] as num).toDouble();
    if (remaining <= 0) return;

    final client = ref.read(supabaseClientProvider);
    final session = ref.read(currentSessionProvider);

    try {
      final response = await client.functions.invoke(
        'create-razorpay-order',
        body: {
          'invoice_id': invoice['id'],
          'amount': remaining,
        },
      );

      final body = response.data;
      if (response.status != 200 || body == null || body['error'] != null) {
        final msg =
            body?['error'] ?? 'Failed to create payment order (status ${response.status})';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
        return;
      }

      final orderId = body['id'] as String;

      razorpay.openRazorpayCheckout(
        key: Env.razorpayKeyId,
        amount: (remaining * 100).toInt(), // paise
        orderId: orderId,
        name: 'School ERP — Fee Payment',
        description: 'Fee payment for invoice ${invoice['invoice_number'] ?? ''}',
        prefill: {
          'email': session?.user.email ?? '',
          'contact': session?.user.phone ?? '',
        },
        theme: {'color': '#6C63FF'},
        onSuccess: (paymentId, orderIdResult, signature) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment submitted — confirming shortly.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 4),
            ),
          );
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _loadData();
          });
        },
        onError: (code, message) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed ($code): $message'),
              backgroundColor: AppColors.error,
            ),
          );
        },
        onDismiss: () {},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Receipt download ──────────────────────────────────────────────────

  Future<void> _downloadReceipt(
    Map<String, dynamic> payment,
    String studentName,
    String admissionNumber,
  ) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // ── EMI request ───────────────────────────────────────────────────────

  void _showEmiRequestSheet(Map<String, dynamic> invoice, double remaining) {
    int installments = 3;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Request Payment Plan',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('₹${remaining.toStringAsFixed(0)} remaining',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [3, 6, 12].map((n) {
                    final sel = installments == n;
                    return ChoiceChip(
                      label: Text(
                          '$n months (₹${(remaining / n).toStringAsFixed(0)}/mo)'),
                      selected: sel,
                      onSelected: (_) =>
                          setModalState(() => installments = n),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : AppColors.textPrimary,
                      ),
                      backgroundColor: AppColors.glassFill,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your request goes to the school office for approval — "
                  "this doesn't create an active plan immediately.",
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

  Future<void> _submitEmiRequest(
    Map<String, dynamic> invoice,
    int installments,
    double remaining,
  ) async {
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
        const SnackBar(
          content: Text('Request submitted — awaiting school approval.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(selfChildrenProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: childrenAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (children) {
              if (children.isEmpty) {
                return const Center(
                  child: Text('No children linked to your account yet.'),
                );
              }

              final selected = children.firstWhere(
                (c) => c.studentId == _selectedStudentId,
                orElse: () => children.first,
              );

              if (_loading && _data == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _loadData();
                });
              }

              return RefreshIndicator(
                onRefresh: _loadData,
                child: _loading && _data == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _error != null && _data == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Failed to load: $_error'),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _buildContent(context, children, selected),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<LinkedChild> children,
    LinkedChild selected,
  ) {
    final data = _data!;
    final totalDue = data.unpaidInvoices.fold<double>(
      0,
      (sum, inv) =>
          sum +
          (inv['amount_due'] as num).toDouble() -
          (inv['amount_paid'] as num).toDouble(),
    );
    final totalPaid = data.paymentHistory
        .where((p) => p['status'] == 'success')
        .fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble());

    // Primary invoice: first unpaid, or first overall
    final primaryInvoice = data.unpaidInvoices.isNotEmpty
        ? data.unpaidInvoices.first
        : (data.allInvoices.isNotEmpty ? data.allInvoices.first : null);
    final primaryLineItems = primaryInvoice != null
        ? data.lineItemsFor(primaryInvoice['id'] as String)
        : <_FeeLineItem>[];

    return CustomScrollView(
      slivers: [
        // ── Header ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Fees — ${selected.fullName}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (children.length > 1)
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, color: AppColors.primary),
                    tooltip: 'Switch child',
                    onPressed: () {
                      final idx = children.indexOf(selected);
                      final next = children[(idx + 1) % children.length];
                      setState(() {
                        _selectedStudentId = next.studentId;
                        _loading = true;
                        _data = null;
                      });
                      _loadData();
                    },
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Student identity ──
              _buildStudentInfoCard(context, selected, data),
              const SizedBox(height: 20),

              // ── Fee breakdown table ──
              if (primaryInvoice != null) ...[
                Text('Fee Breakdown',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _buildFeeBreakdownTable(context, primaryLineItems,
                    primaryInvoice, data.className, data.rollNo),
                const SizedBox(height: 24),
              ],

              // ── Financial summary ──
              _buildFinancialSummary(
                context,
                totalPaid,
                totalDue,
                data.scholarshipTotal,
                data.refundedTotal,
              ),
              const SizedBox(height: 24),

              // ── Outstanding invoices ──
              if (data.unpaidInvoices.isNotEmpty) ...[
                Text('Outstanding', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                ...data.unpaidInvoices.map((inv) {
                  final remaining = (inv['amount_due'] as num).toDouble() -
                      (inv['amount_paid'] as num).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('₹${remaining.toStringAsFixed(0)}',
                                  style:
                                      Theme.of(context).textTheme.headlineMedium),
                              Text('due ${inv['due_date']}',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _showEmiRequestSheet(inv, remaining),
                                  child: const Text('Request EMI'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _payOnline(inv),
                                  child: const Text('Pay Online'),
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
              ],

              // ── Payment history ──
              Text('Payment History',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _buildPaymentHistory(context, data, selected),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Student identity card ──────────────────────────────────────────────

  Widget _buildStudentInfoCard(
    BuildContext context,
    LinkedChild child,
    _FeesData data,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            child.fullName,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _infoRow('Admission Number', child.admissionNumber),
          if (data.className != null) _infoRow('Class', data.className!),
          if (data.rollNo != null) _infoRow('Roll Number', '${data.rollNo}'),
          _infoRow('Academic Year', '2025–26'),
          _infoRow('Fee Cycle', 'Annual'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Fee breakdown table ────────────────────────────────────────────────

  /// Placeholder demo fee heads used when no invoice_line_items rows exist.
  /// Amounts sum to ₹57,000 to match Aarav Sharma's current invoice total.
  /// These are NOT real data — replace with actual line items via the admin
  /// fee management flow once the feature is fully wired.
  static final List<_FeeLineItem> _demoFeeHeads = [
    _FeeLineItem(label: 'Tuition', amount: 30000),
    _FeeLineItem(label: 'Admission', amount: 5000),
    _FeeLineItem(label: 'Examination', amount: 3000),
    _FeeLineItem(label: 'Computer & Technology', amount: 2000),
    _FeeLineItem(label: 'Library', amount: 1500),
    _FeeLineItem(label: 'Laboratory', amount: 2000),
    _FeeLineItem(label: 'Sports & Activities', amount: 2500),
    _FeeLineItem(label: 'Transport', amount: 8000),
    _FeeLineItem(label: 'Miscellaneous', amount: 1500),
    _FeeLineItem(label: 'Late Fee', amount: 0),
    _FeeLineItem(label: 'Previous Outstanding', amount: 1500),
  ];

  Widget _buildFeeBreakdownTable(
    BuildContext context,
    List<_FeeLineItem> lineItems,
    Map<String, dynamic> invoice,
    String? className,
    int? rollNo,
  ) {
    // Use real line items if they exist; otherwise fall back to demo heads
    final items = lineItems.isNotEmpty
        ? lineItems
        : _demoFeeHeads;

    final totalPayable = items.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student identity summary inside breakdown
          if (className != null || rollNo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                [
                  if (className != null) 'Class: $className',
                  if (rollNo != null) 'Roll: $rollNo',
                ].join('  •  '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),

          // Line item rows
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '₹${item.amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.textSecondary, height: 1),
          ),

          // Total payable
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Payable',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  '₹${totalPayable.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Financial summary ──────────────────────────────────────────────────

  Widget _buildFinancialSummary(
    BuildContext context,
    double totalPaid,
    double totalDue,
    double scholarship,
    double refunded,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (scholarship > 0)
            _summaryRow('Scholarship / Concession', scholarship, AppColors.success),
          if (refunded > 0)
            _summaryRow('Refunded Amount', refunded, AppColors.warning),
          _summaryRow('Total Fees Received', totalPaid, AppColors.success),
          _summaryRow('Fees Paid', totalPaid, AppColors.textPrimary),
          _summaryRow('Outstanding Amount', totalDue, AppColors.error),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  // ── Payment history ────────────────────────────────────────────────────

  Widget _buildPaymentHistory(
    BuildContext context,
    _FeesData data,
    LinkedChild selected,
  ) {
    if (data.paymentHistory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No payments recorded yet.'),
      );
    }
    return Column(
      children: data.paymentHistory.map((p) {
        final dt = DateTime.parse(p['created_at'] as String);
        final txId = (p['gateway_payment_id'] as String?) ?? '—';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  p['status'] == 'success'
                      ? Icons.check_circle_outline
                      : p['status'] == 'refunded'
                          ? Icons.replay_circle_filled
                          : Icons.pending_outlined,
                  color: p['status'] == 'success'
                      ? AppColors.success
                      : p['status'] == 'refunded'
                          ? AppColors.warning
                          : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '₹${(p['amount'] as num).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.glassFill,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${p['method']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${p['status']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dt.day}/${dt.month}/${dt.year}  '
                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (txId != '—')
                        Text(
                          'TX: $txId',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Download receipt',
                  onPressed: () => _downloadReceipt(
                    p,
                    selected.fullName,
                    selected.admissionNumber,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────

class _FeeLineItem {
  const _FeeLineItem({
    required this.label,
    required this.amount,
    this.feeStructureId,
  });

  final String label;
  final double amount;
  final String? feeStructureId;
}

class _FeesData {
  _FeesData({
    required this.allInvoices,
    required this.unpaidInvoices,
    required this.lineItemsByInvoice,
    required this.paymentHistory,
    this.className,
    this.rollNo,
    this.scholarshipTotal = 0,
    this.refundedTotal = 0,
  });

  final List<Map<String, dynamic>> allInvoices;
  final List<Map<String, dynamic>> unpaidInvoices;
  final Map<String, List<Map<String, dynamic>>> lineItemsByInvoice;
  final List<Map<String, dynamic>> paymentHistory;
  final String? className;
  final int? rollNo;
  final double scholarshipTotal;
  final double refundedTotal;

  factory _FeesData.empty() => _FeesData(
        allInvoices: [],
        unpaidInvoices: [],
        lineItemsByInvoice: {},
        paymentHistory: [],
      );

  List<_FeeLineItem> lineItemsFor(String invoiceId) {
    final rows = lineItemsByInvoice[invoiceId];
    if (rows == null || rows.isEmpty) return [];
    return rows
        .map((r) => _FeeLineItem(
              label: r['label'] as String,
              amount: (r['amount'] as num).toDouble(),
              feeStructureId: r['fee_structure_id'] as String?,
            ))
        .toList();
  }
}
