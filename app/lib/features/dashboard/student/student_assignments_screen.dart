import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// UPDATED: real file upload via file_picker + Supabase Storage's 'assignment-
/// submissions' bucket (created live tonight), replacing the earlier link-paste-only
/// version. academic.submissions.file_url now stores a real signed URL to an actual
/// uploaded file, not a manually typed link.
///
/// NEW DEPENDENCY: file_picker — not previously in this project's pubspec.yaml. See
/// the accompanying README for the exact line to add before this compiles.
class StudentAssignmentsScreen extends ConsumerStatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  ConsumerState<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends ConsumerState<StudentAssignmentsScreen> {
  late Future<_StudentAssignmentData> _future;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StudentAssignmentData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStudentId = await ref.read(selfStudentIdProvider.future);
    if (selfStudentId == null) {
      return _StudentAssignmentData(selfStudentId: null, assignments: [], submissionByAssignmentId: {});
    }

    // Uses .limit(1) instead of .maybeSingle() — a student can have more than one
    // class_roster row in the current seed data (a real data question, not something
    // this screen should crash over). Deterministically picks the earliest enrollment.
    final rosterRows = await client
        .schema('academic')
        .from('class_roster')
        .select('class_id')
        .eq('student_id', selfStudentId)
        .order('created_at')
        .limit(1);

    if ((rosterRows as List).isEmpty) {
      return _StudentAssignmentData(selfStudentId: selfStudentId, assignments: [], submissionByAssignmentId: {});
    }
    final classId = rosterRows[0]['class_id'];

    final assignments = await client
        .schema('academic')
        .from('assignments')
        .select('id, title, description, due_date, subject_id')
        .eq('class_id', classId)
        .order('due_date');

    final subjectIds = (assignments as List).map((a) => a['subject_id']).toSet().toList();
    final subjects = subjectIds.isEmpty ? [] : await client.schema('academic').from('subjects').select('id, name').inFilter('id', subjectIds);
    final subjectNameById = {for (final s in subjects) s['id'] as String: s['name'] as String};

    final assignmentIds = assignments.map((a) => a['id']).toList();
    final submissions = assignmentIds.isEmpty
        ? []
        : await client
            .schema('academic')
            .from('submissions')
            .select('id, assignment_id, status, grade, feedback, file_url')
            .eq('student_id', selfStudentId)
            .inFilter('assignment_id', assignmentIds);
    final submissionByAssignmentId = {for (final s in submissions) s['assignment_id'] as String: s};

    return _StudentAssignmentData(
      selfStudentId: selfStudentId,
      assignments: List<Map<String, dynamic>>.from(assignments).map((a) {
        a['subject_name'] = subjectNameById[a['subject_id']];
        return a;
      }).toList(),
      submissionByAssignmentId: submissionByAssignmentId,
    );
  }

  Future<void> _pickAndSubmit(String assignmentId, String studentId) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _showSnack('Could not read the selected file.', isError: true);
      return;
    }

    setState(() => _uploading = true);
    final client = ref.read(supabaseClientProvider);
    try {
      final path = 'submissions/$assignmentId/$studentId/${file.name}';
      await client.storage.from('assignment-submissions').uploadBinary(
            path,
            file.bytes!,
            fileOptions: const FileOptions(upsert: true),
          );
      final signedUrl = await client.storage.from('assignment-submissions').createSignedUrl(path, 60 * 60 * 24 * 30); // 30 days

      await client.schema('academic').from('submissions').insert({
        'assignment_id': assignmentId,
        'student_id': studentId,
        'file_url': signedUrl,
        'status': 'submitted',
      });

      _showSnack('Submitted: ${file.name}');
      setState(() { _future = _load(); });
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_StudentAssignmentData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              if (data.selfStudentId == null) {
                return const Center(child: Text("Your account isn't linked to a student record yet."));
              }

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(child: Text('Assignments', style: Theme.of(context).textTheme.headlineMedium)),
                  ),
                  if (data.assignments.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('No assignments for your class yet.')))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          data.assignments.map((a) {
                            final submission = data.submissionByAssignmentId[a['id']];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['title'] as String, style: Theme.of(context).textTheme.titleMedium),
                                    Text('${a['subject_name'] ?? 'Unknown'} · Due ${a['due_date']}', style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 10),
                                    if (submission == null)
                                      ElevatedButton.icon(
                                        onPressed: _uploading ? null : () => _pickAndSubmit(a['id'] as String, data.selfStudentId!),
                                        icon: _uploading
                                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.upload_file_outlined, size: 18),
                                        label: Text(_uploading ? 'Uploading...' : 'Upload file'),
                                      )
                                    else if (submission['grade'] != null)
                                      GlassChip(label: 'Graded: ${submission['grade']}', color: AppColors.success, icon: Icons.grade_outlined)
                                    else
                                      const GlassChip(label: 'Submitted — awaiting grade', icon: Icons.hourglass_empty),
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
}

class _StudentAssignmentData {
  _StudentAssignmentData({required this.selfStudentId, required this.assignments, required this.submissionByAssignmentId});
  final String? selfStudentId;
  final List<Map<String, dynamic>> assignments;
  final Map<String, dynamic> submissionByAssignmentId;
}
