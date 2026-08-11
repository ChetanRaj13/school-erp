import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Shared announcements screen — same screen for every role. Staff roles
/// (teacher/admin/principal) see a "New announcement" button; students/parents
/// get a read-only view.
///
/// Assembles announcements from academic.announcements, grouped or filtered by
/// the viewer's role. Evolving from 000 — teachers can now target announcements
/// to a specific class (the class_id column in the DB was already there, just
/// unused). Admin/principal still default to school-wide.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  late Future<_AnnouncementData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnnouncementData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);

    // Load announcements.
    final rows = await client
        .schema('academic')
        .from('announcements')
        .select('id, title, body, class_id, created_at, author_staff_id')
        .order('created_at', ascending: false);
    final announcements = List<Map<String, dynamic>>.from(rows as List);

    // Load classes for the picker.
    final classRows = await client
        .schema('academic')
        .from('classes')
        .select('id, name')
        .eq('is_archived', false)
        .order('name');
    final allClasses = List<Map<String, dynamic>>.from(classRows as List);
    final classNameById = {for (final c in allClasses) c['id'] as String: c['name'] as String};

    // For teacher: find which classes they teach via timetable or class_teacher_id.
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

    // Filter available classes to taught classes if available, otherwise show all classes
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
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Message'), maxLines: 4),
                const SizedBox(height: 12),
                // Target Class picker for Teachers / Staff
                DropdownButtonFormField<Map<String, dynamic>?>(
                  decoration: const InputDecoration(labelText: 'Target Audience'),
                  value: selectedClass,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('School-wide (all classes)')),
                    for (final c in availableClasses)
                      DropdownMenuItem(value: c, child: Text('${c['name']}${taughtClassIds.contains(c['id']) ? ' (My Class)' : ''}')),
                  ],
                  onChanged: (v) => setModalState(() => selectedClass = v),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.of(context).pop();
                    _post(
                      titleController.text.trim(),
                      bodyController.text.trim(),
                      selectedClass?['id'] as String?,
                    );
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

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final canPost = role == UserRole.teacher || role == UserRole.admin || role == UserRole.principal;

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
                  if (data.announcements.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No announcements yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          data.announcements.map((a) {
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
                                    const SizedBox(height: 4),
                                    // Scope badge.
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
