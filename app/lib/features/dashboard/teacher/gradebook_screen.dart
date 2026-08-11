import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/line_chart.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Gradebook — a DIFFERENT concept from assignment grading (already built in
/// TeacherAssignmentsScreen, which grades individual submissions with free-text
/// grades like "A-" or "85/100"). This is term/exam marks entry against
/// academic.grades, which uses real NUMERIC columns (marks_obtained, max_marks) —
/// genuinely more reliable for any future trend/analytics use than free-text grades.
/// academic.grades was completely unused before this (0 rows).
class GradebookScreen extends ConsumerStatefulWidget {
  const GradebookScreen({super.key});

  @override
  ConsumerState<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends ConsumerState<GradebookScreen> {
  late Future<_GradebookData> _future;
  String? _selectedClassId;
  String? _selectedSubjectId;
  final _termController = TextEditingController(text: 'Term 1');

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _termController.dispose();
    super.dispose();
  }

  Future<_GradebookData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    if (selfStaffId == null) return _GradebookData(selfStaffId: null, classes: [], subjects: []);

    final timetableRows = await client.schema('scheduling').from('timetable').select('class_id, subject_id').eq('teacher_id', selfStaffId);
    final classIds = (timetableRows as List).map((r) => r['class_id'] as String).toSet().toList();
    final subjectIds = timetableRows.map((r) => r['subject_id'] as String).toSet().toList();
    if (classIds.isEmpty) return _GradebookData(selfStaffId: selfStaffId, classes: [], subjects: []);

    final classes = await client
        .schema('academic')
        .from('classes')
        .select('id, name')
        .inFilter('id', classIds)
        .eq('is_archived', false)
        .order('name');
    final subjectsRaw = subjectIds.isEmpty
        ? []
        : await client.schema('academic').from('subjects').select('id, name').inFilter('id', subjectIds);

    // Deduplicate subjects by name — the subjects table has one row per
    // (subject, qualified-teacher) pair, so the same subject name appears
    // multiple times. Keep only the first row per name for the dropdown.
    final seenNames = <String>{};
    final subjects = subjectsRaw.where((s) => seenNames.add(s['name'] as String)).toList();
    final classList = List<Map<String, dynamic>>.from(classes as List);

    // Rank classes by historical attendance/grade count so default selection has the most data (7-A/6-A)
    try {
      final counts = <String, int>{};
      await Future.wait(classIds.map((cid) async {
        final res = await client
            .schema('attendance')
            .from('records')
            .select('id')
            .eq('class_id', cid)
            .count(CountOption.exact);
        counts[cid] = res.count;
      }));
      classList.sort((a, b) {
        final countA = counts[a['id']] ?? 0;
        final countB = counts[b['id']] ?? 0;
        if (countB != countA) return countB.compareTo(countA);
        return (a['name'] as String).compareTo(b['name'] as String);
      });
    } catch (_) {}

    return _GradebookData(
      selfStaffId: selfStaffId,
      classes: classList,
      subjects: List<Map<String, dynamic>>.from(subjects),
    );
  }

  Future<List<Map<String, dynamic>>> _loadRosterWithGrades(String classId, String subjectId, String term) async {
    final client = ref.read(supabaseClientProvider);
    final roster = await client.schema('academic').from('class_roster').select('student_id, roll_no').eq('class_id', classId).order('roll_no');
    final studentIds = (roster as List).map((r) => r['student_id'] as String).toList();
    final students = studentIds.isEmpty
        ? []
        : await client.schema('public').from('students').select('id, full_name').inFilter('id', studentIds);
    final nameById = {for (final s in students) s['id'] as String: s['full_name'] as String};

    final existingGrades = studentIds.isEmpty
        ? []
        : await client
            .schema('academic')
            .from('grades')
            .select('id, student_id, marks_obtained, max_marks')
            .eq('subject_id', subjectId)
            .eq('term', term)
            .inFilter('student_id', studentIds);
    final gradeByStudentId = {for (final g in existingGrades) g['student_id'] as String: g};

    return roster.map((r) => {
          'student_id': r['student_id'],
          'roll_no': r['roll_no'],
          'full_name': nameById[r['student_id']] ?? 'Unknown',
          'existing_grade': gradeByStudentId[r['student_id']],
        }).toList();
  }

  Future<void> _saveMark(String studentId, String subjectId, String term, double marksObtained, double maxMarks, Map<String, dynamic>? existing) async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    try {
      if (existing != null) {
        await client.schema('academic').from('grades').update({
          'marks_obtained': marksObtained,
          'max_marks': maxMarks,
        }).eq('id', existing['id']);
      } else {
        await client.schema('academic').from('grades').insert({
          'student_id': studentId,
          'subject_id': subjectId,
          'term': term,
          'marks_obtained': marksObtained,
          'max_marks': maxMarks,
          'entered_by': selfStaffId,
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mark saved.'), backgroundColor: AppColors.success),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showMarkEntryDialog(Map<String, dynamic> row, String subjectId, String term) {
    final existing = row['existing_grade'] as Map<String, dynamic>?;
    final marksController = TextEditingController(text: existing != null ? (existing['marks_obtained'] as num).toString() : '');
    final maxMarksController = TextEditingController(text: existing != null ? (existing['max_marks'] as num).toString() : '100');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(row['full_name'] as String),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: marksController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Marks obtained')),
            TextField(controller: maxMarksController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Out of')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final marks = double.tryParse(marksController.text);
              final maxMarks = double.tryParse(maxMarksController.text);
              if (marks == null || maxMarks == null) return;
              Navigator.of(context).pop();
              _saveMark(row['student_id'] as String, subjectId, term, marks, maxMarks, existing);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadGradeTrend(String classId) async {
    final client = ref.read(supabaseClientProvider);
    try {
      final res = await client.schema('analytics').rpc('get_grade_trend', params: {'p_class_id': classId});
      final list = List<Map<String, dynamic>>.from(res as List);
      if (list.length >= 2) return list;
    } catch (_) {
      try {
        final res = await client.rpc('get_grade_trend', params: {'p_class_id': classId});
        final list = List<Map<String, dynamic>>.from(res as List);
        if (list.length >= 2) return list;
      } catch (_) {}
    }

    // Try computing directly from academic.grades for students in this class
    try {
      final roster = await client.schema('academic').from('class_roster').select('student_id').eq('class_id', classId);
      final studentIds = (roster as List).map((r) => r['student_id'] as String).toList();
      if (studentIds.isNotEmpty) {
        final gradesRaw = await client
            .schema('academic')
            .from('grades')
            .select('term, marks_obtained, max_marks')
            .inFilter('student_id', studentIds);
        final grades = List<Map<String, dynamic>>.from(gradesRaw as List);
        if (grades.isNotEmpty) {
          final byTerm = <String, List<double>>{};
          for (final g in grades) {
            final termStr = g['term'] as String? ?? 'General';
            final marks = (g['marks_obtained'] as num?)?.toDouble() ?? 0.0;
            final maxM = (g['max_marks'] as num?)?.toDouble() ?? 100.0;
            final pct = maxM > 0 ? (marks / maxM) * 100 : 0.0;
            byTerm.putIfAbsent(termStr, () => []).add(pct);
          }
          if (byTerm.length >= 2) {
            final sortedTerms = byTerm.keys.toList()..sort();
            return sortedTerms.map((t) {
              final pctList = byTerm[t]!;
              final avg = pctList.reduce((a, b) => a + b) / pctList.length;
              return {'term': t, 'avg_marks': double.parse(avg.toStringAsFixed(1))};
            }).toList();
          }
        }
      }
    } catch (_) {}

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_GradebookData>(
            future: _future,
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
              if (data.classes.isEmpty || data.subjects.isEmpty) {
                return const Center(child: Text("You don't have any classes/subjects on the timetable yet."));
              }

              _selectedClassId ??= data.classes.first['id'] as String;
              _selectedSubjectId ??= data.subjects.first['id'] as String;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text('Gradebook', style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedClassId,
                            decoration: const InputDecoration(labelText: 'Class'),
                            items: data.classes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                            onChanged: (v) => setState(() => _selectedClassId = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedSubjectId,
                            decoration: const InputDecoration(labelText: 'Subject'),
                            items: data.subjects.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String))).toList(),
                            onChanged: (v) => setState(() => _selectedSubjectId = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: TextField(
                      controller: _termController,
                      decoration: const InputDecoration(labelText: 'Term / Exam name'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      key: ValueKey('grade-trend-$_selectedClassId'),
                      future: _loadGradeTrend(_selectedClassId!),
                      builder: (context, snapshot) {
                        final trend = snapshot.data ?? [];
                        if (trend.length < 2) {
                          return GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.show_chart_outlined, color: AppColors.textSecondary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Not enough historical data yet for this class',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        }
                        final labels = trend.map((t) => (t['term']?.toString() ?? t['academic_year']?.toString() ?? '')).toList();
                        final values = trend.map((t) => (t['avg_marks'] as num?)?.toDouble() ?? 0.0).toList();
                        return SizedBox(
                          height: 160,
                          child: LineChart(
                            title: 'Grade Trend (Class Avg Marks)',
                            labels: labels,
                            values: values,
                            maxValue: 100.0,
                            chartColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      key: ValueKey('$_selectedClassId-$_selectedSubjectId-${_termController.text}'),
                      future: _loadRosterWithGrades(_selectedClassId!, _selectedSubjectId!, _termController.text),
                      builder: (context, rosterSnapshot) {
                        if (rosterSnapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }
                        final roster = rosterSnapshot.data ?? [];
                        if (roster.isEmpty) {
                          return const Center(child: Text('No students in this class yet.'));
                        }
                        return ListView(
                          padding: const EdgeInsets.all(20),
                          children: roster.map((r) {
                            final existing = r['existing_grade'] as Map<String, dynamic>?;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => _showMarkEntryDialog(r, _selectedSubjectId!, _termController.text),
                                borderRadius: BorderRadius.circular(AppRadii.card),
                                child: GlassCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      Text('${r['roll_no']}', style: Theme.of(context).textTheme.bodyMedium),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(r['full_name'] as String, style: Theme.of(context).textTheme.titleMedium)),
                                      if (existing != null)
                                        GlassChip(label: '${existing['marks_obtained']}/${existing['max_marks']}', color: AppColors.primary)
                                      else
                                        const Text('Not entered', style: TextStyle(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
}

class _GradebookData {
  _GradebookData({required this.selfStaffId, required this.classes, required this.subjects});
  final String? selfStaffId;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
}
