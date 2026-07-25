import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Student Library — the read-only counterpart to Teacher's Lesson Resources screen.
/// Same real table (academic.lesson_resources), filtered to whichever class this
/// student belongs to. No upload capability here — that stays teacher-only by RLS.
class StudentLibraryScreen extends ConsumerWidget {
  const StudentLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _load(ref, client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final resources = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Library', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  if (resources.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No resources shared for your class yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          resources.map((r) => Padding(
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
                                            if ((r['description'] as String?)?.isNotEmpty == true)
                                              Text(r['description'] as String, style: Theme.of(context).textTheme.bodyMedium),
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

  Future<List<Map<String, dynamic>>> _load(WidgetRef ref, SupabaseClient client) async {
    final selfStudentId = await ref.read(selfStudentIdProvider.future);
    if (selfStudentId == null) return [];

    final roster = await client.schema('academic').from('class_roster').select('class_id').eq('student_id', selfStudentId).maybeSingle();
    if (roster == null) return [];

    final resources = await client
        .schema('academic')
        .from('lesson_resources')
        .select('id, title, description, file_url, created_at')
        .eq('class_id', roster['class_id'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(resources as List);
  }
}
