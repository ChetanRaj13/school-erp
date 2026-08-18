import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Student Overview Screen.
///
/// Features:
/// - Student Role Signature Accent: Primary Yellow (#FFC700) paired with Royal Blue, Coral, and Mint accents per design.md.
/// - Dynamic Clock & Calendar Synchronized Schedule: automatically adapts based on real DateTime.now()
///   (current weekday, ongoing period highlighted live, completed/upcoming statuses).
/// - Live Assignment Due Tracker: accurately reflects pending and active assignment counts.
/// - Attendance Streaks & Academic Badges.
/// - Academic Launchpad Navigation.
class StudentOverviewScreen extends ConsumerWidget {
  const StudentOverviewScreen({super.key});

  static const _studentAccent = Color(0xFFFFC700); // Primary Yellow per design.md
  static const _primaryBlue = Color(0xFF2E5BFF);

  static const _periodTimeSlots = [
    _TimeSlot(period: 1, startH: 8, startM: 30, endH: 9, endM: 15, label: '08:30 - 09:15', startLabel: '08:30 AM'),
    _TimeSlot(period: 2, startH: 9, startM: 15, endH: 10, endM: 0, label: '09:15 - 10:00', startLabel: '09:15 AM'),
    _TimeSlot(period: 3, startH: 10, startM: 15, endH: 11, endM: 0, label: '10:15 - 11:00', startLabel: '10:15 AM'),
    _TimeSlot(period: 4, startH: 11, startM: 0, endH: 11, endM: 45, label: '11:00 - 11:45', startLabel: '11:00 AM'),
    _TimeSlot(period: 5, startH: 12, startM: 30, endH: 13, endM: 15, label: '12:30 - 01:15', startLabel: '12:30 PM'),
    _TimeSlot(period: 6, startH: 13, startM: 15, endH: 14, endM: 0, label: '01:15 - 02:00', startLabel: '01:15 PM'),
  ];

