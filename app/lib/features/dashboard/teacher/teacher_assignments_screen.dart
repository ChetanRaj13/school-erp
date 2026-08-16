import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

class TeacherAssignmentsScreen extends ConsumerStatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  ConsumerState<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends ConsumerState<TeacherAssignmentsScreen> {
  late Future<_TeacherAssignmentData> _future;

  // Search, Filter, Sort state
  String _searchQuery = '';
  String _selectedClassId = 'all';
  String _selectedSubjectId = 'all';
  SortOption _sortOption = const SortOption(value: 'due_date_desc', label: 'Due: Newest First', icon: Icons.calendar_today);

  static const _sortOptions = [
    SortOption(value: 'due_date_desc', label: 'Due: Newest First', icon: Icons.calendar_today),
    SortOption(value: 'due_date_asc', label: 'Due: Oldest First', icon: Icons.calendar_today_outlined),
    SortOption(value: 'title_asc', label: 'Title: A → Z', icon: Icons.sort_by_alpha),
    SortOption(value: 'title_desc', label: 'Title: Z → A', icon: Icons.sort_by_alpha),
    SortOption(value: 'submissions_desc', label: 'Most Submissions', icon: Icons.assignment_turned_in),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TeacherAssignmentData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    if (selfStaffId == null) return _TeacherAssignmentData(selfStaffId: null, assignments: [], classes: [], subjects: []);

    final assignments = await client
        .schema('academic')
        .from('assignments')
        .select('id, title, description, due_date, class_id, subject_id')
        .eq('teacher_id', selfStaffId)
        .order('due_date', ascending: false);

    final submissionCounts = <String, int>{};
    for (final a in assignments as List) {
      final subs = await client.schema('academic').from('submissions').select('id').eq('assignment_id', a['id']);
      submissionCounts[a['id'] as String] = (subs as List).length;
    }

    final classes = await client
        .schema('academic')
        .from('classes')
        .select('id, name')
        .eq('is_archived', false)
        .order('name');
    final subjectsRaw = await client.schema('academic').from('subjects').select('id, name');

    final seenNames = <String>{};
    final subjects = (subjectsRaw as List).where((s) => seenNames.add(s['name'] as String)).toList();
    final subjectNameById = {for (final s in subjects) s['id'] as String: s['name'] as String};
    final classNameById = {for (final c in classes as List) c['id'] as String: c['name'] as String};

    return _TeacherAssignmentData(
      selfStaffId: selfStaffId,
      assignments: List<Map<String, dynamic>>.from(assignments).map((a) {
        a['submission_count'] = submissionCounts[a['id']] ?? 0;
        a['subject_name'] = subjectNameById[a['subject_id']] ?? 'General';
        a['class_name'] = classNameById[a['class_id']] ?? 'Class';
        return a;
      }).toList(),
      classes: List<Map<String, dynamic>>.from(classes as List),
      subjects: List<Map<String, dynamic>>.from(subjects),
    );
  }

