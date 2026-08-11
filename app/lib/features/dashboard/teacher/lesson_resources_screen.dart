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

/// Lesson Plan / Resource Sharing — entirely new, no equivalent existed anywhere in
/// the app before tonight. A teacher shares a file (notes, slides, worksheets) tied to
/// one of their real classes; that class's students see it. Uses the new
/// academic.lesson_resources table + 'lesson-resources' storage bucket, both created
/// live tonight.
class LessonResourcesScreen extends ConsumerStatefulWidget {
  const LessonResourcesScreen({super.key});

  @override
  ConsumerState<LessonResourcesScreen> createState() => _LessonResourcesScreenState();
}

class _LessonResourcesScreenState extends ConsumerState<LessonResourcesScreen> {
  late Future<_ResourcesData> _future;
  bool _uploading = false;

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

    return _ResourcesData(selfStaffId: selfStaffId, teacherClasses: classes, resources: resources);
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
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _uploading || titleController.text.trim().isEmpty
                      ? null
                      : () {
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
              final canUpload = data.teacherClasses.isNotEmpty;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Lesson Resources', style: Theme.of(context).textTheme.headlineMedium),
                          if (canUpload)
                            ElevatedButton.icon(
                              onPressed: () => _showUploadSheet(data.teacherClasses),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Share'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (data.resources.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No resources shared yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          data.resources.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.folder_open_outlined, color: AppColors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r['title'] as String, style: Theme.of(context).textTheme.titleMedium),
                                            Text('${r['class_name']}${(r['description'] as String?)?.isNotEmpty == true ? ' · ${r['description']}' : ''}', style: Theme.of(context).textTheme.bodyMedium),
                                          ],
                                        ),
                                      ),
                                      if (r['file_url'] != null)
                                        IconButton(
                                          icon: const Icon(Icons.open_in_new, color: AppColors.primary),
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
  _ResourcesData({required this.selfStaffId, required this.teacherClasses, required this.resources});
  final String? selfStaffId;
  final List<Map<String, dynamic>> teacherClasses;
  final List<Map<String, dynamic>> resources;
}
