import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  late Future<_AnnouncementData> _future;

  // Search, Filter, Sort state
  String _searchQuery = '';
  String _selectedScope = 'all';
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

  Future<_AnnouncementData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);

    final rows = await client
        .schema('academic')
        .from('announcements')
        .select('id, title, body, class_id, created_at, author_staff_id')
        .order('created_at', ascending: false);
    final announcements = List<Map<String, dynamic>>.from(rows as List);

    final classRows = await client
        .schema('academic')
        .from('classes')
        .select('id, name')
        .eq('is_archived', false)
        .order('name');
    final allClasses = List<Map<String, dynamic>>.from(classRows as List);
    final classNameById = {for (final c in allClasses) c['id'] as String: c['name'] as String};

    Set<String> taughtClassIds = {};
    if (selfStaffId != null) {
      final tts = await client
          .schema('scheduling')
          .from('timetable')
          .select('class_id')
          .eq('teacher_id', selfStaffId);
      for (final t in tts as List) {
        final cid = t['class_id'] as String?;
        if (cid != null && cid.isNotEmpty) taughtClassIds.add(cid);
      }
      final ctClasses = await client
          .schema('academic')
          .from('classes')
          .select('id')
          .eq('class_teacher_id', selfStaffId);
      for (final c in ctClasses as List) {
        final cid = c['id'] as String?;
        if (cid != null && cid.isNotEmpty) taughtClassIds.add(cid);
      }
    }

    return _AnnouncementData(
      announcements: announcements,
      allClasses: allClasses,
      classNameById: classNameById,
      taughtClassIds: taughtClassIds,
    );
  }

  Future<void> _post(String title, String body, String? classId) async {
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    if (selfStaffId == null) {
      _showSnack('Your account must be linked to a staff record to post.', isError: true);
      return;
    }
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('academic').from('announcements').insert({
        'school_id': '11111111-1111-1111-1111-111111111111',
        'author_staff_id': selfStaffId,
        'title': title,
        'body': body,
        if (classId != null) 'class_id': classId,
      });
      _showSnack('Announcement posted.');
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
    setState(() { _future = _load(); });
  }

  void _showPostSheet(List<Map<String, dynamic>> allClasses, Set<String> taughtClassIds) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    Map<String, dynamic>? selectedClass;

    final availableClasses = taughtClassIds.isNotEmpty
        ? allClasses.where((c) => taughtClassIds.contains(c['id'])).toList()
        : allClasses;

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
                Text('New Announcement', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<Map<String, dynamic>?>(
                  initialValue: selectedClass,
                  decoration: const InputDecoration(
                    labelText: 'Target audience',
                    helperText: 'Leave as "School-wide" to broadcast to everyone',
                  ),
                  items: [
                    const DropdownMenuItem<Map<String, dynamic>?>(
                      value: null,
                      child: Text('School-wide (all classes)'),
                    ),
                    ...availableClasses.map(
                      (c) => DropdownMenuItem<Map<String, dynamic>?>(
                        value: c,
                        child: Text('Class ${c['name']}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => selectedClass = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  decoration: const InputDecoration(labelText: 'Body / details'),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.of(context).pop();
                    _post(title, bodyController.text.trim(), selectedClass?['id'] as String?);
                  },
                  child: const Text('Post announcement'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilterAndSort(List<Map<String, dynamic>> source, Map<String, String> classNameById) {
    var list = source.where((a) {
      final classId = a['class_id'] as String?;
      final className = classId != null ? (classNameById[classId] ?? '') : 'School-wide';
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (a['title'] as String? ?? '').toLowerCase();
        final body = (a['body'] as String? ?? '').toLowerCase();
        if (!title.contains(q) && !body.contains(q) && !className.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_selectedScope == 'school_wide' && classId != null) {
        return false;
      }
      if (_selectedScope == 'class_specific' && classId == null) {
        return false;
      }
      if (_selectedScope != 'all' && _selectedScope != 'school_wide' && _selectedScope != 'class_specific') {
        if (classId != _selectedScope) return false;
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
    final role = ref.watch(userRoleProvider);
    final canPost = role == UserRole.admin || role == UserRole.principal || role == UserRole.teacher;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_AnnouncementData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              final displayedList = _applyFilterAndSort(data.announcements, data.classNameById);

              final filterGroups = <FilterGroup>[
                FilterGroup(
                  title: 'Scope',
                  currentValue: _selectedScope,
                  options: [
                    const FilterOption(value: 'all', label: 'All Announcements'),
                    const FilterOption(value: 'school_wide', label: 'School-wide only'),
                    const FilterOption(value: 'class_specific', label: 'Class-specific only'),
                    ...data.allClasses.map((c) => FilterOption(value: c['id'] as String, label: 'Class ${c['name']}')),
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
                          Text('Announcements', style: Theme.of(context).textTheme.headlineMedium),
                          if (canPost)
                            ElevatedButton.icon(
                              onPressed: () => _showPostSheet(data.allClasses, data.taughtClassIds),
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
                        hintText: 'Search announcements...',
                        onSearch: (val) => setState(() => _searchQuery = val),
                        filterGroups: filterGroups,
                        onFilterChanged: (group) {
                          setState(() => _selectedScope = group.currentValue ?? 'all');
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
                          _searchQuery.isNotEmpty || _selectedScope != 'all'
                              ? 'No matching announcements found.'
                              : 'No announcements yet.',
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
                            final classId = a['class_id'] as String?;
                            final scopeLabel = classId != null
                                ? (data.classNameById[classId] ?? 'A class')
                                : 'School-wide';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.campaign_outlined, color: AppColors.primary, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(a['title'] as String, style: Theme.of(context).textTheme.titleMedium),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    GlassChip(
                                      label: scopeLabel,
                                      color: classId != null ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                    if ((a['body'] as String?)?.isNotEmpty ?? false) ...[
                                      const SizedBox(height: 8),
                                      Text(a['body'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                    ],
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

class _AnnouncementData {
  _AnnouncementData({
    required this.announcements,
    required this.allClasses,
    required this.classNameById,
    required this.taughtClassIds,
  });

  final List<Map<String, dynamic>> announcements;
  final List<Map<String, dynamic>> allClasses;
  final Map<String, String> classNameById;
  final Set<String> taughtClassIds;
}
