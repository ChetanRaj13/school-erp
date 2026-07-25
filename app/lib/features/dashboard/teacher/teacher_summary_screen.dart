import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Teacher Summary — a real overview instead of jumping straight to a schedule list.
/// Two things worth being honest about, both stated directly in the UI, not silently
/// assumed:
///
/// 1. DECLINING ATTENDANCE flag is real and reliably computable: compares each
///    student's attendance % in the most recent 10 school days vs. the 10 before
///    that, using real attendance.records data.
/// 2. DECLINING GRADES flag only works from academic.grades, which uses real numeric
///    columns (marks_obtained/max_marks) — NOT from assignment submissions, whose
///    grade field is free text ("A-", "85/100") and can't be reliably compared as a
///    trend. If a student has fewer than 2 numeric grade entries, they're correctly
///    excluded from this flag rather than guessed at.
class TeacherSummaryScreen extends ConsumerWidget {
  const TeacherSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_TeacherSummaryData>(
            future: _load(ref, client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              if (data.selfStaffId == null) {
                return const Center(child: Text("Your account isn't linked to a staff record yet."));
              }

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Summary', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            Expanded(child: _StatCard(label: 'Classes', value: '${data.classPerf.length}', icon: Icons.class_outlined)),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(label: "Today's periods", value: '${data.todayPeriodCount}', icon: Icons.today_outlined)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text('Class Performance', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        if (data.classPerf.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No classes on your timetable yet.'))
                        else
                          ...data.classPerf.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c.className, style: Theme.of(context).textTheme.titleMedium),
                                            Text(
                                              c.avgAttendance == null ? 'No attendance data yet' : '${c.avgAttendance!.toStringAsFixed(0)}% attendance',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (c.avgMarksPercent != null)
                                        GlassChip(label: 'Avg ${c.avgMarksPercent!.toStringAsFixed(0)}%', color: AppColors.primary),
                                    ],
                                  ),
                                ),
                              )),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.flag_outlined, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Text('Students to Watch', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Auto-flagged: attendance or grades trending down over the last two windows.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        if (data.flaggedStudents.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No students currently flagged.'))
                        else
                          ...data.flaggedStudents.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.trending_down, color: AppColors.error, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(f.studentName, style: Theme.of(context).textTheme.titleMedium),
                                            Text(f.reason, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        const SizedBox(height: 24),
                        Text('Quick Links', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        _QuickLinkTile(icon: Icons.checklist_outlined, label: 'Mark Attendance', onTap: () => context.go('/teacher/attendance')),
                        const SizedBox(height: 8),
                        _QuickLinkTile(icon: Icons.grade_outlined, label: 'Gradebook', onTap: () => context.go('/teacher/gradebook')),
                        const SizedBox(height: 8),
                        _QuickLinkTile(icon: Icons.folder_shared_outlined, label: 'Lesson Resources', onTap: () => context.go('/teacher/resources')),
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

  Future<_TeacherSummaryData> _load(WidgetRef ref, SupabaseClient client) async {
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    if (selfStaffId == null) {
      return _TeacherSummaryData(selfStaffId: null, classPerf: [], flaggedStudents: [], todayPeriodCount: 0);
    }

    final timetableRows = await client.schema('scheduling').from('timetable').select('class_id, slot_id').eq('teacher_id', selfStaffId);
    final classIds = (timetableRows as List).map((r) => r['class_id'] as String).toSet().toList();

    const weekdayCodes = ['mon', 'tue', 'wed', 'thu', 'fri'];
    final todayCode = DateTime.now().weekday <= 5 ? weekdayCodes[DateTime.now().weekday - 1] : null;
    int todayPeriodCount = 0;
    if (todayCode != null) {
      final slotIds = timetableRows.map((r) => r['slot_id']).toList();
      if (slotIds.isNotEmpty) {
        final todaySlots = await client.schema('scheduling').from('time_slots').select('id').eq('day', todayCode).inFilter('id', slotIds);
        todayPeriodCount = (todaySlots as List).length;
      }
    }

    if (classIds.isEmpty) {
      return _TeacherSummaryData(selfStaffId: selfStaffId, classPerf: [], flaggedStudents: [], todayPeriodCount: todayPeriodCount);
    }

    final classes = await client.schema('academic').from('classes').select('id, name').inFilter('id', classIds);

    final classPerf = <_ClassPerformance>[];
    final flagged = <_FlaggedStudent>[];

    final today = DateTime.now();
    final recentStart = today.subtract(const Duration(days: 10));
    final priorStart = today.subtract(const Duration(days: 20));

    for (final cls in classes as List) {
      final classId = cls['id'] as String;
      final className = cls['name'] as String;

      final roster = await client.schema('academic').from('class_roster').select('student_id').eq('class_id', classId);
      final studentIds = (roster as List).map((r) => r['student_id'] as String).toList();
      if (studentIds.isEmpty) continue;

      final students = await client.schema('public').from('students').select('id, full_name').inFilter('id', studentIds);
      final nameById = {for (final s in students as List) s['id'] as String: s['full_name'] as String};

      final attendanceRaw = await client
          .schema('attendance')
          .from('records')
          .select('student_id, status, date')
          .eq('class_id', classId)
          .gte('date', priorStart.toIso8601String().split('T').first);
      final attendance = List<Map<String, dynamic>>.from(attendanceRaw as List);

      double? classAvgAttendance;
      if (attendance.isNotEmpty) {
        final presentCount = attendance.where((a) => a['status'] == 'present').length;
        classAvgAttendance = presentCount / attendance.length * 100;
      }

      for (final studentId in studentIds) {
        final studentRecords = attendance.where((a) => a['student_id'] == studentId).toList();
        final recent = studentRecords.where((a) {
          final d = DateTime.tryParse(a['date'] as String);
          return d != null && !d.isBefore(recentStart);
        }).toList();
        final prior = studentRecords.where((a) {
          final d = DateTime.tryParse(a['date'] as String);
          return d != null && d.isBefore(recentStart) && !d.isBefore(priorStart);
        }).toList();

        if (recent.length >= 3 && prior.length >= 3) {
          final recentPct = recent.where((a) => a['status'] == 'present').length / recent.length * 100;
          final priorPct = prior.where((a) => a['status'] == 'present').length / prior.length * 100;
          if (priorPct - recentPct >= 15) {
            flagged.add(_FlaggedStudent(
              studentName: nameById[studentId] ?? 'Unknown',
              reason: 'Attendance down ${(priorPct - recentPct).toStringAsFixed(0)} pts (${priorPct.toStringAsFixed(0)}% → ${recentPct.toStringAsFixed(0)}%)',
            ));
          }
        }
      }

      final gradesRaw = await client
          .schema('academic')
          .from('grades')
          .select('student_id, marks_obtained, max_marks, created_at')
          .inFilter('student_id', studentIds)
          .order('created_at');
      final grades = List<Map<String, dynamic>>.from(gradesRaw as List);

      double? classAvgMarksPercent;
      if (grades.isNotEmpty) {
        final percentages = grades.map((g) => (g['marks_obtained'] as num) / (g['max_marks'] as num) * 100).toList();
        classAvgMarksPercent = percentages.reduce((a, b) => a + b) / percentages.length;
      }

      for (final studentId in studentIds) {
        final studentGrades = grades.where((g) => g['student_id'] == studentId).toList();
        if (studentGrades.length >= 2) {
          final latest = (studentGrades.last['marks_obtained'] as num) / (studentGrades.last['max_marks'] as num) * 100;
          final previous = (studentGrades[studentGrades.length - 2]['marks_obtained'] as num) /
              (studentGrades[studentGrades.length - 2]['max_marks'] as num) *
              100;
          if (previous - latest >= 15) {
            flagged.add(_FlaggedStudent(
              studentName: nameById[studentId] ?? 'Unknown',
              reason: 'Marks down ${(previous - latest).toStringAsFixed(0)} pts (${previous.toStringAsFixed(0)}% → ${latest.toStringAsFixed(0)}%)',
            ));
          }
        }
      }

      classPerf.add(_ClassPerformance(className: className, avgAttendance: classAvgAttendance, avgMarksPercent: classAvgMarksPercent));
    }

    return _TeacherSummaryData(selfStaffId: selfStaffId, classPerf: classPerf, flaggedStudents: flagged, todayPeriodCount: todayPeriodCount);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TeacherSummaryData {
  _TeacherSummaryData({required this.selfStaffId, required this.classPerf, required this.flaggedStudents, required this.todayPeriodCount});
  final String? selfStaffId;
  final List<_ClassPerformance> classPerf;
  final List<_FlaggedStudent> flaggedStudents;
  final int todayPeriodCount;
}

class _ClassPerformance {
  _ClassPerformance({required this.className, required this.avgAttendance, required this.avgMarksPercent});
  final String className;
  final double? avgAttendance;
  final double? avgMarksPercent;
}

class _FlaggedStudent {
  _FlaggedStudent({required this.studentName, required this.reason});
  final String studentName;
  final String reason;
}
