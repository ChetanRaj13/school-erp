import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

class ParentScheduleScreen extends ConsumerStatefulWidget {
  const ParentScheduleScreen({super.key});

  @override
  ConsumerState<ParentScheduleScreen> createState() => _ParentScheduleScreenState();
}

class _ParentScheduleScreenState extends ConsumerState<ParentScheduleScreen> {
  String? _selectedStudentId;
  static const _parentAccent = Color(0xFFFF6B9D);
  static const _parentAccentSoft = Color(0xFFFFE8F0);

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(selfChildrenProvider);
    final client = ref.watch(supabaseClientProvider);

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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text('Timetable & Schedule', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  if (children.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
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
                              onTap: () => setState(() => _selectedStudentId = c.studentId),
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
                  Expanded(
                    child: FutureBuilder<_ScheduleData>(
                      key: ValueKey('schedule-${selected.studentId}'),
                      future: _load(client, selected.studentId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator(color: _parentAccent));
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Failed to load: ${snapshot.error}'));
                        }
                        final data = snapshot.data!;
                        if (data.rows.isEmpty) {
                          return Center(child: Text('No timetable set up yet for ${selected.fullName}.'));
                        }

                        final days = ['mon', 'tue', 'wed', 'thu', 'fri'];
                        final dayLabels = {'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu', 'fri': 'Fri'};
                        final periods = data.rows.map((r) => r['period_number'] as int).toSet().toList()..sort();

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                          itemCount: periods.length,
                          itemBuilder: (context, i) {
                            final period = periods[i];
                            final periodRows = data.rows.where((r) => r['period_number'] == period).toList();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _parentAccentSoft,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Period $period',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: _parentAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...days.map((day) {
                                      final match = periodRows.where((r) => r['day'] == day).toList();
                                      if (match.isEmpty) return const SizedBox.shrink();
                                      final row = match.first;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.backgroundAlt,
                                            borderRadius: BorderRadius.circular(AppRadii.input),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                padding: const EdgeInsets.symmetric(vertical: 2),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  dayLabels[day]!,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  row['subject_name'] as String,
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                ),
                                              ),
                                              Text(
                                                row['teacher_name'] as String,
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
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

  Future<_ScheduleData> _load(SupabaseClient client, String studentId) async {
    final roster = await client.schema('academic').from('class_roster').select('class_id').eq('student_id', studentId).maybeSingle();
    if (roster == null) return _ScheduleData(rows: []);
    final classId = roster['class_id'] as String;

    final timetableRows = await client.schema('scheduling').from('timetable').select('slot_id, subject_id, teacher_id').eq('class_id', classId);
    if ((timetableRows as List).isEmpty) return _ScheduleData(rows: []);

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

    return _ScheduleData(rows: rows);
  }
}

class _ScheduleData {
  _ScheduleData({required this.rows});
  final List<Map<String, dynamic>> rows;
}