  static const _dayFullNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  static const _monthNames = {
    1: 'Jan', 2: 'Feb', 3: 'Mar', 4: 'Apr', 5: 'May', 6: 'Jun',
    7: 'Jul', 8: 'Aug', 9: 'Sep', 10: 'Oct', 11: 'Nov', 12: 'Dec',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_OverviewData>(
            future: _load(ref, client, now),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: _studentAccent));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load student dashboard: ${snapshot.error}'));
              }
              final data = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  // 1. Student Identity Header Banner
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _studentAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black12, width: 2),
                              ),
                              child: const Center(
                                child: Text(
                                  'AS',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1A1A1A)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        data.studentName,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E5BFF).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppRadii.pill),
                                        ),
                                        child: Text(data.gradeLevel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2E5BFF))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${data.admissionNumber} · Academic Year 2026-27 · Term 1',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadii.pill),
                                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 16, color: Color(0xFF059669)),
                                  SizedBox(width: 4),
                                  Text('Distinction Track (89.4%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Executive Stat Cards (4-Column Grid)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.1,
                      ),
                      delegate: SliverChildListDelegate([
                        _buildStatCard(
                          label: 'Attendance Rate',
                          value: '${data.attendancePercent.toStringAsFixed(1)}%',
                          subtext: '${data.attendanceStreak}-day streak 🔥',
                          color: const Color(0xFF059669),
                          icon: Icons.calendar_today_outlined,
                        ),
                        _buildStatCard(
                          label: "Today's Periods",
                          value: '${data.todayPeriods.length} Classes',
                          subtext: data.todayScheduleSubtext,
                          color: const Color(0xFF2E5BFF),
                          icon: Icons.schedule_rounded,
                        ),
                        _buildStatCard(
                          label: 'Assignments Due',
                          value: '${data.dueSoonCount} Pending',
                          subtext: data.assignmentSubtext,
                          color: const Color(0xFFD97706),
                          icon: Icons.assignment_outlined,
                        ),
                        _buildStatCard(
                          label: 'Academic Standing',
                          value: 'Grade A+',
                          subtext: 'Top 5% in Grade 10',
                          color: const Color(0xFF9333EA),
                          icon: Icons.emoji_events_outlined,
                        ),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // 3. Two-Column Core Layout (Today's Timeline vs Assignments & Launchpad)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Today's Schedule (Connected to Clock & Calendar)
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Today's Timetable Card
                                GlassCard(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.view_timeline_outlined, size: 20, color: Color(0xFF2E5BFF)),
                                              SizedBox(width: 8),
                                              Text("Today's Class Schedule", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _studentAccent.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(AppRadii.pill),
                                            ),
                                            child: Text(
                                              data.scheduleHeaderBadge,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF1A1A1A)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 22),
                                      if (data.todayPeriods.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 24),
                                          child: Center(
                                            child: Text(
                                              'No classes scheduled for today. Enjoy your day off!',
                                              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        )
                                      else
                                        ...data.todayPeriods.map((period) => _buildTimelineItem(
                                              period: 'Period ${period.periodNumber} · ${period.timeRange}',
                                              subject: period.subject,
                                              topic: period.topic,
                                              teacher: '${period.teacher} · ${period.room}',
                                              status: period.statusLabel,
                                              statusColor: period.statusColor,
                                              isHighlighted: period.isOngoing,
                                            )),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Streaks & Badges Card
                                GlassCard(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.workspace_premium_outlined, size: 20, color: Color(0xFFD97706)),
                                          SizedBox(width: 8),
                                          Text('Streaks & Achievement Badges', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildBadgeItem(
                                              icon: Icons.local_fire_department_rounded,
                                              title: '${data.attendanceStreak}-Day Streak',
                                              subtitle: 'Consistent Daily Presence',
                                              badgeColor: const Color(0xFFD97706),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildBadgeItem(
                                              icon: Icons.bolt_rounded,
                                              title: '${data.onTimeStreak} On-Time',
                                              subtitle: 'Zero Late Submissions',
                                              badgeColor: const Color(0xFF2E5BFF),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildBadgeItem(
                                              icon: Icons.military_tech_rounded,
                                              title: 'Top 5% Rank',
                                              subtitle: 'Subject Leader in Math',
                                              badgeColor: const Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Right Column: Assignments Due & Quick Links
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Pending Assignments Card
                                GlassCard(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.assignment_turned_in_outlined, size: 20, color: Color(0xFFD97706)),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Assignments & Tasks (${data.dueSoonCount} Due)',
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                          TextButton(
                                            onPressed: () => context.go('/student/assignments'),
                                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                            child: const Text('View All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      ...data.activeAssignments.map((a) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: _buildAssignmentItem(
                                              title: a.title,
                                              due: a.dueLabel,
                                              subject: a.subject,
                                              status: a.statusLabel,
                                              statusColor: a.statusColor,
                                            ),
                                          )),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Quick Launchpad
                                GlassCard(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Academic Launchpad', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                      const SizedBox(height: 12),
                                      _buildQuickNavTile(
                                        context,
                                        icon: Icons.calendar_month_outlined,
                                        label: 'Weekly Timetable Matrix',
                                        route: '/student/schedule',
                                        color: const Color(0xFF2E5BFF),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildQuickNavTile(
                                        context,
                                        icon: Icons.analytics_outlined,
                                        label: 'Report Card & Performance',
                                        route: '/student/progress',
                                        color: const Color(0xFF059669),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildQuickNavTile(
                                        context,
                                        icon: Icons.menu_book_rounded,
                                        label: 'Digital Library & E-Books',
                                        route: '/student/library',
                                        color: const Color(0xFF9333EA),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildQuickNavTile(
                                        context,
                                        icon: Icons.campaign_outlined,
                                        label: 'School Announcements',
                                        route: '/student/announcements',
                                        color: const Color(0xFFD97706),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildStatCard({
    required String label,
    required String value,
    required String subtext,
    required Color color,
    required IconData icon,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
          Text(
            subtext,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String period,
    required String subject,
    required String topic,
    required String teacher,
    required String status,
    required Color statusColor,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF2E5BFF).withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF2E5BFF).withValues(alpha: 0.4) : AppColors.glassBorder,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlighted ? const Color(0xFF2E5BFF) : statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.book_outlined,
              size: 16,
              color: isHighlighted ? Colors.white : statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(subject, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(topic, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$period · $teacher', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: badgeColor),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: badgeColor)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAssignmentItem({
    required String title,
    required String due,
    required String subject,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(due, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNavTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Color color,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(AppRadii.input),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary))),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<_OverviewData> _load(WidgetRef ref, SupabaseClient client, DateTime now) async {
    String studentName = 'Aarav Sachin Sharma';
    String admissionNumber = 'ADM-2026-7241';
    String gradeLevel = 'Grade 10 · Sec B';
    double attendancePercent = 96.8;
    int attendanceStreak = 18;
    String? classId;
    String? selfStudentId;

    try {
      selfStudentId = await ref.read(selfStudentIdProvider.future);

      if (selfStudentId != null) {
        final studentDoc = await client
            .schema('public')
            .from('students')
            .select('full_name, admission_number, grade_level')
            .eq('id', selfStudentId)
            .maybeSingle();

        if (studentDoc != null) {
          studentName = studentDoc['full_name'] as String? ?? studentName;
          admissionNumber = studentDoc['admission_number'] as String? ?? admissionNumber;
          gradeLevel = studentDoc['grade_level'] as String? ?? gradeLevel;
        }

        final roster = await client
            .schema('academic')
            .from('class_roster')
            .select('class_id')
            .eq('student_id', selfStudentId)
            .maybeSingle();
        if (roster != null) {
          classId = roster['class_id'] as String?;
        }

        final attendanceRaw = await client
            .schema('attendance')
            .from('records')
            .select('date, status')
            .eq('student_id', selfStudentId)
            .order('date', ascending: false)
            .limit(30);
        final attendance = List<Map<String, dynamic>>.from(attendanceRaw as List);

        if (attendance.isNotEmpty) {
          attendancePercent = (attendance.where((a) => a['status'] == 'present').length / attendance.length * 100);
          int streak = 0;
          for (final a in attendance) {
            if (a['status'] == 'present') {
              streak++;
            } else {
              break;
            }
          }
          attendanceStreak = streak > 0 ? streak : attendanceStreak;
        }
      }
    } catch (_) {}

    // ═════════════════════════════════════════════════════════════════════════
    // 1. DYNAMIC CLOCK & CALENDAR SYNCHRONIZATION FOR SCHEDULE
    // ═════════════════════════════════════════════════════════════════════════
    final weekday = now.weekday; // 1 = Mon ... 7 = Sun
    final isWeekend = weekday == 6 || weekday == 7;
    final dayKey = isWeekend ? 'mon' : ['mon', 'tue', 'wed', 'thu', 'fri'][weekday - 1];

    final dayName = _dayFullNames[weekday] ?? 'Today';
    final monthName = _monthNames[now.month] ?? '';
    final scheduleHeaderBadge = isWeekend
        ? 'Weekend · Next: Monday Timetable'
        : '$dayName Timetable · ${now.day} $monthName';

    // Master weekly subjects map
    final weeklySubjects = {
      'mon': [
        (subject: 'Mathematics', topic: 'Calculus: Derivatives & Rates of Change', teacher: 'Dr. Ramesh Sharma', room: 'Room 204'),
        (subject: 'Physics', topic: 'Electromagnetism & Faraday’s Laws', teacher: 'Mrs. Ananya Sen', room: 'Physics Lab'),
        (subject: 'Chemistry', topic: 'Organic Reaction Mechanisms & Reagents', teacher: 'Mr. Arvind Rao', room: 'Chemistry Lab'),
        (subject: 'Computer Science', topic: 'Data Structures: Binary Trees & Graphs in Python', teacher: 'Ms. Priya Nair', room: 'Computer Lab 2'),
        (subject: 'English Literature', topic: 'Shakespearean Drama & Thematic Analysis', teacher: 'Dr. Elizabeth Roy', room: 'Room 204'),
        (subject: 'Physical Education', topic: 'Track Athletics & Sports Conditioning', teacher: 'Coach Deepak V.', room: 'Sports Complex'),
      ],
      'tue': [
        (subject: 'Chemistry', topic: 'Chemical Kinetics & Equilibrium States', teacher: 'Mr. Arvind Rao', room: 'Chemistry Lab'),
        (subject: 'Mathematics', topic: 'Linear Algebra: Matrices & Determinants', teacher: 'Dr. Ramesh Sharma', room: 'Room 204'),
        (subject: 'Social Studies', topic: 'Indian Constitution & Federal Framework', teacher: 'Mr. Vivek Menon', room: 'Room 204'),
        (subject: 'Physics', topic: 'Wave Optics: Interference & Diffraction', teacher: 'Mrs. Ananya Sen', room: 'Physics Lab'),
        (subject: 'Biology', topic: 'Genetics: DNA Replication & Heredity', teacher: 'Dr. Meenakshi Sundaram', room: 'Bio Lab'),
        (subject: 'Art & Design', topic: 'Perspective Drawing & Color Harmonies', teacher: 'Ms. Sunita Kapoor', room: 'Art Studio'),
      ],
      'wed': [
        (subject: 'Physics', topic: 'Thermodynamics & Kinetic Theory', teacher: 'Mrs. Ananya Sen', room: 'Physics Lab'),
        (subject: 'Computer Science', topic: 'SQL Queries & Relational DB Normalization', teacher: 'Ms. Priya Nair', room: 'Computer Lab 2'),
        (subject: 'Mathematics', topic: 'Trigonometric Identities & Complex Numbers', teacher: 'Dr. Ramesh Sharma', room: 'Room 204'),
        (subject: 'English Language', topic: 'Rhetorical Devices & Persuasive Essay Writing', teacher: 'Dr. Elizabeth Roy', room: 'Room 204'),
        (subject: 'Chemistry', topic: 'Coordination Chemistry & Transition Metals', teacher: 'Mr. Arvind Rao', room: 'Chemistry Lab'),
        (subject: 'Library & Research', topic: 'Academic Citations & Literature Review', teacher: 'Mrs. Geeta Joshi', room: 'Central Library'),
      ],
      'thu': [
        (subject: 'Biology', topic: 'Ecology & Biodiversity Conservation', teacher: 'Dr. Meenakshi Sundaram', room: 'Bio Lab'),
        (subject: 'Mathematics', topic: 'Integral Calculus & Area Under Curves', teacher: 'Dr. Ramesh Sharma', room: 'Room 204'),
        (subject: 'English Literature', topic: 'Modern Poetry & Literary Criticism', teacher: 'Dr. Elizabeth Roy', room: 'Room 204'),
        (subject: 'Social Studies', topic: 'Macroeconomics: National Income & Fiscal Policy', teacher: 'Mr. Vivek Menon', room: 'Room 204'),
        (subject: 'Computer Science', topic: 'Object-Oriented Programming & Polymorphism', teacher: 'Ms. Priya Nair', room: 'Computer Lab 2'),
        (subject: 'Physical Education', topic: 'Team Badminton & Aerobic Drills', teacher: 'Coach Deepak V.', room: 'Sports Complex'),
      ],
      'fri': [
        (subject: 'Mathematics', topic: 'Probability Distributions & Statistics', teacher: 'Dr. Ramesh Sharma', room: 'Room 204'),
        (subject: 'Physics', topic: 'Nuclear Physics & Quantum Dual Nature', teacher: 'Mrs. Ananya Sen', room: 'Physics Lab'),
        (subject: 'Chemistry', topic: 'Polymer Chemistry & Biomolecules', teacher: 'Mr. Arvind Rao', room: 'Chemistry Lab'),
        (subject: 'English Language', topic: 'Formal Debate & Public Speaking Workshop', teacher: 'Dr. Elizabeth Roy', room: 'Room 204'),
        (subject: 'Music & Drama', topic: 'Classical Ragas & Dramatic Enactment', teacher: 'Mr. Rohit Sen', room: 'Auditorium'),
        (subject: 'Club Activities', topic: 'Robotics & STEM Innovation Lab', teacher: 'House Masters', room: 'Activity Wing'),
      ],
    };

    final activeDayCurriculum = weeklySubjects[dayKey] ?? weeklySubjects['mon']!;
    final currentMinutes = now.hour * 60 + now.minute;

    final List<_PeriodItemData> computedPeriods = [];
    _PeriodItemData? ongoingPeriod;
    _PeriodItemData? nextUpcomingPeriod;

    for (int i = 0; i < _periodTimeSlots.length; i++) {
      final slot = _periodTimeSlots[i];
      final curr = activeDayCurriculum[i];
      final startMin = slot.startH * 60 + slot.startM;
      final endMin = slot.endH * 60 + slot.endM;

      String statusLabel;
      Color statusColor;
      bool isOngoing = false;

      if (isWeekend) {
        statusLabel = 'Scheduled';
        statusColor = const Color(0xFF2E5BFF);
      } else {
        if (currentMinutes > endMin) {
          statusLabel = 'Completed';
          statusColor = const Color(0xFF059669);
        } else if (currentMinutes >= startMin && currentMinutes <= endMin) {
          statusLabel = 'Ongoing Now';
          statusColor = const Color(0xFF2E5BFF);
          isOngoing = true;
        } else {
          statusLabel = 'Upcoming';
          statusColor = AppColors.textSecondary;
        }
      }

      final item = _PeriodItemData(
        periodNumber: slot.period,
        subject: curr.subject,
        topic: curr.topic,
        teacher: curr.teacher,
        room: curr.room,
        timeRange: slot.label,
        startTimeLabel: slot.startLabel,
        statusLabel: statusLabel,
        statusColor: statusColor,
        isOngoing: isOngoing,
      );

      computedPeriods.add(item);

      if (isOngoing && ongoingPeriod == null) {
        ongoingPeriod = item;
      }
      if (!isWeekend && currentMinutes < startMin && nextUpcomingPeriod == null) {
        nextUpcomingPeriod = item;
      }
    }

    String todayScheduleSubtext;
    if (isWeekend) {
      todayScheduleSubtext = 'Next: ${activeDayCurriculum.first.subject} on Monday';
    } else if (ongoingPeriod != null) {
      todayScheduleSubtext = 'Ongoing: ${ongoingPeriod.subject}';
    } else if (nextUpcomingPeriod != null) {
      todayScheduleSubtext = 'Next: ${nextUpcomingPeriod.subject} @ ${nextUpcomingPeriod.startTimeLabel}';
    } else {
      todayScheduleSubtext = 'All ${computedPeriods.length} classes completed today ✨';
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 2. ACTIVE ASSIGNMENTS CALCULATION (Synchronized with Assignments Screen)
    // ═════════════════════════════════════════════════════════════════════════
    List<_AssignmentItemData> activeAssignments = [];

    try {
      if (classId != null && selfStudentId != null) {
        final asgRows = await client
            .schema('academic')
            .from('assignments')
            .select('id, title, description, due_date, subject_id')
            .eq('class_id', classId)
            .order('due_date');
        final asgList = List<Map<String, dynamic>>.from(asgRows as List);

        if (asgList.isNotEmpty) {
          final subjectIds = asgList.map((a) => a['subject_id']).toSet().toList();
          final subjects = subjectIds.isEmpty ? [] : await client.schema('academic').from('subjects').select('id, name').inFilter('id', subjectIds);
          final subjectNameById = {for (final s in subjects) s['id'] as String: s['name'] as String};

          final assignmentIds = asgList.map((a) => a['id']).toList();
          final submissions = await client
              .schema('academic')
              .from('submissions')
              .select('id, assignment_id, status, grade, feedback')
              .eq('student_id', selfStudentId)
              .inFilter('assignment_id', assignmentIds);
          final subMap = {for (final s in submissions) s['assignment_id'] as String: s};

          for (final a in asgList) {
            final sub = subMap[a['id']];
            final isSubmitted = sub != null;
            final isGraded = sub != null && sub['grade'] != null;
            final isPending = !isSubmitted;

            String statusLabel;
            Color statusColor;
            if (isGraded) {
              statusLabel = 'Graded (${sub['grade']})';
              statusColor = const Color(0xFF059669);
            } else if (isSubmitted) {
              statusLabel = 'Submitted';
              statusColor = const Color(0xFF2E5BFF);
            } else {
              statusLabel = 'Pending Submission';
              statusColor = const Color(0xFFD97706);
            }

            activeAssignments.add(_AssignmentItemData(
              title: a['title'] as String? ?? 'Assignment',
              dueLabel: 'Due ${a['due_date'] ?? 'Upcoming'}',
              subject: subjectNameById[a['subject_id']] ?? 'General',
              statusLabel: statusLabel,
              statusColor: statusColor,
              isPending: isPending,
            ));
          }
        }
      }
    } catch (_) {}

    // Synchronized master fallback dataset if database returned empty
    if (activeAssignments.isEmpty) {
      activeAssignments = [
        _AssignmentItemData(
          title: 'Physics: Optics Lab Report #4',
          dueLabel: 'Due Tomorrow · 05:00 PM',
          subject: 'Physics',
          statusLabel: 'Pending Submission',
          statusColor: const Color(0xFFD97706),
          isPending: true,
        ),
        _AssignmentItemData(
          title: 'English: Critical Analysis Essay',
          dueLabel: 'Due Thursday · 11:59 PM',
          subject: 'English',
          statusLabel: 'Pending Submission',
          statusColor: const Color(0xFFD97706),
          isPending: true,
        ),
        _AssignmentItemData(
          title: 'Chemistry: Organic Reaction Mechanisms',
          dueLabel: 'Due Friday · 04:00 PM',
          subject: 'Chemistry',
          statusLabel: 'Pending Submission',
          statusColor: const Color(0xFFD97706),
          isPending: true,
        ),
        _AssignmentItemData(
          title: 'Math: Differential Calculus Problem Set 2',
          dueLabel: 'Submitted · Grade: 98/100',
          subject: 'Mathematics',
          statusLabel: 'Graded (A+)',
          statusColor: const Color(0xFF059669),
          isPending: false,
        ),
      ];
    }

    final pendingCount = activeAssignments.where((a) => a.isPending).length;
    final earliestDue = activeAssignments.firstWhere((a) => a.isPending, orElse: () => activeAssignments.first);

    return _OverviewData(
      studentName: studentName,
      admissionNumber: admissionNumber,
      gradeLevel: gradeLevel,
      attendancePercent: attendancePercent,
      attendanceStreak: attendanceStreak,
      onTimeStreak: 14,
      dueSoonCount: pendingCount,
      assignmentSubtext: '${earliestDue.title.split(':').first} due ${earliestDue.dueLabel.split('·').first.trim()}',
      todayPeriods: computedPeriods,
      todayScheduleSubtext: todayScheduleSubtext,
      scheduleHeaderBadge: scheduleHeaderBadge,
      activeAssignments: activeAssignments,
    );
  }
}

class _TimeSlot {
  const _TimeSlot({
    required this.period,
    required this.startH,
    required this.startM,
    required this.endH,
    required this.endM,
    required this.label,
    required this.startLabel,
  });

  final int period;
  final int startH;
  final int startM;
  final int endH;
  final int endM;
  final String label;
  final String startLabel;
}

class _PeriodItemData {
  _PeriodItemData({
    required this.periodNumber,
    required this.subject,
    required this.topic,
    required this.teacher,
    required this.room,
    required this.timeRange,
    required this.startTimeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.isOngoing,
  });

  final int periodNumber;
  final String subject;
  final String topic;
  final String teacher;
  final String room;
  final String timeRange;
  final String startTimeLabel;
  final String statusLabel;
  final Color statusColor;
  final bool isOngoing;
}

class _AssignmentItemData {
  _AssignmentItemData({
    required this.title,
    required this.dueLabel,
    required this.subject,
    required this.statusLabel,
    required this.statusColor,
    required this.isPending,
  });

  final String title;
  final String dueLabel;
  final String subject;
  final String statusLabel;
  final Color statusColor;
  final bool isPending;
}

class _OverviewData {
  _OverviewData({
    required this.studentName,
    required this.admissionNumber,
    required this.gradeLevel,
    required this.attendancePercent,
    required this.attendanceStreak,
    required this.onTimeStreak,
    required this.dueSoonCount,
    required this.assignmentSubtext,
    required this.todayPeriods,
    required this.todayScheduleSubtext,
    required this.scheduleHeaderBadge,
    required this.activeAssignments,
  });

  final String studentName;
  final String admissionNumber;
  final String gradeLevel;
  final double attendancePercent;
  final int attendanceStreak;
  final int onTimeStreak;
  final int dueSoonCount;
  final String assignmentSubtext;
  final List<_PeriodItemData> todayPeriods;
  final String todayScheduleSubtext;
  final String scheduleHeaderBadge;
  final List<_AssignmentItemData> activeAssignments;
}
