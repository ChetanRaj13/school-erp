import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

class StudentAssignmentsScreen extends ConsumerStatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  ConsumerState<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends ConsumerState<StudentAssignmentsScreen> {
  late Future<_StudentAssignmentData> _future;
  bool _uploading = false;

  // Search, Filter, Sort state
  String _searchQuery = '';
  String _selectedSubject = 'all';
  String _selectedStatus = 'all';
  SortOption _sortOption = const SortOption(value: 'due_date_asc', label: 'Due: Earliest First', icon: Icons.calendar_today);

  static const _sortOptions = [
    SortOption(value: 'due_date_asc', label: 'Due: Earliest First', icon: Icons.calendar_today),
    SortOption(value: 'due_date_desc', label: 'Due: Latest First', icon: Icons.calendar_today_outlined),
    SortOption(value: 'title_asc', label: 'Title: A → Z', icon: Icons.sort_by_alpha),
    SortOption(value: 'title_desc', label: 'Title: Z → A', icon: Icons.sort_by_alpha),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StudentAssignmentData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStudentId = await ref.read(selfStudentIdProvider.future);
    if (selfStudentId == null) {
      return _StudentAssignmentData(selfStudentId: null, assignments: [], submissionByAssignmentId: {}, subjectList: []);
    }

    final rosterRows = await client
        .schema('academic')
        .from('class_roster')
        .select('class_id')
        .eq('student_id', selfStudentId)
        .order('created_at')
        .limit(1);

    if ((rosterRows as List).isEmpty) {
      return _StudentAssignmentData(selfStudentId: selfStudentId, assignments: [], submissionByAssignmentId: {}, subjectList: []);
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

    final subjectNames = subjectNameById.values.toSet().toList()..sort();

    return _StudentAssignmentData(
      selfStudentId: selfStudentId,
      assignments: List<Map<String, dynamic>>.from(assignments).map((a) {
        a['subject_name'] = subjectNameById[a['subject_id']] ?? 'General';
        return a;
      }).toList(),
      submissionByAssignmentId: submissionByAssignmentId,
      subjectList: subjectNames,
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
      final signedUrl = await client.storage.from('assignment-submissions').createSignedUrl(path, 60 * 60 * 24 * 30);

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

  List<Map<String, dynamic>> _applyFilterAndSort(List<Map<String, dynamic>> source, Map<String, dynamic> submissionByAssignmentId) {
    var list = source.where((a) {
      final sub = submissionByAssignmentId[a['id']];
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (a['title'] as String? ?? '').toLowerCase();
        final desc = (a['description'] as String? ?? '').toLowerCase();
        final subj = (a['subject_name'] as String? ?? '').toLowerCase();
        if (!title.contains(q) && !desc.contains(q) && !subj.contains(q)) {
          return false;
        }
      }
      if (_selectedSubject != 'all' && a['subject_name'] != _selectedSubject) {
        return false;
      }
      if (_selectedStatus == 'submitted' && sub == null) {
        return false;
      }
      if (_selectedStatus == 'pending' && sub != null) {
        return false;
      }
      if (_selectedStatus == 'graded' && (sub == null || sub['grade'] == null)) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sortOption.value) {
        case 'due_date_asc':
          final dA = a['due_date'] as String? ?? '';
          final dB = b['due_date'] as String? ?? '';
          return dA.compareTo(dB);
        case 'due_date_desc':
          final dA = a['due_date'] as String? ?? '';
          final dB = b['due_date'] as String? ?? '';
          return dB.compareTo(dA);
        case 'title_asc':
          return (a['title'] as String? ?? '').compareTo(b['title'] as String? ?? '');
        case 'title_desc':
          return (b['title'] as String? ?? '').compareTo(a['title'] as String? ?? '');
        default:
          return 0;
      }
    });

    return list;
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

              final displayedList = _applyFilterAndSort(data.assignments, data.submissionByAssignmentId);

              final filterGroups = <FilterGroup>[
                FilterGroup(
                  title: 'Subject',
                  currentValue: _selectedSubject,
                  options: [
                    const FilterOption(value: 'all', label: 'All Subjects'),
                    ...data.subjectList.map((s) => FilterOption(value: s, label: s)),
                  ],
                ),
                FilterGroup(
                  title: 'Status',
                  currentValue: _selectedStatus,
                  options: const [
                    FilterOption(value: 'all', label: 'All Statuses'),
                    FilterOption(value: 'pending', label: 'Pending Upload'),
                    FilterOption(value: 'submitted', label: 'Submitted'),
                    FilterOption(value: 'graded', label: 'Graded'),
                  ],
                ),
              ];

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(child: Text('Assignments', style: Theme.of(context).textTheme.headlineMedium)),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: SearchFilterBar(
                        hintText: 'Search assignments or subjects...',
                        onSearch: (val) => setState(() => _searchQuery = val),
                        filterGroups: filterGroups,
                        onFilterChanged: (group) {
                          setState(() {
                            if (group.title == 'Subject') {
                              _selectedSubject = group.currentValue ?? 'all';
                            } else if (group.title == 'Status') {
                              _selectedStatus = group.currentValue ?? 'all';
                            }
                          });
                        },
                        sorts: _sortOptions,
                        currentSortValue: _sortOption.value,
                        onSortSelected: (option) => setState(() => _sortOption = option),
                      ),
                    ),
                  ),
                  if (displayedList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          _searchQuery.isNotEmpty || _selectedSubject != 'all' || _selectedStatus != 'all'
                              ? 'No matching assignments found.'
                              : 'No assignments for your class yet.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          displayedList.map((a) {
                            final submission = data.submissionByAssignmentId[a['id']];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['title'] as String, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        GlassChip(label: a['subject_name'] as String, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Text('Due ${a['due_date']}', style: Theme.of(context).textTheme.bodyMedium),
                                      ],
                                    ),
                                    if ((a['description'] as String?)?.isNotEmpty == true) ...[
                                      const SizedBox(height: 6),
                                      Text(a['description'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                    ],
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
  _StudentAssignmentData({
    required this.selfStudentId,
    required this.assignments,
    required this.submissionByAssignmentId,
    required this.subjectList,
  });
  final String? selfStudentId;
  final List<Map<String, dynamic>> assignments;
  final Map<String, dynamic> submissionByAssignmentId;
  final List<String> subjectList;
}
