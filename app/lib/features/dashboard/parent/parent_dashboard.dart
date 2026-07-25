import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Parent front page (the shell sidebar's "Overview" item). Kept to genuinely
/// important-at-a-glance info only: per-child fees + attendance, with a child selector
/// when more than one child is linked. The "Scholarships & Waivers" quick-access card
/// that used to live here has moved into the persistent sidebar (see nav_config.dart +
/// role_shell.dart). Data logic UNCHANGED (real parent_links-backed queries).
class ParentDashboard extends ConsumerStatefulWidget {
  const ParentDashboard({super.key});

  @override
  ConsumerState<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<ParentDashboard> {
  String? _selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(selfChildrenProvider);
    final client = ref.watch(supabaseClientProvider);
    final role = ref.watch(userRoleProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (children) {
              if (children.isEmpty) {
                return _NoChildrenLinkedView(role: role);
              }

              final selected = children.firstWhere((c) => c.studentId == _selectedStudentId, orElse: () => children.first);

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text('Parent Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  if (children.length > 1)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: children.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final c = children[i];
                              final isSelected = c.studentId == selected.studentId;
                              return ChoiceChip(
                                label: Text(c.fullName),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedStudentId = c.studentId),
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                                backgroundColor: AppColors.glassFill,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverFillRemaining(
                      fillOverscroll: true,
                      hasScrollBody: false,
                      child: FutureBuilder<_ChildSummary>(
                        future: _loadChildSummary(client, selected.studentId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                          }
                          if (snapshot.hasError) {
                            return Text('Failed to load: ${snapshot.error}');
                          }
                          final s = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${selected.fullName} · ${selected.admissionNumber}', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [const Icon(Icons.currency_rupee, color: AppColors.primary), const SizedBox(width: 8), Text('Fees', style: Theme.of(context).textTheme.titleMedium)]),
                                    const SizedBox(height: 12),
                                    Text('₹${s.amountDue.toStringAsFixed(0)} due', style: Theme.of(context).textTheme.headlineMedium),
                                    Text('₹${s.amountPaid.toStringAsFixed(0)} paid so far', style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [const Icon(Icons.event_available_outlined, color: AppColors.primary), const SizedBox(width: 8), Text('Attendance', style: Theme.of(context).textTheme.titleMedium)]),
                                    const SizedBox(height: 12),
                                    if (s.attendanceRecords.isEmpty)
                                      const Text('No attendance records yet.')
                                    else
                                      ...s.attendanceRecords.map((r) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(children: [
                                              Icon(r['status'] == 'present' ? Icons.check_circle_outline : Icons.cancel_outlined, size: 18, color: r['status'] == 'present' ? AppColors.success : AppColors.error),
                                              const SizedBox(width: 8),
                                              Text('${r['date']} — ${r['status']}'),
                                            ]),
                                          )),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Use the sidebar to reach scholarships & waivers.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          );
                        },
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

  Future<_ChildSummary> _loadChildSummary(SupabaseClient client, String studentId) async {
    final invoices = await client.schema('finance').from('invoices').select('amount_due, amount_paid').eq('student_id', studentId);
    double due = 0, paid = 0;
    for (final row in invoices as List) {
      due += (row['amount_due'] as num).toDouble();
      paid += (row['amount_paid'] as num).toDouble();
    }
    final attendance = await client.schema('attendance').from('records').select('date, status').eq('student_id', studentId).order('date', ascending: false).limit(10);
    return _ChildSummary(amountDue: due, amountPaid: paid, attendanceRecords: List<Map<String, dynamic>>.from(attendance as List));
  }
}

class _ChildSummary {
  _ChildSummary({required this.amountDue, required this.amountPaid, required this.attendanceRecords});
  final double amountDue;
  final double amountPaid;
  final List<Map<String, dynamic>> attendanceRecords;
}

class _NoChildrenLinkedView extends StatelessWidget {
  const _NoChildrenLinkedView({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Parent Dashboard', style: Theme.of(context).textTheme.headlineMedium),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.family_restroom_outlined, size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text("No children linked to your account yet.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Ask the school admin to link your account to your child\'s record.', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
