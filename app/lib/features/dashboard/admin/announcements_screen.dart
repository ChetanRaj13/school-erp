import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Shared announcements screen — same screen for every role, since the read side is
/// identical (academic.announcements, school-wide or class-scoped). Only staff roles
/// (teacher/admin/principal) see the "New announcement" button — students/parents get
/// a read-only view. Matches the same role-aware-single-screen pattern already used
/// for LeaveRequestsScreen rather than duplicating near-identical screens per role.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = ref.read(supabaseClientProvider);
    final rows = await client
        .schema('academic')
        .from('announcements')
        .select('id, title, body, class_id, created_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> _post(String title, String body) async {
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
        // class_id intentionally left null — a school-wide announcement. Extending to
        // a class-specific picker is a straightforward follow-up, not built here to
        // keep this screen's first version simple and shippable.
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

  void _showPostSheet() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) return;
                  Navigator.of(context).pop();
                  _post(titleController.text.trim(), bodyController.text.trim());
                },
                child: const Text('Post announcement'),
              ),
            ],
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
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final announcements = snapshot.data!;

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
                              onPressed: _showPostSheet,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (announcements.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No announcements yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          announcements.map((a) => Padding(
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
                                      if ((a['body'] as String?)?.isNotEmpty ?? false) ...[
                                        const SizedBox(height: 8),
                                        Text(a['body'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                      ],
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
