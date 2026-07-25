import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Grades & Progress — combines two real, distinct things per subject:
/// 1. Term marks from academic.grades (real numeric data, entered via the new
///    Gradebook screen)
/// 2. Assignment completion rate — submitted assignments / total assigned, per
///    subject, from real academic.assignments + academic.submissions data
///
/// If a subject has no grades entered yet, that's shown honestly ("Not graded yet"),
/// not hidden or defaulted to 0%.
class StudentProgressScreen extends ConsumerWidget {
  const StudentProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<List<_SubjectProgress>>(
            future: _load(ref, client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final subjects = snapshot.data!;
              if (subjects.isEmpty) {
                return const Center(child: Text("Your account isn't linked to a class yet."));
              }

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Grades & Progress', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        subjects.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Row(
                                  children: [
                                    ProgressRing(
                                      value: s.completionRate,
                                      centerLabel: '${(s.completionRate * 100).toStringAsFixed(0)}%',
                                      centerSubtitle: 'done',
                                      size: 76,
                                      strokeWidth: 7,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.subjectName, style: Theme.of(context).textTheme.titleMedium),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${s.submittedCount}/${s.totalAssignments} assignments submitted',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                          const SizedBox(height: 6),
                                          if (s.avgMarksPercent != null)
                                            GlassChip(label: 'Avg mark: ${s.avgMarksPercent!.toStringAsFixed(0)}%', color: AppColors.primary)
                                          else
                                            const Text('Not graded yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ))
                            .toList(),
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

  Future<List<_SubjectProgress>> _load(WidgetRef ref, SupabaseClient client) async {
    final selfStudentId = await ref.read(selfStudentIdProvider.future);
    if (selfStudentId == null) return [];

    final roster = await client.schema('academic').from('class_roster').select('class_id').eq('student_id', selfStudentId).maybeSingle();
    if (roster == null) return [];
    final classId = roster['class_id'] as String;

    final assignments = await client.schema('academic').from('assignments').select('id, subject_id').eq('class_id', classId);
    final subjectIds = (assignments as List).map((a) => a['subject_id'] as String).toSet().toList();
    if (subjectIds.isEmpty) return [];

    final subjects = await client.schema('academic').from('subjects').select('id, name').inFilter('id', subjectIds);

    final submissions = await client
        .schema('academic')
        .from('submissions')
        .select('assignment_id')
        .eq('student_id', selfStudentId);
    final submittedAssignmentIds = (submissions as List).map((s) => s['assignment_id'] as String).toSet();

    final grades = await client
        .schema('academic')
        .from('grades')
        .select('subject_id, marks_obtained, max_marks')
        .eq('student_id', selfStudentId)
        .inFilter('subject_id', subjectIds);

    return (subjects as List).map((subj) {
      final subjectId = subj['id'] as String;
      final subjectAssignments = assignments.where((a) => a['subject_id'] == subjectId).toList();
      final submittedCount = subjectAssignments.where((a) => submittedAssignmentIds.contains(a['id'])).length;

      final subjectGrades = (grades as List).where((g) => g['subject_id'] == subjectId).toList();
      double? avgMarksPercent;
      if (subjectGrades.isNotEmpty) {
        final percentages = subjectGrades.map((g) => (g['marks_obtained'] as num) / (g['max_marks'] as num) * 100).toList();
        avgMarksPercent = percentages.reduce((a, b) => a + b) / percentages.length;
      }

      return _SubjectProgress(
        subjectName: subj['name'] as String,
        totalAssignments: subjectAssignments.length,
        submittedCount: submittedCount,
        completionRate: subjectAssignments.isEmpty ? 0.0 : submittedCount / subjectAssignments.length,
        avgMarksPercent: avgMarksPercent,
      );
    }).toList();
  }
}

class _SubjectProgress {
  _SubjectProgress({
    required this.subjectName,
    required this.totalAssignments,
    required this.submittedCount,
    required this.completionRate,
    required this.avgMarksPercent,
  });
  final String subjectName;
  final int totalAssignments;
  final int submittedCount;
  final double completionRate;
  final double? avgMarksPercent;
}
