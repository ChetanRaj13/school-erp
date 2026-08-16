import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

class LessonResourcesScreen extends ConsumerStatefulWidget {
  const LessonResourcesScreen({super.key});

  @override
  ConsumerState<LessonResourcesScreen> createState() => _LessonResourcesScreenState();
}

class _LessonResourcesScreenState extends ConsumerState<LessonResourcesScreen> {
  late Future<_ResourcesData> _future;
  bool _uploading = false;

  // Search, Filter, Sort state
  String _searchQuery = '';
  String _selectedClassId = 'all';
  SortOption _sortOption = const SortOption(value: 'date_desc', label: 'Date: Newest First', icon: Icons.calendar_today);

  static const _sortOptions = [
    SortOption(value: 'date_desc', label: 'Date: Newest First', icon: Icons.calendar_today),
    SortOption(value: 'date_asc', label: 'Date: Oldest First', icon: Icons.calendar_today_outlined),
    SortOption(value: 'title_asc', label: 'Title: A → Z', icon: Icons.sort_by_alpha),
    SortOption(value: 'title_desc', label: 'Title: Z → A', icon: Icons.sort_by_alpha),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ResourcesData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);

    List<Map<String, dynamic>> classes = [];
    if (selfStaffId != null) {
      final timetableRows = await client.schema('scheduling').from('timetable').select('class_id').eq('teacher_id', selfStaffId);
      final classIds = (timetableRows as List).map((r) => r['class_id'] as String).toSet().toList();
      if (classIds.isNotEmpty) {
        final classesRaw = await client
            .schema('academic')
            .from('classes')
            .select('id, name')
            .inFilter('id', classIds)
            .eq('is_archived', false)
            .order('name');
        classes = List<Map<String, dynamic>>.from(classesRaw as List);
      }
    }

    final resourcesRaw = await client
        .schema('academic')
        .from('lesson_resources')
        .select('id, class_id, title, description, file_url, created_at')
        .order('created_at', ascending: false);
    final resources = List<Map<String, dynamic>>.from(resourcesRaw as List);

    final classIds = resources.map((r) => r['class_id']).toSet().toList();
    final allClasses = classIds.isEmpty
        ? []
        : await client.schema('academic').from('classes').select('id, name').inFilter('id', classIds);
    final classNameById = {for (final c in allClasses) c['id'] as String: c['name'] as String};
    for (final r in resources) {
      r['class_name'] = classNameById[r['class_id']] ?? 'Unknown';
    }

    return _ResourcesData(
      selfStaffId: selfStaffId,
      teacherClasses: classes,
      allClasses: List<Map<String, dynamic>>.from(allClasses),
      resources: resources,
    );
  }

  Future<void> _upload(String classId, String title, String description) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;

    setState(() => _uploading = true);
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    try {
      final file = result.files.first;
      final path = 'resources/$classId/${DateTime.now().millisecondsSinceEpoch}-${file.name}';
      await client.storage.from('lesson-resources').uploadBinary(path, file.bytes!, fileOptions: const FileOptions(upsert: true));
      final signedUrl = await client.storage.from('lesson-resources').createSignedUrl(path, 60 * 60 * 24 * 90);

      await client.schema('academic').from('lesson_resources').insert({
        'class_id': classId,
        'teacher_id': selfStaffId,
        'title': title,
        'description': description,
        'file_url': signedUrl,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource shared.'), backgroundColor: AppColors.success),
      );
      setState(() { _future = _load(); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showUploadSheet(List<Map<String, dynamic>> classes) {
    if (classes.isEmpty) return;
    Map<String, dynamic>? selectedClass = classes.first;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Share a Resource', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedClass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c['name'] as String))).toList(),
                  onChanged: (v) => setModalState(() => selectedClass = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title / topic (e.g. Chapter 4 Notes)')),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () {
                          if (titleController.text.trim().isEmpty || selectedClass == null) return;
                          Navigator.of(context).pop();
                          _upload(selectedClass!['id'] as String, titleController.text.trim(), descriptionController.text.trim());
                        },
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Pick file & share'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilterAndSort(List<Map<String, dynamic>> source) {
    var list = source.where((r) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (r['title'] as String? ?? '').toLowerCase();
        final desc = (r['description'] as String? ?? '').toLowerCase();
        final cls = (r['class_name'] as String? ?? '').toLowerCase();
        if (!title.contains(q) && !desc.contains(q) && !cls.contains(q)) {
          return false;
        }
      }
      if (_selectedClassId != 'all' && r['class_id'] != _selectedClassId) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sortOption.value) {
        case 'date_asc':
          final dA = a['created_at'] as String? ?? '';
          final dB = b['created_at'] as String? ?? '';
          return dA.compareTo(dB);
        case 'date_desc':
          final dA = a['created_at'] as String? ?? '';
          final dB = b['created_at'] as String? ?? '';
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
          child: FutureBuilder<_ResourcesData>(
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

              final displayedList = _applyFilterAndSort(data.resources);

              // Gather unique classes
              final filterClasses = data.allClasses.isNotEmpty ? data.allClasses : data.teacherClasses;
              final filterGroups = <FilterGroup>[
                FilterGroup(
                  title: 'Class',
                  currentValue: _selectedClassId,
                  options: [
                    const FilterOption(value: 'all', label: 'All Classes'),
                    ...filterClasses.map((c) => FilterOption(value: c['id'] as String, label: 'Class ${c['name']}')),
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
                          Text('Lesson Resources', style: Theme.of(context).textTheme.headlineMedium),
                          if (data.teacherClasses.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: _uploading ? null : () => _showUploadSheet(data.teacherClasses),
                              icon: _uploading
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.upload_file_outlined, size: 18),
                              label: Text(_uploading ? 'Uploading...' : 'Share'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: SearchFilterBar(
                        hintText: 'Search resources...',
                        onSearch: (val) => setState(() => _searchQuery = val),
                        filterGroups: filterGroups,
                        onFilterChanged: (group) {
                          setState(() => _selectedClassId = group.currentValue ?? 'all');
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
                          _searchQuery.isNotEmpty || _selectedClassId != 'all'
                              ? 'No matching resources found.'
                              : 'No resources shared yet.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          displayedList.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.menu_book_outlined, color: AppColors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r['title'] as String, style: Theme.of(context).textTheme.titleMedium),
                                            const SizedBox(height: 4),
                                            GlassChip(label: 'Class ${r['class_name']}', color: AppColors.primary),
                                            if ((r['description'] as String?)?.isNotEmpty == true) ...[
                                              const SizedBox(height: 6),
                                              Text(r['description'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (r['file_url'] != null)
                                        IconButton(
                                          icon: const Icon(Icons.open_in_new, color: AppColors.primary),
                                          tooltip: 'Open resource',
                                          onPressed: () => launchUrl(Uri.parse(r['file_url'] as String), webOnlyWindowName: '_blank'),
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
}

class _ResourcesData {
  _ResourcesData({
    required this.selfStaffId,
    required this.teacherClasses,
    required this.allClasses,
    required this.resources,
  });

  final String? selfStaffId;
  final List<Map<String, dynamic>> teacherClasses;
  final List<Map<String, dynamic>> allClasses;
  final List<Map<String, dynamic>> resources;
}
