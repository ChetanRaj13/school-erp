import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Student Schedule — genuinely never existed before. Only Teacher had a schedule
/// view; a student had no way to see their own weekly timetable in the app at all.
/// Reads the same real scheduling.timetable data already used by Teacher/Principal
/// screens, filtered to whichever class this student belongs to (via
/// academic.class_roster).
class StudentScheduleScreen extends ConsumerWidget {
  const StudentScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_ScheduleData>(
            future: _load(ref, client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              if (data.className == null) {
                return const Center(child: Text("Your account isn't linked to a class yet."));
              }
              if (data.rows.isEmpty) {
                return Center(child: Text('No timetable set up yet for ${data.className}.'));
              }

              final days = ['mon', 'tue', 'wed', 'thu', 'fri'];
              final dayLabels = {'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu', 'fri': 'Fri'};
              final periods = data.rows.map((r) => r['period_number'] as int).toSet().toList()..sort();

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('My Schedule — ${data.className}', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        periods.map((period) {
                          final periodRows = data.rows.where((r) => r['period_number'] == period).toList();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Period $period', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 8),
                                  ...days.map((day) {
                                    final match = periodRows.where((r) => r['day'] == day).toList();
                                    if (match.isEmpty) return const SizedBox.shrink();
                                    final row = match.first;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 40, child: Text(dayLabels[day]!, style: const TextStyle(color: AppColors.textSecondary))),
                                          Expanded(child: Text('${row['subject_name']} · ${row['teacher_name']}')),
                                        ],
                                      ),
                                    );
                                  }),
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

  Future<_ScheduleData> _load(WidgetRef ref, SupabaseClient client) async {
    final selfStudentId = await ref.read(selfStudentIdProvider.future);
    if (selfStudentId == null) return _ScheduleData(className: null, rows: []);

    final roster = await client.schema('academic').from('class_roster').select('class_id').eq('student_id', selfStudentId).maybeSingle();
    if (roster == null) return _ScheduleData(className: null, rows: []);
    final classId = roster['class_id'] as String;

    final classRow = await client.schema('academic').from('classes').select('name').eq('id', classId).single();
    final className = classRow['name'] as String;

    final timetableRows = await client
        .schema('scheduling')
        .from('timetable')
        .select('slot_id, subject_id, teacher_id')
        .eq('class_id', classId);
    if ((timetableRows as List).isEmpty) return _ScheduleData(className: className, rows: []);

    final slotIds = timetableRows.map((r) => r['slot_id']).toSet().toList();
    final subjectIds = timetableRows.map((r) => r['subject_id']).toSet().toList();
    final teacherIds = timetableRows.map((r) => r['teacher_id']).toSet().toList();

    final slots = await client.schema('scheduling').from('time_slots').select('id, day, period_number').inFilter('id', slotIds);
    final subjects = await client.schema('academic').from('subjects').select('id, name').inFilter('id', subjectIds);
    final teachers = await client.schema('public').from('staff').select('id, full_name').inFilter('id', teacherIds);

    final slotById = {for (final s in slots as List) s['id']: s};
    final subjectNameById = {for (final s in subjects as List) s['id']: s['name']};
    final teacherNameById = {for (final t in teachers as List) t['id']: t['full_name']};

    final rows = timetableRows.map((r) {
      final slot = slotById[r['slot_id']] as Map<String, dynamic>?;
      return {
        'day': slot?['day'],
        'period_number': slot?['period_number'],
        'subject_name': subjectNameById[r['subject_id']] ?? 'Unknown',
        'teacher_name': teacherNameById[r['teacher_id']] ?? 'Unknown',
      };
    }).where((r) => r['day'] != null).toList();

    return _ScheduleData(className: className, rows: rows);
  }
}

class _ScheduleData {
  _ScheduleData({required this.className, required this.rows});
  final String? className;
  final List<Map<String, dynamic>> rows;
}
