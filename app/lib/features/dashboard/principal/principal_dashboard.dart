import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Principal front page (the shell sidebar's "Overview" item). Kept to genuinely
/// important-at-a-glance info only: the fee-collection ring, student/staff counts, and
/// timetable slot count. The ~14 operational quick links that used to live here as a
/// scrolling list have moved into the persistent sidebar (see nav_config.dart +
/// role_shell.dart) — this page no longer duplicates them.
class PrincipalDashboard extends ConsumerWidget {
  const PrincipalDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_PrincipalSummary>(
            future: _loadSummary(client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load dashboard: ${snapshot.error}'));
              }
              final s = snapshot.data!;
              final collectedRatio = s.amountDue == 0 ? 0.0 : (s.amountPaid / s.amountDue).clamp(0.0, 1.0);

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good morning', style: Theme.of(context).textTheme.bodyMedium),
                          Text('Principal Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        GlassCard(
                          child: Row(
                            children: [
                              ProgressRing(value: collectedRatio, centerLabel: '${(collectedRatio * 100).toStringAsFixed(0)}%', centerSubtitle: 'collected'),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.eco_outlined, color: AppColors.primary, size: 18),
                                        const SizedBox(width: 6),
                                        Text('Fee Collection', style: Theme.of(context).textTheme.titleMedium),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text('₹${s.amountPaid.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineMedium),
                                    Text('of ₹${s.amountDue.toStringAsFixed(0)} due', style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _StatGlassCard(icon: Icons.groups_outlined, label: 'Students', value: '${s.studentCount}')),
                            const SizedBox(width: 12),
                            Expanded(child: _StatGlassCard(icon: Icons.badge_outlined, label: 'Staff', value: '${s.staffCount}')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _StatGlassCard(icon: Icons.calendar_month_outlined, label: 'Timetable Slots', value: '${s.timetableCount}', subtitle: 'reviewed & live', wide: true),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Use the sidebar to reach finance, operations, and communication tools.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
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

  Future<_PrincipalSummary> _loadSummary(SupabaseClient client) async {
    final students = await client.schema('public').from('students').select('id');
    final staff = await client.schema('public').from('staff').select('id');
    final invoices = await client.schema('finance').from('invoices').select('amount_due, amount_paid');
    final timetable = await client.schema('scheduling').from('timetable').select('id');
    double due = 0, paid = 0;
    for (final row in invoices) {
      due += (row['amount_due'] as num).toDouble();
      paid += (row['amount_paid'] as num).toDouble();
    }
    return _PrincipalSummary(studentCount: students.length, staffCount: staff.length, amountDue: due, amountPaid: paid, timetableCount: timetable.length);
  }
}

class _PrincipalSummary {
  _PrincipalSummary({required this.studentCount, required this.staffCount, required this.amountDue, required this.amountPaid, required this.timetableCount});
  final int studentCount;
  final int staffCount;
  final double amountDue;
  final double amountPaid;
  final int timetableCount;
}

class _StatGlassCard extends StatelessWidget {
  const _StatGlassCard({required this.icon, required this.label, required this.value, this.subtitle, this.wide = false});
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: wide
          ? Row(children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  Text(value, style: Theme.of(context).textTheme.headlineMedium),
                ]),
              ),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(height: 10),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ]),
    );
  }
}
