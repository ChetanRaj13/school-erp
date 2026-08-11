import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';

/// Recent Payments screen for Admin Finance Workspace — real data from finance.payments.
class RecentPaymentsScreen extends ConsumerStatefulWidget {
  const RecentPaymentsScreen({super.key});

  @override
  ConsumerState<RecentPaymentsScreen> createState() => _RecentPaymentsScreenState();
}

class _RecentPaymentsScreenState extends ConsumerState<RecentPaymentsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String _searchQuery = '';
  String _filterMethod = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = ref.read(supabaseClientProvider);
    final paymentsRaw = await client
        .schema('finance')
        .from('payments')
        .select('id, invoice_id, amount, method, status, created_at, reference_number')
        .order('created_at', ascending: false)
        .limit(100);

    final paymentsList = List<Map<String, dynamic>>.from(paymentsRaw as List);
    if (paymentsList.isEmpty) return [];

    final invoiceIds = paymentsList
        .map((p) => p['invoice_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (invoiceIds.isEmpty) return paymentsList;

    final invoicesRaw = await client
        .schema('finance')
        .from('invoices')
        .select('id, student_id, invoice_number')
        .inFilter('id', invoiceIds);

    final invoiceMap = {
      for (final inv in invoicesRaw as List) inv['id'] as String: inv
    };

    final studentIds = invoiceMap.values
        .map((inv) => inv['student_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final studentsRaw = studentIds.isEmpty
        ? []
        : await client
            .schema('public')
            .from('students')
            .select('id, full_name, admission_number')
            .inFilter('id', studentIds);

    final studentMap = {
      for (final s in studentsRaw as List) s['id'] as String: s
    };

    for (final p in paymentsList) {
      final invId = p['invoice_id'] as String?;
      final inv = invId != null ? invoiceMap[invId] : null;
      final stId = inv != null ? inv['student_id'] as String? : null;
      final st = stId != null ? studentMap[stId] : null;

      p['invoice_number'] = inv?['invoice_number'] ?? '—';
      p['student_name'] = st?['full_name'] ?? 'Unknown';
      p['admission_number'] = st?['admission_number'] ?? '—';
    }

    return paymentsList;
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
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
              final payments = snapshot.data ?? [];

              var filtered = payments;
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                filtered = filtered.where((p) {
                  final name = (p['student_name'] as String).toLowerCase();
                  final ref = (p['reference_number'] as String? ?? '').toLowerCase();
                  final invNum = (p['invoice_number'] as String).toLowerCase();
                  return name.contains(q) || ref.contains(q) || invNum.contains(q);
                }).toList();
              }

              if (_filterMethod != 'all') {
                filtered = filtered.where((p) => p['method'] == _filterMethod).toList();
              }

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Payments', style: Theme.of(context).textTheme.headlineMedium),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppColors.primary),
                            onPressed: _refresh,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: SearchFilterBar(
                        title: 'Payments',
                        hintText: 'Search by student, reference, or invoice #...',
                        onSearch: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No payment records found.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final p = filtered[index];
                            final amount = (p['amount'] as num).toDouble();
                            final method = (p['method'] as String? ?? 'cash').toUpperCase();
                            final status = p['status'] as String? ?? 'completed';
                            final dateStr = p['created_at'] as String? ?? '';
                            final dt = DateTime.tryParse(dateStr)?.toLocal();
                            final formattedDate = dt != null
                                ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                                : dateStr;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.payments_outlined, color: AppColors.success),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['student_name'] as String,
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Inv: ${p['invoice_number']} · Ref: ${p['reference_number'] ?? 'N/A'}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            formattedDate,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${amount.toStringAsFixed(0)}',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        GlassChip(
                                          label: '$method · $status',
                                          color: status == 'completed' || status == 'success' ? AppColors.success : AppColors.warning,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: filtered.length,
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