  Future<void> _postAssignment(String staffId, String classId, String subjectId, String title, String desc, DateTime due) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('academic').from('assignments').insert({
        'class_id': classId,
        'subject_id': subjectId,
        'teacher_id': staffId,
        'title': title,
        'description': desc,
        'due_date': due.toIso8601String().split('T').first,
      });
      _refresh('Assignment posted.');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _viewSubmissions(String assignmentId, String title) async {
    final client = ref.read(supabaseClientProvider);
    final subs = await client
        .schema('academic')
        .from('submissions')
        .select('id, student_id, status, grade, feedback, file_url')
        .eq('assignment_id', assignmentId);
    final studentIds = (subs as List).map((s) => s['student_id']).toList();
    final students = studentIds.isEmpty ? [] : await client.schema('public').from('students').select('id, full_name').inFilter('id', studentIds);
    final nameById = {for (final s in students) s['id'] as String: s['full_name'] as String};

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Submissions — $title', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(
              child: subs.isEmpty
                  ? const Center(child: Text('No submissions yet.'))
                  : ListView.builder(
                      itemCount: subs.length,
                      itemBuilder: (context, i) {
                        final s = subs[i];
                        final fileUrl = s['file_url'] as String?;
                        return ListTile(
                          title: Text(nameById[s['student_id']] ?? 'Unknown'),
                          subtitle: Text(s['grade'] != null ? 'Grade: ${s['grade']}' : 'Status: ${s['status']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (fileUrl != null && fileUrl.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  tooltip: 'Open submitted file',
                                  onPressed: () => launchUrl(Uri.parse(fileUrl), webOnlyWindowName: '_blank'),
                                ),
                              TextButton(
                                onPressed: () => _showGradeDialog(s['id'] as String, nameById[s['student_id']] ?? 'Unknown'),
                                child: const Text('Grade'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGradeDialog(String submissionId, String studentName) {
    final gradeController = TextEditingController();
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Grade — $studentName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: gradeController, decoration: const InputDecoration(labelText: 'Grade (e.g. A, 85/100)')),
            TextField(controller: feedbackController, decoration: const InputDecoration(labelText: 'Feedback')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              try {
                await client.schema('academic').from('submissions').update({
                  'grade': gradeController.text.trim(),
                  'feedback': feedbackController.text.trim(),
                  'status': 'graded',
                }).eq('id', submissionId);
                if (!mounted) return;
                Navigator.of(context).pop();
                _refresh('Grade saved.');
              } catch (e) {
                _showError(e);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _refresh(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
    setState(() { _future = _load(); });
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
  }

  void _showPostSheet(String staffId, List<Map<String, dynamic>> classes, List<Map<String, dynamic>> subjects) {
    if (classes.isEmpty || subjects.isEmpty) return;
    Map<String, dynamic>? selectedClass = classes.first;
    Map<String, dynamic>? selectedSubject = subjects.first;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final due = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('New Assignment', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedClass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c['name'] as String))).toList(),
                  onChanged: (v) => setModalState(() => selectedClass = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedSubject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s['name'] as String))).toList(),
                  onChanged: (v) => setModalState(() => selectedSubject = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.of(context).pop();
                    _postAssignment(staffId, selectedClass!['id'] as String, selectedSubject!['id'] as String, titleController.text.trim(), descController.text.trim(), due);
                  },
                  child: const Text('Post assignment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilterAndSort(List<Map<String, dynamic>> source) {
    var list = source.where((a) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (a['title'] as String? ?? '').toLowerCase();
        final desc = (a['description'] as String? ?? '').toLowerCase();
        final subj = (a['subject_name'] as String? ?? '').toLowerCase();
        final cls = (a['class_name'] as String? ?? '').toLowerCase();
        if (!title.contains(q) && !desc.contains(q) && !subj.contains(q) && !cls.contains(q)) {
          return false;
        }
      }
      if (_selectedClassId != 'all' && a['class_id'] != _selectedClassId) {
        return false;
      }
      if (_selectedSubjectId != 'all' && a['subject_id'] != _selectedSubjectId) {
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
        case 'submissions_desc':
          return ((b['submission_count'] as num?) ?? 0).compareTo((a['submission_count'] as num?) ?? 0);
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
          child: FutureBuilder<_TeacherAssignmentData>(
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

              final displayedList = _applyFilterAndSort(data.assignments);

              final filterGroups = <FilterGroup>[
                FilterGroup(
                  title: 'Class',
                  currentValue: _selectedClassId,
                  options: [
                    const FilterOption(value: 'all', label: 'All Classes'),
                    ...data.classes.map((c) => FilterOption(value: c['id'] as String, label: c['name'] as String)),
                  ],
                ),
                FilterGroup(
                  title: 'Subject',
                  currentValue: _selectedSubjectId,
                  options: [
                    const FilterOption(value: 'all', label: 'All Subjects'),
                    ...data.subjects.map((s) => FilterOption(value: s['id'] as String, label: s['name'] as String)),
                  ],
                ),
              ];

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Assignments', style: Theme.of(context).textTheme.headlineMedium),
                          ElevatedButton.icon(
                            onPressed: () => _showPostSheet(data.selfStaffId!, data.classes, data.subjects),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: SearchFilterBar(
                        hintText: 'Search assignments...',
                        onSearch: (val) => setState(() => _searchQuery = val),
                        filterGroups: filterGroups,
                        onFilterChanged: (group) {
                          setState(() {
                            if (group.title == 'Class') {
                              _selectedClassId = group.currentValue ?? 'all';
                            } else if (group.title == 'Subject') {
                              _selectedSubjectId = group.currentValue ?? 'all';
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
                          _searchQuery.isNotEmpty || _selectedClassId != 'all' || _selectedSubjectId != 'all'
                              ? 'No matching assignments found.'
                              : 'No assignments posted yet.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          displayedList.map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () => _viewSubmissions(a['id'] as String, a['title'] as String),
                                  borderRadius: BorderRadius.circular(AppRadii.card),
                                  child: GlassCard(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(a['title'] as String, style: Theme.of(context).textTheme.titleMedium),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  GlassChip(label: a['class_name'] as String, color: AppColors.primary),
                                                  const SizedBox(width: 6),
                                                  GlassChip(label: a['subject_name'] as String, color: AppColors.textSecondary),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text('Due ${a['due_date']}', style: Theme.of(context).textTheme.bodyMedium),
                                            ],
                                          ),
                                        ),
                                        GlassChip(label: '${a['submission_count']} submitted', icon: Icons.assignment_turned_in_outlined),
                                      ],
                                    ),
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
}

class _TeacherAssignmentData {
  _TeacherAssignmentData({required this.selfStaffId, required this.assignments, required this.classes, required this.subjects});
  final String? selfStaffId;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
}
