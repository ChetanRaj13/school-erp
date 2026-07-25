import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Parent Overview — a real performance summary (attendance %, recent grades,
/// assignment completion), NOT a fee dashboard. Fees move to their own dedicated
/// section per the explicit request — this screen leads with what the child is
/// actually doing at school, matching the same "students first, money separate"
/// principle already applied to the Student role.
class ParentOverviewScreen extends ConsumerStatefulWidget {
  const ParentOverviewScreen({super.key});

  @override
  ConsumerState<ParentOverviewScreen> createState() => _ParentOverviewScreenState();
}

class _ParentOverviewScreenState extends ConsumerState<ParentOverviewScreen> {
  String? _selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(selfChildrenProvider);
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (children) {
              if (children.isEmpty) {
                return const Center(child: Text('No children linked to your account yet.'));
              }
              final selected = children.firstWhere((c) => c.studentId == _selectedStudentId, orElse: () => children.first);

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text('Overview', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  if (children.length > 1)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: children.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final c = children[i];
                              final isSelected = c.studentId == selected.studentId;
                              return ChoiceChip(
                                label: Text(c.fullName),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedStudentId = c.studentId),
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                                backgroundColor: AppColors.glassFill,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverFillRemaining(
                      fillOverscroll: true,
                      hasScrollBody: false,
                      child: FutureBuilder<_ChildPerformance>(
                        future: _loadPerformance(client, selected.studentId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                          }
                          if (snapshot.hasError) {
                            return Text('Failed to load: ${snapshot.error}');
                          }
                          final perf = snapshot.data!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${selected.fullName} · ${selected.admissionNumber}', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: GlassCard(
                                      child: Column(
                                        children: [
                                          ProgressRing(
                                            value: perf.attendancePercent / 100,
                                            centerLabel: '${perf.attendancePercent.toStringAsFixed(0)}%',
                                            centerSubtitle: 'attendance',
                                            size: 84,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GlassCard(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.school_outlined, color: AppColors.primary),
                                          const SizedBox(height: 8),
                                          Text(
                                            perf.avgMarksPercent != null ? '${perf.avgMarksPercent!.toStringAsFixed(0)}%' : '—',
                                            style: Theme.of(context).textTheme.headlineMedium,
                                          ),
                                          Text('Average marks', style: Theme.of(context).textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GlassCard(
                                child: Row(
                                  children: [
                                    const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${perf.submittedAssignments}/${perf.totalAssignments} assignments submitted this term',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text('Quick Links', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              _QuickLinkTile(icon: Icons.calendar_today_outlined, label: 'Timetable', onTap: () => context.go('/parent/schedule')),
                              const SizedBox(height: 8),
                              _QuickLinkTile(icon: Icons.payments_outlined, label: 'Fees', onTap: () => context.go('/parent/fees')),
                              const SizedBox(height: 8),
                              _QuickLinkTile(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () => context.go('/parent/notifications')),
                              const SizedBox(height: 8),
                              _QuickLinkTile(icon: Icons.campaign_outlined, label: 'Announcements', onTap: () => context.go('/parent/announcements')),
                              const SizedBox(height: 8),
                              _QuickLinkTile(icon: Icons.mail_outline, label: 'Messages', onTap: () => context.go('/parent/messages')),
                              const SizedBox(height: 8),
                              _QuickLinkTile(icon: Icons.volunteer_activism_outlined, label: 'Scholarships & Waivers', onTap: () => context.go('/parent/waivers')),
                            ],
                          );
                        },
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

  Future<_ChildPerformance> _loadPerformance(SupabaseClient client, String studentId) async {
    final attendanceRaw = await client
        .schema('attendance')
        .from('records')
        .select('status')
        .eq('student_id', studentId)
        .order('date', ascending: false)
        .limit(30);
    final attendance = List<Map<String, dynamic>>.from(attendanceRaw as List);
    final attendancePercent = attendance.isEmpty ? 0.0 : attendance.where((a) => a['status'] == 'present').length / attendance.length * 100;

    final grades = await client.schema('academic').from('grades').select('marks_obtained, max_marks').eq('student_id', studentId);
    double? avgMarksPercent;
    if ((grades as List).isNotEmpty) {
      final percentages = grades.map((g) => (g['marks_obtained'] as num) / (g['max_marks'] as num) * 100).toList();
      avgMarksPercent = percentages.reduce((a, b) => a + b) / percentages.length;
    }

    final roster = await client.schema('academic').from('class_roster').select('class_id').eq('student_id', studentId).maybeSingle();
    int totalAssignments = 0;
    int submittedAssignments = 0;
    if (roster != null) {
      final assignments = await client.schema('academic').from('assignments').select('id').eq('class_id', roster['class_id']);
      totalAssignments = (assignments as List).length;
      final assignmentIds = assignments.map((a) => a['id']).toList();
      if (assignmentIds.isNotEmpty) {
        final submissions = await client
            .schema('academic')
            .from('submissions')
            .select('id')
            .eq('student_id', studentId)
            .inFilter('assignment_id', assignmentIds);
        submittedAssignments = (submissions as List).length;
      }
    }

    return _ChildPerformance(
      attendancePercent: attendancePercent,
      avgMarksPercent: avgMarksPercent,
      totalAssignments: totalAssignments,
      submittedAssignments: submittedAssignments,
    );
  }
}

class _ChildPerformance {
  _ChildPerformance({
    required this.attendancePercent,
    required this.avgMarksPercent,
    required this.totalAssignments,
    required this.submittedAssignments,
  });
  final double attendancePercent;
  final double? avgMarksPercent;
  final int totalAssignments;
  final int submittedAssignments;
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
