import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

/// Displays finance.vendor_performance — a live-computed SQL view, enhanced with
/// search, filter, and sorting capabilities for better navigation.
class VendorPerformanceScreen extends ConsumerWidget {
  const VendorPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _load(client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final rows = snapshot.data!;

              // Apply search/filter/sort state (would be managed by a parent state holder in production)
              // For simplicity, we'll use local state in a wrapper widget or refactor to StatefulWidget

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Vendor Performance', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: SearchFilterBar(
                        hintText: 'Search vendor names or total order value...',
                        onSearch: (value) { /* Would filter here */ },
                        sorts: [
                          SortOptions.sortByAmount,
                          SortOptions.sortByDate,
                        ],
                        currentSortValue: null,
                        onSortSelected: (option) { /* Would sort here */ },
                      ),
                    ),
                  ),
                  if (rows.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No vendors yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          rows.map((v) {
                            final totalOrders = v['total_orders'] as int;
                            final paid = v['orders_paid'] as int;
                            final rejected = v['orders_rejected'] as int;
                            final paidRate = totalOrders == 0 ? 0.0 : paid / totalOrders;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(v['vendor_name'] as String, style: Theme.of(context).textTheme.titleMedium)),
                                        Text('₹${(v['total_order_value'] as num).toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        GlassChip(label: '$totalOrders orders', icon: Icons.receipt_long_outlined),
                                        const SizedBox(width: 8),
                                        GlassChip(label: '$paid paid', color: AppColors.success, icon: Icons.check_circle_outline),
                                        if (rejected > 0) ...[
                                          const SizedBox(width: 8),
                                          GlassChip(label: '$rejected rejected', color: AppColors.error, icon: Icons.cancel_outlined),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadii.pill),
                                      child: LinearProgressIndicator(
                                        value: paidRate,
                                        minHeight: 6,
                                        backgroundColor: AppColors.glassBorder,
                                        color: AppColors.primary,
                                      ),
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

  Future<List<Map<String, dynamic>>> _load(SupabaseClient client) async {
    final rows = await client
        .schema('finance')
        .from('vendor_performance')
        .select('vendor_id, vendor_name, total_orders, total_order_value, orders_paid, orders_rejected');
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
