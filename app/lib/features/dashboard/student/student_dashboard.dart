import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/account_not_linked_view.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Student front page (the shell sidebar's "Overview" item). Kept to genuinely
/// important-at-a-glance info only: fees due + attendance summary + recent attendance
/// records. The Assignments / Announcements / Messages cards that used to live here
/// have moved into the persistent sidebar (see nav_config.dart + role_shell.dart).
/// Data logic UNCHANGED. Account-not-linked guard preserved.
class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selfStudentId = ref.watch(selfStudentIdProvider);
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: selfStudentId.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (studentId) {
              if (studentId == null) {
                return const AccountNotLinkedView(
                    message: "Your account isn't linked to a student record yet.");
              }
              return FutureBuilder<_StudentSummary>(
                future: _loadSummary(client, studentId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Failed to load: ${snapshot.error}'));
                  }
                  final summary = snapshot.data!;
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Text('Student Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Row(
                              children: [
                                Expanded(
                                  child: StatCard(
                                    label: 'Fees Due',
                                    value: '₹${summary.amountDue.toStringAsFixed(0)}',
                                    subtitle: '₹${summary.amountPaid.toStringAsFixed(0)} paid',
                                    icon: Icons.currency_rupee,
                                    color: summary.amountDue > 0 ? Colors.orange : Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: StatCard(
                                    label: 'Attendance',
                                    value: summary.attendanceRecords.isEmpty
                                        ? '—'
                                        : '${summary.presentCount}/${summary.attendanceRecords.length}',
                                    subtitle: summary.attendanceRecords.isEmpty
                                        ? 'No records yet'
                                        : 'days present (recent)',
                                    icon: Icons.event_available_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text('Recent Attendance', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            if (summary.attendanceRecords.isEmpty)
                              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No attendance records yet.'))
                            else
                              ...summary.attendanceRecords.map((r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: GlassCard(
                                      child: Row(
                                        children: [
                                          Icon(
                                            r['status'] == 'present'
                                                ? Icons.check_circle_outline
                                                : Icons.cancel_outlined,
                                            color: r['status'] == 'present' ? AppColors.success : AppColors.error,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(r['date'] as String, style: Theme.of(context).textTheme.titleMedium),
                                                Text((r['status'] as String).replaceAll('_', ' '),
                                                    style: Theme.of(context).textTheme.bodyMedium),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                            const SizedBox(height: 8),
                            Text(
                              'Use the sidebar for assignments, announcements, and messages.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
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

  Future<_StudentSummary> _loadSummary(SupabaseClient client, String studentId) async {
    final invoices = await client.schema('finance').from('invoices').select('amount_due, amount_paid').eq('student_id', studentId);
    double due = 0, paid = 0;
    for (final row in invoices as List) {
      due += (row['amount_due'] as num).toDouble();
      paid += (row['amount_paid'] as num).toDouble();
    }
    final attendance = await client.schema('attendance').from('records').select('date, status').eq('student_id', studentId).order('date', ascending: false).limit(10);
    final records = List<Map<String, dynamic>>.from(attendance as List);
    final presentCount = records.where((r) => r['status'] == 'present').length;
    return _StudentSummary(amountDue: due, amountPaid: paid, attendanceRecords: records, presentCount: presentCount);
  }
}

class _StudentSummary {
  _StudentSummary({required this.amountDue, required this.amountPaid, required this.attendanceRecords, required this.presentCount});
  final double amountDue;
  final double amountPaid;
  final List<Map<String, dynamic>> attendanceRecords;
  final int presentCount;
}
