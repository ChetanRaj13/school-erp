import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

class ParentNotificationsScreen extends ConsumerWidget {
  const ParentNotificationsScreen({super.key});

  static const _parentAccent = Color(0xFFFF6B9D);
  static const _parentAccentSoft = Color(0xFFFFE8F0);

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
                return const Center(child: CircularProgressIndicator(color: _parentAccent));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final notifications = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (notifications.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          notifications.map((n) {
                            final isFee = n['type'] == 'fee_reminder';
                            final iconBg = isFee ? const Color(0xFFFFECE6) : _parentAccentSoft;
                            final iconColor = isFee ? const Color(0xFFFF6B47) : _parentAccent;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: iconBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isFee ? Icons.payments_outlined : Icons.notifications_outlined,
                                        color: iconColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n['title'] as String,
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                                ),
                                              ),
                                              Text(
                                                (n['created_at'] as String).split('T').first,
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            n['body'] as String,
                                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                                          ),
                                          if (n['student_name'] != null) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.backgroundAlt,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'For: ${n['student_name']}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
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

  Future<List<Map<String, dynamic>>> _load(WidgetRef ref, SupabaseClient client) async {
    final children = await ref.read(selfChildrenProvider.future);
    if (children.isEmpty) return [];

    final studentIds = children.map((c) => c.studentId).toList();
    final studentNameById = {for (final c in children) c.studentId: c.fullName};

    try {
      final rows = await client
          .from('notifications')
          .select('id, recipient_student_id, type, title, body, created_at')
          .inFilter('recipient_student_id', studentIds)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) => {
                ...r as Map<String, dynamic>,
                'student_name': studentNameById[r['recipient_student_id']],
              })
          .toList();
    } catch (_) {
      try {
        final rows = await client
            .from('notifications')
            .select('id, type, title, body, created_at')
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(rows as List);
      } catch (e) {
        debugPrint('[Notifications] query error: $e');
        return [];
      }
    }
  }
}
