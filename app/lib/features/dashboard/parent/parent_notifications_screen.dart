import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Parent Notifications — the read-side for real notifications sent about any linked
/// child (fee reminders from Fee Management, or anything else written to
/// public.notifications in future). Requested explicitly: "no ambiguity on what's
/// owed and why" — the reminder body text (written when Fee Management sends it)
/// already includes the real amount and due date, shown here verbatim, not
/// summarized/reworded into something vaguer.
class ParentNotificationsScreen extends ConsumerWidget {
  const ParentNotificationsScreen({super.key});

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
              final notifications = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Notifications', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  if (notifications.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No notifications yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          notifications.map((n) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: Row(
                                    children: [
                                      Icon(
                                        n['type'] == 'fee_reminder' ? Icons.payments_outlined : Icons.notifications_outlined,
                                        color: AppColors.warning,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(n['title'] as String, style: Theme.of(context).textTheme.titleMedium),
                                            const SizedBox(height: 4),
                                            Text(n['body'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${n['student_name'] ?? ''} · ${(n['created_at'] as String).split('T').first}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
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
    final children = await ref.read(selfChildrenProvider.future);
    if (children.isEmpty) return [];

    final studentIds = children.map((c) => c.studentId).toList();
    final nameByStudentId = {for (final c in children) c.studentId: c.fullName};

    final notifications = await client
        .schema('public')
        .from('notifications')
        .select('id, recipient_student_id, type, title, body, created_at')
        .inFilter('recipient_student_id', studentIds)
        .order('created_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(notifications as List);
    for (final n in rows) {
      n['student_name'] = nameByStudentId[n['recipient_student_id']];
    }
    return rows;
  }
}
