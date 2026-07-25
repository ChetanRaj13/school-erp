import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Student Overview — DELIBERATELY excludes any fee/financial data. Per an explicit
/// request: students shouldn't see fee balances at all, regardless of framing — it's
/// not their responsibility and can cause real anxiety, especially for families under
/// financial strain. This is a values decision baked into what data this screen even
/// queries, not just what's displayed — it never fetches finance.invoices at all.
///
/// Streaks and badges are computed LIVE from real attendance/submission timestamps
/// every time this loads — not stored in a separate table, so they can never drift
/// out of sync with what actually happened.
class StudentOverviewScreen extends ConsumerWidget {
  const StudentOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_OverviewData>(
            future: _load(ref, client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              if (data.selfStudentId == null) {
                return const Center(child: Text("Your account isn't linked to a student record yet."));
              }

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Overview', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            Expanded(
                              child: GlassCard(
                                child: Column(
                                  children: [
                                    ProgressRing(
                                      value: data.attendancePercent / 100,
                                      centerLabel: '${data.attendancePercent.toStringAsFixed(0)}%',
                                      centerSubtitle: 'attendance',
                                      size: 88,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  _StatCard(icon: Icons.assignment_late_outlined, label: 'Due soon', value: '${data.dueSoonCount}'),
                                  const SizedBox(height: 12),
                                  _StatCard(icon: Icons.today_outlined, label: "Today's periods", value: '${data.todayPeriodCount}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (data.attendanceStreak >= 3 || data.onTimeStreak >= 3) ...[
                          Text('Streaks', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (data.attendanceStreak >= 3)
                                Expanded(
                                  child: _BadgeCard(
                                    icon: Icons.local_fire_department_outlined,
                                    label: '${data.attendanceStreak}-day streak',
                                    subtitle: 'Attendance',
                                    color: AppColors.warning,
                                  ),
                                ),
                              if (data.attendanceStreak >= 3 && data.onTimeStreak >= 3) const SizedBox(width: 10),
                              if (data.onTimeStreak >= 3)
                                Expanded(
                                  child: _BadgeCard(
                                    icon: Icons.bolt_outlined,
                                    label: '${data.onTimeStreak} in a row',
                                    subtitle: 'On-time submissions',
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        Text('Quick Links', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        _QuickLinkTile(icon: Icons.calendar_today_outlined, label: 'My Schedule', onTap: () => context.go('/student/schedule')),
                        const SizedBox(height: 8),
                        _QuickLinkTile(icon: Icons.assignment_outlined, label: 'Assignments', onTap: () => context.go('/student/assignments')),
                        const SizedBox(height: 8),
                        _QuickLinkTile(icon: Icons.grade_outlined, label: 'Grades & Progress', onTap: () => context.go('/student/progress')),
                        const SizedBox(height: 8),
                        _QuickLinkTile(icon: Icons.menu_book_outlined, label: 'Library', onTap: () => context.go('/student/library')),
                        const SizedBox(height: 8),
                        _QuickLinkTile(icon: Icons.campaign_outlined, label: 'Announcements', onTap: () => context.go('/student/announcements')),
                      ]),
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

  Future<_OverviewData> _load(WidgetRef ref, SupabaseClient client) async {
    final selfStudentId = await ref.read(selfStudentIdProvider.future);
    if (selfStudentId == null) {
      return _OverviewData(selfStudentId: null, attendancePercent: 0, attendanceStreak: 0, onTimeStreak: 0, dueSoonCount: 0, todayPeriodCount: 0);
    }

    final attendanceRaw = await client
        .schema('attendance')
        .from('records')
        .select('date, status')
        .eq('student_id', selfStudentId)
        .order('date', ascending: false)
        .limit(30);
    final attendance = List<Map<String, dynamic>>.from(attendanceRaw as List);

    final attendancePercent = attendance.isEmpty ? 0.0 : attendance.where((a) => a['status'] == 'present').length / attendance.length * 100;

    int attendanceStreak = 0;
    for (final a in attendance) {
      if (a['status'] == 'present') {
        attendanceStreak++;
      } else {
        break;
      }
    }

    final submissions = await client
        .schema('academic')
        .from('submissions')
        .select('assignment_id, submitted_at')
        .eq('student_id', selfStudentId)
        .order('submitted_at', ascending: false)
        .limit(20);
    final assignmentIds = (submissions as List).map((s) => s['assignment_id'] as String).toSet().toList();
    final assignments = assignmentIds.isEmpty
        ? []
        : await client.schema('academic').from('assignments').select('id, due_date').inFilter('id', assignmentIds);
    final dueDateByAssignmentId = {for (final a in assignments) a['id'] as String: a['due_date'] as String};

    int onTimeStreak = 0;
    for (final s in submissions) {
      final dueDateStr = dueDateByAssignmentId[s['assignment_id']];
      final submittedAt = DateTime.tryParse(s['submitted_at'] as String? ?? '');
      final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;
      if (submittedAt != null && dueDate != null && !submittedAt.isAfter(dueDate.add(const Duration(days: 1)))) {
        onTimeStreak++;
      } else {
        break;
      }
    }

    final roster = await client.schema('academic').from('class_roster').select('class_id').eq('student_id', selfStudentId).maybeSingle();
    int dueSoonCount = 0;
    int todayPeriodCount = 0;
    if (roster != null) {
      final classId = roster['class_id'] as String;
      final classAssignments = await client.schema('academic').from('assignments').select('id, due_date').eq('class_id', classId);
      final submittedIds = (await client.schema('academic').from('submissions').select('assignment_id').eq('student_id', selfStudentId))
          .map((s) => s['assignment_id'] as String)
          .toSet();
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));
      dueSoonCount = (classAssignments as List).where((a) {
        if (submittedIds.contains(a['id'])) return false;
        final due = DateTime.tryParse(a['due_date'] as String);
        return due != null && !due.isBefore(now) && !due.isAfter(weekFromNow);
      }).length;

      const weekdayCodes = ['mon', 'tue', 'wed', 'thu', 'fri'];
      final todayCode = now.weekday <= 5 ? weekdayCodes[now.weekday - 1] : null;
      if (todayCode != null) {
        final timetableRows = await client.schema('scheduling').from('timetable').select('slot_id').eq('class_id', classId);
        final slotIds = (timetableRows as List).map((r) => r['slot_id']).toList();
        if (slotIds.isNotEmpty) {
          final todaySlots = await client.schema('scheduling').from('time_slots').select('id').eq('day', todayCode).inFilter('id', slotIds);
          todayPeriodCount = (todaySlots as List).length;
        }
      }
    }

    return _OverviewData(
      selfStudentId: selfStudentId,
      attendancePercent: attendancePercent,
      attendanceStreak: attendanceStreak,
      onTimeStreak: onTimeStreak,
      dueSoonCount: dueSoonCount,
      todayPeriodCount: todayPeriodCount,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.icon, required this.label, required this.subtitle, required this.color});
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
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

class _OverviewData {
  _OverviewData({
    required this.selfStudentId,
    required this.attendancePercent,
    required this.attendanceStreak,
    required this.onTimeStreak,
    required this.dueSoonCount,
    required this.todayPeriodCount,
  });
  final String? selfStudentId;
  final double attendancePercent;
  final int attendanceStreak;
  final int onTimeStreak;
  final int dueSoonCount;
  final int todayPeriodCount;
}
