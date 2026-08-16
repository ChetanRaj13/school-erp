import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/self_children_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/line_chart.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import 'providers/parent_providers.dart';

enum _ParentSection { overview, reportCard }

class ParentOverviewScreen extends ConsumerStatefulWidget {
  const ParentOverviewScreen({super.key});

  @override
  ConsumerState<ParentOverviewScreen> createState() => _ParentOverviewScreenState();
}

class _ParentOverviewScreenState extends ConsumerState<ParentOverviewScreen> {
  String? _selectedStudentId;
  _ParentSection _currentSection = _ParentSection.overview;
  String? _selectedReportSubjectId;

  static const _parentAccent = Color(0xFFFF6B9D);
  static const _parentAccentSoft = Color(0xFFFFE8F0);

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(selfChildrenProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: childrenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _parentAccent)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (children) {
              if (children.isEmpty) {
                return const Center(child: Text('No children linked to your account yet.'));
              }
              final selected = children.firstWhere(
                (c) => c.studentId == _selectedStudentId,
                orElse: () => children.first,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header & Child Selector ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Parent Profile',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Monitoring ${selected.fullName}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _parentAccentSoft,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(color: _parentAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.family_restroom_rounded, size: 16, color: _parentAccent),
                              const SizedBox(width: 6),
                              Text(
                                '${children.length} ${children.length == 1 ? "Child" : "Children"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _parentAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Child Switcher Tabs (if multiple children)
                  if (children.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: children.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final c = children[i];
                            final isSelected = c.studentId == selected.studentId;
                            return InkWell(
                              onTap: () => setState(() {
                                _selectedStudentId = c.studentId;
                                _selectedReportSubjectId = null;
                              }),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? _parentAccent : AppColors.glassFill,
                                  borderRadius: BorderRadius.circular(AppRadii.pill),
                                  border: Border.all(
                                    color: isSelected ? _parentAccent : AppColors.glassBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: isSelected ? Colors.white : _parentAccentSoft,
                                      child: Text(
                                        c.fullName.isNotEmpty ? c.fullName[0] : 'S',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? _parentAccent : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      c.fullName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Section Segmented Switcher (Overview vs Full Report Card)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: SegmentedButton<_ParentSection>(
                      segments: const [
                        ButtonSegment(
                          value: _ParentSection.overview,
                          icon: Icon(Icons.space_dashboard_outlined, size: 18),
                          label: Text('Overview'),
                        ),
                        ButtonSegment(
                          value: _ParentSection.reportCard,
                          icon: Icon(Icons.assessment_outlined, size: 18),
                          label: Text('Report Card'),
                        ),
                      ],
                      selected: {_currentSection},
                      onSelectionChanged: (set) => setState(() => _currentSection = set.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: _parentAccentSoft,
                        selectedForegroundColor: _parentAccent,
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                      ),
                    ),
                  ),

                  // ── Content Area ──
                  Expanded(
                    child: _currentSection == _ParentSection.overview
                        ? _buildOverviewSection(selected)
                        : _buildReportCardSection(selected),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. OVERVIEW SUBSECTION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOverviewSection(LinkedChild selected) {
    final perfAsync = ref.watch(childPerformanceProvider(selected.studentId));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: perfAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: _parentAccent),
          ),
        ),
        error: (e, _) => Center(child: Text('Failed to load performance: $e')),
        data: (perf) {
          final avgMarks = perf.avgMarksPercent;
          final avgColor = avgMarks == null
              ? AppColors.textSecondary
              : avgMarks >= 80
                  ? const Color(0xFF00877D)
                  : avgMarks >= 65
                      ? AppColors.primary
                      : AppColors.warning;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Child Identity Badge Card
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: _parentAccentSoft,
                      child: Text(
                        selected.fullName.isNotEmpty ? selected.fullName[0] : 'S',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _parentAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.fullName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Admission No: ${selected.admissionNumber}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _currentSection = _ParentSection.reportCard),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F9F5),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insights, size: 14, color: Color(0xFF00877D)),
                            SizedBox(width: 4),
                            Text(
                              'Report Card',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00877D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Metric Cards Row (Attendance Donut Chart & Average Marks)
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                      child: SizedBox(
                        height: 155,
                        child: Center(
                          child: ProgressRing(
                            value: perf.attendancePercent / 100,
                            centerLabel: '${perf.attendancePercent.toStringAsFixed(0)}%',
                            centerSubtitle: 'attendance',
                            size: 140,
                            strokeWidth: 14,
                            color: const Color(0xFF00D4AA),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        height: 155,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F9F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.school_outlined, size: 22, color: Color(0xFF00877D)),
                            ),
                            const Spacer(),
                            Text(
                              avgMarks != null ? '${avgMarks.toStringAsFixed(1)}%' : '—',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: avgColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Average Marks',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Assignment Completion GlassCard
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _parentAccentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment_turned_in_outlined, color: _parentAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assignments Progress', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            '${perf.submittedAssignments} of ${perf.totalAssignments} completed this term',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    GlassChip(
                      label: perf.totalAssignments > 0 && perf.submittedAssignments >= perf.totalAssignments
                          ? 'Up to Date'
                          : '${perf.totalAssignments - perf.submittedAssignments} Pending',
                      color: perf.totalAssignments > 0 && perf.submittedAssignments >= perf.totalAssignments
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Quick Links Section (High-Contrast, Clean & Accessible) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Links',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Text(
                    'Actions & Services',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _QuickLinkTile(
                icon: Icons.assessment_outlined,
                iconColor: const Color(0xFF00D4AA),
                iconBgColor: const Color(0xFFE6F9F5),
                label: 'Student Report Card',
                subtitle: 'Full academic analysis, marks table & trends',
                onTap: () => setState(() => _currentSection = _ParentSection.reportCard),
              ),
              const SizedBox(height: 10),
              _QuickLinkTile(
                icon: Icons.calendar_today_outlined,
                iconColor: AppColors.primary,
                iconBgColor: const Color(0xFFEBF1FF),
                label: 'Timetable & Schedule',
                subtitle: 'Daily period breakdown & teachers',
                onTap: () => context.go('/parent/schedule'),
              ),
              const SizedBox(height: 10),
              _QuickLinkTile(
                icon: Icons.payments_outlined,
                iconColor: _parentAccent,
                iconBgColor: _parentAccentSoft,
                label: 'Fees & Invoices',
                subtitle: 'Pay fees, view breakdown & download receipts',
                onTap: () => context.go('/parent/fees'),
              ),
              const SizedBox(height: 10),
              _QuickLinkTile(
                icon: Icons.notifications_outlined,
                iconColor: const Color(0xFFFF6B47),
                iconBgColor: const Color(0xFFFFECE6),
                label: 'Notifications',
                subtitle: 'Absence alerts, payment receipts & updates',
                onTap: () => context.go('/parent/notifications'),
              ),
              const SizedBox(height: 10),
              _QuickLinkTile(
                icon: Icons.campaign_outlined,
                iconColor: const Color(0xFFFFC700),
                iconBgColor: const Color(0xFFFFF9E6),
                label: 'School Announcements',
                subtitle: 'Circulars, events & exam schedules',
                onTap: () => context.go('/parent/announcements'),
              ),
              const SizedBox(height: 10),
              _QuickLinkTile(
                icon: Icons.mail_outline,
                iconColor: AppColors.primary,
                iconBgColor: const Color(0xFFEBF1FF),
                label: 'Messages',
                subtitle: 'Direct communication with teachers & admin',
                onTap: () => context.go('/parent/messages'),
              ),
              const SizedBox(height: 10),
              _QuickLinkTile(
                icon: Icons.volunteer_activism_outlined,
                iconColor: _parentAccent,
                iconBgColor: _parentAccentSoft,
                label: 'Scholarships & Waivers',
                subtitle: 'Apply for merit scholarships & fee waivers',
                onTap: () => context.go('/parent/waivers'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. FULL STUDENT REPORT CARD SECTION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReportCardSection(LinkedChild selected) {
    final reportAsync = ref.watch(childReportCardProvider(selected.studentId));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: reportAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: _parentAccent),
          ),
        ),
        error: (e, _) => Center(child: Text('Failed to load report card: $e')),
        data: (rc) {
          final isDistinction = rc.overallPercentage >= 80;
          final standingColor = isDistinction
              ? const Color(0xFF00877D)
              : rc.overallPercentage >= 65
                  ? AppColors.primary
                  : AppColors.warning;

          final selectedSubject = rc.subjects.firstWhere(
            (s) => s.subjectId == _selectedReportSubjectId,
            orElse: () => rc.bestSubject ?? rc.subjects.first,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Overall Academic Performance Summary Card ──
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${rc.studentName}’s Report Card',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${rc.className} · Academic Year 2025-26',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: standingColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(color: standingColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 16, color: standingColor),
                              const SizedBox(width: 6),
                              Text(
                                'Grade ${rc.overallGrade}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: standingColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: AppColors.glassBorder, height: 1),
                    const SizedBox(height: 18),

                    // Key Performance Metrics Summary
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Overall Score', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                '${rc.overallPercentage}%',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: standingColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Passed Subjects', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                '${rc.passedSubjects} / ${rc.subjects.length}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Credits', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                '${rc.totalCredits}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Academic Standing Explanatory Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppRadii.input),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: standingColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rc.standingDescription,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Overall Performance Multi-Term Trajectory Chart ──
              if (rc.overallTrend.length >= 2) ...[
                SizedBox(
                  height: 195,
                  child: LineChart(
                    title: 'Overall Academic Performance Trend',
                    labels: rc.termLabels,
                    values: rc.overallTrend,
                    maxValue: 100.0,
                    chartColor: standingColor,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── 2. Best Subject & Areas Requiring More Work ──
              if (rc.bestSubject != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F9F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.star_rounded, size: 18, color: Color(0xFF00877D)),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Best Subject',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF00877D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              rc.bestSubject!.subjectName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${rc.bestSubject!.marksObtained} / ${rc.bestSubject!.maxMarks} (${rc.bestSubject!.percentage}%)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00877D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // ── 3. Subject-wise Marks Trend (Selectable & Visual) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subject-wise Marks Trend',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Icon(Icons.show_chart, color: AppColors.primary, size: 20),
                ],
              ),
              const SizedBox(height: 10),

              // Subject selection pills for chart
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rc.subjects.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final s = rc.subjects[i];
                    final isSel = s.subjectId == selectedSubject.subjectId;
                    return InkWell(
                      onTap: () => setState(() => _selectedReportSubjectId = s.subjectId),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF00877D) : AppColors.glassFill,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(
                            color: isSel ? const Color(0xFF00877D) : AppColors.glassBorder,
                          ),
                        ),
                        child: Text(
                          s.subjectName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Subject Trajectory Line Chart
              if (selectedSubject.termTrend.length >= 2) ...[
                SizedBox(
                  height: 190,
                  child: LineChart(
                    title: "${selectedSubject.subjectName} Trajectory (%)",
                    labels: selectedSubject.termLabels,
                    values: selectedSubject.termTrend,
                    maxValue: 100.0,
                    chartColor: const Color(0xFF00877D),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── 4. All Subject Marks Table ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Subject Marks Table',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  GlassChip(
                    label: '${rc.subjects.length} Subjects Evaluated',
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    // Table Header
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text('Subject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                          Expanded(flex: 3, child: Text('Marks', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                          Expanded(flex: 2, child: Text('Grade', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                          Expanded(flex: 3, child: Text('Class Avg', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.glassBorder, height: 1),

                    // Table Rows
                    ...rc.subjects.map((sub) {
                      final gradeColor = sub.percentage >= 85
                          ? const Color(0xFF00877D)
                          : sub.percentage >= 70
                              ? AppColors.primary
                              : sub.percentage >= 50
                                  ? AppColors.warning
                                  : AppColors.error;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sub.subjectName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundAlt,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(sub.subjectCode, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${sub.marksObtained} / ${sub.maxMarks}\n(${sub.percentage}%)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: gradeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                  ),
                                  child: Text(
                                    sub.gradeLetter,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: gradeColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${sub.classAverage}%',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── 5. Areas Requiring More Work (Concise Insights & Guidance) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Areas Requiring More Work',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFF6B47),
                        ),
                  ),
                  const Icon(Icons.lightbulb_outline, color: Color(0xFFFF6B47), size: 20),
                ],
              ),
              const SizedBox(height: 12),

              if (rc.areasNeedingWork.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F9F5),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF00877D), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No critical areas flagged! Performance is consistently solid across all registered subjects.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF00877D)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...rc.areasNeedingWork.map((area) {
                  final isHigh = area.urgency == 'high';
                  final badgeColor = isHigh ? AppColors.error : const Color(0xFFFF6B47);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                area.subjectName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              GlassChip(
                                label: '${area.currentScore}% — ${isHigh ? "High Focus" : "Review"}',
                                color: badgeColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            area.issue,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECE6),
                              borderRadius: BorderRadius.circular(AppRadii.input),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFFF6B47)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    area.recommendation,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9E361B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
