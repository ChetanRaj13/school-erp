import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/account_not_linked_view.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Teacher front page (the shell sidebar's "My Schedule" item). Kept to genuinely
/// important-at-a-glance info only: today's teaching schedule. The Leave / Assignments /
/// Announcements / Messages cards that used to live here have moved into the persistent
/// sidebar (see nav_config.dart + role_shell.dart). Schedule query logic UNCHANGED and
/// already validated against real data. Account-not-linked guard preserved.
class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selfStaffId = ref.watch(selfStaffIdProvider);
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: selfStaffId.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (staffId) {
              if (staffId == null) {
                return const AccountNotLinkedView(
                    message: "Your account isn't linked to a staff record yet.");
              }
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text('Teacher Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _loadTodaySchedule(client, staffId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                          }
                          if (snapshot.hasError) {
                            return Text('Failed to load schedule: ${snapshot.error}');
                          }
                          final rows = snapshot.data!;
                          final todayCode = _todayWeekdayCode();

                          if (todayCode == null) {
                            return GlassCard(
                              child: Row(
                                children: [
                                  const Icon(Icons.weekend_outlined, color: AppColors.primary, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text('No school today — enjoy the weekend!', style: Theme.of(context).textTheme.titleMedium)),
                                ],
                              ),
                            );
                          }
                          if (rows.isEmpty) {
                            return GlassCard(
                              child: Row(
                                children: [
                                  const Icon(Icons.free_cancellation_outlined, color: AppColors.primary, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text('No periods scheduled for you today.', style: Theme.of(context).textTheme.titleMedium)),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Today', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              ...rows.map((r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: GlassCard(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppColors.primaryLight,
                                            child: Text('${r['period_number']}',
                                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(r['subject_name'] as String? ?? 'Unknown subject',
                                                    style: Theme.of(context).textTheme.titleMedium),
                                                Text('${r['class_name'] ?? 'Unknown class'} · ${r['start_time']}–${r['end_time']}',
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
                                'Use the sidebar for leave, assignments, announcements, and messages.',
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

  Future<List<Map<String, dynamic>>> _loadTodaySchedule(SupabaseClient client, String staffId) async {
    final todayCode = _todayWeekdayCode();
    if (todayCode == null) return [];

    final slots = await client.schema('scheduling').from('time_slots').select('id, period_number, start_time, end_time').eq('day', todayCode).order('period_number');
    final slotById = {for (final s in slots as List) s['id']: s};
    final slotIds = slotById.keys.toList();
    if (slotIds.isEmpty) return [];

    final timetableRows = await client.schema('scheduling').from('timetable').select('slot_id, subject_id, class_id').eq('teacher_id', staffId).inFilter('slot_id', slotIds);
    if ((timetableRows as List).isEmpty) return [];

    final subjectIds = timetableRows.map((r) => r['subject_id']).toSet().toList();
    final classIds = timetableRows.map((r) => r['class_id']).toSet().toList();

    final subjects = await client.schema('academic').from('subjects').select('id, name').inFilter('id', subjectIds);
    final classes = await client
        .schema('academic')
        .from('classes')
        .select('id, name')
        .inFilter('id', classIds)
        .eq('is_archived', false);
    final subjectNameById = {for (final s in subjects as List) s['id']: s['name']};
    final classNameById = {for (final c in classes as List) c['id']: c['name']};

    final result = timetableRows.map((r) {
      final slot = slotById[r['slot_id']] as Map<String, dynamic>;
      return {
        'period_number': slot['period_number'],
        'start_time': slot['start_time'],
        'end_time': slot['end_time'],
        'subject_name': subjectNameById[r['subject_id']],
        'class_name': classNameById[r['class_id']],
      };
    }).toList();

    result.sort((a, b) => (a['period_number'] as int).compareTo(b['period_number'] as int));
    return result;
  }

  String? _todayWeekdayCode() {
    const codes = ['mon', 'tue', 'wed', 'thu', 'fri', null, null];
    return codes[DateTime.now().weekday - 1];
  }
}
