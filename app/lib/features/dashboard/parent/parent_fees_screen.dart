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
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

class ParentFeesScreen extends ConsumerStatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  ConsumerState<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends ConsumerState<ParentFeesScreen> {
  String? _selectedStudentId;
  _FeesData? _data;
  bool _loading = false;
  String? _error;

  static const _parentAccent = Color(0xFFFF6B9D);

  String _searchQuery = '';
  SortOption? _sortOption;

  @override
  void initState() {
    super.initState();
    _sortOption = SortOptions.sortByDate;
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = ref.read(supabaseClientProvider);
    final childrenAsync = ref.read(selfChildrenProvider);
    final children = childrenAsync.valueOrNull ?? [];
    if (children.isEmpty) {
      if (!mounted) return;
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
      final data = await _load(client, selected.studentId);
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

  Future<_FeesData> _load(SupabaseClient client, String studentId) async {
    final invoicesRaw = await client
        .schema('finance')
        .from('invoices')
        .select('id, amount_due, amount_paid, due_date, invoice_number, fee_structure_id')
        .eq('student_id', studentId)
        .order('due_date');
    final allInvoices = List<Map<String, dynamic>>.from(invoicesRaw as List);
    final unpaidInvoices = allInvoices
        .where((i) => (i['amount_due'] as num) > (i['amount_paid'] as num))
        .toList();

    final invoiceIds = allInvoices.map((i) => i['id'] as String).toList();
    List<Map<String, dynamic>> payments = [];
    if (invoiceIds.isNotEmpty) {
      final payRows = await client
          .schema('finance')
          .from('payments')
          .select('id, invoice_id, amount, method, status, gateway_payment_id, created_at')
          .inFilter('invoice_id', invoiceIds)
          .order('created_at', ascending: false);
      payments = List<Map<String, dynamic>>.from(payRows);

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        payments = payments.where((p) {
          final method = (p['method'] as String?)?.toLowerCase() ?? '';
          final status = (p['status'] as String?)?.toLowerCase() ?? '';
          final txId = (p['gateway_payment_id'] as String?)?.toLowerCase() ?? '';
          return method.contains(query) || status.contains(query) || txId.contains(query);
        }).toList();
      }

      if (_sortOption != null) {
        payments = ListSorter.sortItems(payments, _sortOption!, true).toList();
      }
    }

    return _FeesData(
      allInvoices: allInvoices,
      unpaidInvoices: unpaidInvoices,
      paymentHistory: payments,
    );
  }

  void _onSearch(String value) {
    if (!mounted) return;
    setState(() {
      _searchQuery = value;
      _loadData();
    });
  }

  void _onSortChanged(SortOption? option) {
    if (!mounted) return;
    setState(() {
      _sortOption = option;
      _loadData();
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
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
              color: AppColors.glassFill,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Request Payment Plan', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('₹${remaining.toStringAsFixed(0)} remaining balance', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [3, 6, 12].map((n) {
                    final sel = installments == n;
                    return ChoiceChip(
                      label: Text('$n months (₹${(remaining / n).toStringAsFixed(0)}/mo)'),
                      selected: sel,
                      onSelected: (_) => setModalState(() => installments = n),
                      selectedColor: _parentAccent,
                      labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold),
                      backgroundColor: AppColors.backgroundAlt,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your request goes to the school accounts office for approval.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
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
                        const SnackBar(content: Text('EMI plan requested successfully.'), backgroundColor: AppColors.success),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
                    }
                  },
                  child: const Text('Submit Request'),
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
    final childrenAsync = ref.watch(selfChildrenProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _parentAccent)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (children) {
              if (children.isEmpty) {
                return const Center(child: Text('No children linked to your account yet.'));
              }
              final selected = children.firstWhere(
                (c) => c.studentId == _selectedStudentId,
                orElse: () => children.first,
              );

              if (!_loading && _data == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _loadData();
                });
              }

              return RefreshIndicator(
                onRefresh: _loadData,
                child: _loading && _data == null
                    ? const Center(child: CircularProgressIndicator(color: _parentAccent))
                    : _error != null && _data == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Failed to load: $_error'),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
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

  Widget _buildContent(BuildContext context, List<LinkedChild> children, LinkedChild selected) {
    final data = _data!;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text('Fees & Payments', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ),
        if (children.length > 1)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = children[i];
                    final isSelected = c.studentId == selected.studentId;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedStudentId = c.studentId;
                          _data = null;
                        });
                        _loadData();
                      },
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _parentAccent : AppColors.glassFill,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(
                            color: isSelected ? _parentAccent : AppColors.glassBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          c.fullName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text('Outstanding Invoices', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (data.unpaidInvoices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F9F5),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF00877D), size: 20),
                      SizedBox(width: 10),
                      Text('All fees are fully cleared! Nothing due right now.', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF00877D))),
                    ],
                  ),
                )
              else
                ...data.unpaidInvoices.map((inv) {
                  final remaining = (inv['amount_due'] as num).toDouble() - (inv['amount_paid'] as num).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('₹${remaining.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _parentAccent)),
                                  const SizedBox(height: 2),
                                  Text('Invoice #${inv['invoice_number'] ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                              GlassChip(label: 'Due: ${inv['due_date']}', color: const Color(0xFFFF6B47)),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                                child: ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Online payments are in Test Mode. You can also pay at the accounts counter.'),
                                        backgroundColor: _parentAccent,
                                      ),
                                    );
                                  },
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
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: SearchFilterBar(
              title: 'Payment History',
              hintText: 'Search by method, status, or TX ID...',
              onSearch: _onSearch,
              sorts: const [
                SortOptions.sortByDate,
                SortOptions.sortByAmount,
              ],
              currentSortValue: _sortOption?.value,
              onSortSelected: _onSortChanged,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (data.paymentHistory.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No payment history found matching your filters.', style: TextStyle(color: AppColors.textSecondary))),
                )
              else
                ...data.paymentHistory.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('₹${(p['amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(4)),
                                        child: Text('${p['method']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                      const SizedBox(width: 8),
                                      GlassChip(label: '${p['status']}', color: AppColors.success),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateTime.parse(p['created_at'] as String).day}/${DateTime.parse(p['created_at'] as String).month}/${DateTime.parse(p['created_at'] as String).year}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
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
  }
}

class _FeesData {
  final List<Map<String, dynamic>> allInvoices;
  final List<Map<String, dynamic>> unpaidInvoices;
  final List<Map<String, dynamic>> paymentHistory;

  _FeesData({
    required this.allInvoices,
    required this.unpaidInvoices,
    required this.paymentHistory,
  });

  factory _FeesData.empty() => _FeesData(
        allInvoices: [],
        unpaidInvoices: [],
        paymentHistory: [],
      );
}
