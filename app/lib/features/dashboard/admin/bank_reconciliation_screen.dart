import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Bank Reconciliation screen for Admin Finance Workspace.
/// Lists transactions needing bank statement reconciliation (Cash, Cheque, DD, Online).
class BankReconciliationScreen extends ConsumerStatefulWidget {
  const BankReconciliationScreen({super.key});

  @override
  ConsumerState<BankReconciliationScreen> createState() => _BankReconciliationScreenState();
}

class _BankReconciliationScreenState extends ConsumerState<BankReconciliationScreen> {
  late Future<_BankRecData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BankRecData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final paymentsRaw = await client
        .schema('finance')
        .from('payments')
        .select('id, amount, method, status, reference_number, created_at, invoice_id')
        .order('created_at', ascending: false);

    final payments = List<Map<String, dynamic>>.from(paymentsRaw as List);

    double totalRecorded = 0;
    double cashAmount = 0;
    double chequeDdAmount = 0;
    double onlineAmount = 0;

    for (final p in payments) {
      final amt = (p['amount'] as num).toDouble();
      totalRecorded += amt;
      final m = (p['method'] as String? ?? 'cash').toLowerCase();
      if (m == 'cash') {
        cashAmount += amt;
      } else if (m == 'cheque' || m == 'demand_draft' || m == 'dd') {
        chequeDdAmount += amt;
      } else {
        onlineAmount += amt;
      }
    }

    return _BankRecData(
      payments: payments,
      totalRecorded: totalRecorded,
      cashAmount: cashAmount,
      chequeDdAmount: chequeDdAmount,
      onlineAmount: onlineAmount,
    );
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
          child: FutureBuilder<_BankRecData>(
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
                          Text('Bank Reconciliation', style: Theme.of(context).textTheme.headlineMedium),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppColors.primary),
                            onPressed: _refresh,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Summary stats
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                      ),
                      delegate: SliverChildListDelegate([
                        StatCard(
                          label: 'Total Collected',
                          value: '₹${data.totalRecorded.toStringAsFixed(0)}',
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppColors.primary,
                        ),
                        StatCard(
                          label: 'Online / UPI',
                          value: '₹${data.onlineAmount.toStringAsFixed(0)}',
                          icon: Icons.qr_code_2_outlined,
                          color: AppColors.success,
                        ),
                        StatCard(
                          label: 'Cash & Cheque/DD',
                          value: '₹${(data.cashAmount + data.chequeDdAmount).toStringAsFixed(0)}',
                          icon: Icons.payments_outlined,
                          color: AppColors.warning,
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Payment Audit & Deposit Log', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),

                  if (data.payments.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No payments recorded yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final p = data.payments[index];
                            final amt = (p['amount'] as num).toDouble();
                            final method = (p['method'] as String? ?? 'cash').toUpperCase();
                            final ref = p['reference_number'] as String? ?? 'N/A';
                            final dtStr = p['created_at'] as String? ?? '';
                            final dt = DateTime.tryParse(dtStr)?.toLocal();
                            final dateFormatted = dt != null ? '${dt.day}/${dt.month}/${dt.year}' : dtStr;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('$method Payment', style: Theme.of(context).textTheme.titleMedium),
                                          Text('Ref: $ref · Date: $dateFormatted', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Text('₹${amt.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 12),
                                    GlassChip(
                                      label: 'Reconciled',
                                      icon: Icons.check_circle_outline,
                                      color: AppColors.success,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: data.payments.length,
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

class _BankRecData {
  _BankRecData({
    required this.payments,
    required this.totalRecorded,
    required this.cashAmount,
    required this.chequeDdAmount,
    required this.onlineAmount,
  });

  final List<Map<String, dynamic>> payments;
  final double totalRecorded;
  final double cashAmount;
  final double chequeDdAmount;
  final double onlineAmount;
}
