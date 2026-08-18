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
  String _selectedReportTerm = 'all'; // 'all', 'term1', 'midterm', 'term2'

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
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      child: SizedBox(
                        height: 155,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Header Row: Icon + Title + Grade Pill
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F9F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.school_rounded, size: 18, color: Color(0xFF00877D)),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Average Marks',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (avgMarks != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: avgColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(AppRadii.pill),
                                      border: Border.all(color: avgColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      avgMarks >= 90
                                          ? 'A+'
                                          : avgMarks >= 80
                                              ? 'A'
                                              : avgMarks >= 70
                                                  ? 'B'
                                                  : avgMarks >= 60
                                                      ? 'C'
                                                      : 'D',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: avgColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Main Score Display (Prominent Size)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  avgMarks != null ? avgMarks.toStringAsFixed(1) : '—',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: avgColor,
                                    height: 1.0,
                                    letterSpacing: -1,
                                  ),
                                ),
                                if (avgMarks != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 2),
                                    child: Text(
                                      '%',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: avgColor.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Bottom Subtitle / Trajectory Status
                            Row(
                              children: [
                                Icon(
                                  avgMarks != null && avgMarks >= 75 ? Icons.trending_up : Icons.assessment_outlined,
                                  size: 14,
                                  color: avgColor,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    avgMarks == null
                                        ? 'Pending evaluation'
                                        : avgMarks >= 80
                                            ? 'Distinction • All Terms'
                                            : avgMarks >= 65
                                                ? 'Good Standing • All Terms'
                                                : 'Attention Needed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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

              // ── Active EMI Plan & Fees Quick Highlight ──
              Consumer(
                builder: (context, ref, _) {
                  final summaryAsync = ref.watch(childSummaryProvider(selected.studentId));
                  return summaryAsync.maybeWhen(
                    data: (summary) {
                      final activePlan = summary.activeEmiPlan;
                      final pendingInsts = summary.nextPendingInstallments;
                      final hasPendingFee = summary.amountDue > summary.amountPaid;

                      if (activePlan != null) {
                        final monthlyAmt = (activePlan['installment_amount'] as num?)?.toDouble() ?? 0.0;
                        final totalInst = (activePlan['total_installments'] as num?)?.toInt() ?? 3;
                        final nextInst = pendingInsts.isNotEmpty ? pendingInsts.first : null;

                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F9F5),
                              borderRadius: BorderRadius.circular(AppRadii.card),
                              border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.4), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00D4AA).withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.shield_outlined, color: Color(0xFF00877D), size: 18),
                                        SizedBox(width: 6),
                                        Text('EMI Financing Active', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF00877D))),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00877D),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$totalInst Months Plan',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('₹${monthlyAmt.toStringAsFixed(0)} / mo', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF00877D))),
                                        if (nextInst != null)
                                          Text('Next: Installment #${nextInst['installment_number']} (Due: ${nextInst['due_date']})', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00877D),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      onPressed: () => context.go('/parent/fees'),
                                      child: const Text('Manage EMI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      } else if (hasPendingFee) {
                        final remaining = summary.amountDue - summary.amountPaid;
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECE6),
                              borderRadius: BorderRadius.circular(AppRadii.card),
                              border: Border.all(color: const Color(0xFFFF6B47).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Color(0xFFFF6B47), size: 20),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('₹${remaining.toStringAsFixed(0)} Fee Balance Due', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFD84315))),
                                        const Text('Apply for EMI or pay online', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B47),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => context.go('/parent/fees'),
                                  child: const Text('View & Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
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
          // 1. Determine term index
          final int? termIndex = _selectedReportTerm == 'term1'
              ? 0
              : _selectedReportTerm == 'midterm'
                  ? 1
                  : _selectedReportTerm == 'term2'
                      ? 2
                      : null; // 'all' is null (cumulative)

          // 2. Map subjects dynamically according to selected term
          final computedSubjects = rc.subjects.map((sub) {
            double termPct;
            if (termIndex != null) {
              if (sub.termTrend.length > termIndex) {
                termPct = sub.termTrend[termIndex];
              } else if (sub.termTrend.isNotEmpty) {
                termPct = sub.termTrend.last;
              } else {
                termPct = sub.percentage;
              }
            } else {
              termPct = sub.percentage;
            }

            final marksObt = double.parse((termPct * sub.maxMarks / 100).toStringAsFixed(1));

            String gradeLetter;
            if (termPct >= 90) {
              gradeLetter = 'A+';
            } else if (termPct >= 80) {
              gradeLetter = 'A';
            } else if (termPct >= 70) {
              gradeLetter = 'B';
            } else if (termPct >= 55) {
              gradeLetter = 'C';
            } else if (termPct >= 40) {
              gradeLetter = 'D';
            } else {
              gradeLetter = 'E';
            }

            return SubjectReportItem(
              subjectId: sub.subjectId,
              subjectName: sub.subjectName,
              subjectCode: sub.subjectCode,
              marksObtained: marksObt,
              maxMarks: sub.maxMarks,
              percentage: termPct,
              gradeLetter: gradeLetter,
              classAverage: sub.classAverage,
              termLabels: sub.termLabels,
              termTrend: sub.termTrend,
              status: sub.status,
            );
          }).toList();

          // Sort subjects by percentage descending for current term
          computedSubjects.sort((a, b) => b.percentage.compareTo(a.percentage));

          // Compute term-specific overall percentage & grade
          final double overallPct = computedSubjects.isNotEmpty
              ? double.parse((computedSubjects.map((s) => s.percentage).reduce((a, b) => a + b) / computedSubjects.length).toStringAsFixed(1))
              : rc.overallPercentage;

          final String overallGrade = overallPct >= 90
              ? 'A+'
              : overallPct >= 80
                  ? 'A'
                  : overallPct >= 70
                      ? 'B'
                      : overallPct >= 55
                          ? 'C'
                          : 'D';

          final isDistinction = overallPct >= 80;
          final standingColor = isDistinction
              ? const Color(0xFF00877D)
              : overallPct >= 65
                  ? AppColors.primary
                  : AppColors.warning;

          final bestSubject = computedSubjects.isNotEmpty ? computedSubjects.first : null;
          final passedCount = computedSubjects.where((s) => s.percentage >= 40).length;

          final selectedSubject = computedSubjects.firstWhere(
            (s) => s.subjectId == _selectedReportSubjectId,
            orElse: () => bestSubject ?? computedSubjects.first,
          );

          // Areas needing work for the selected term (< 75% or grade C/D/E)
          final areasNeedingWork = computedSubjects.where((s) => s.percentage < 75).map((s) {
            return AreaNeedingWork(
              subjectName: s.subjectName,
              currentScore: s.percentage,
              issue: 'Scored ${s.percentage}% (Grade ${s.gradeLetter}) in ${_getTermName(_selectedReportTerm)}.',
              recommendation: 'Target weekly revision and practice problem sets to reach class average of ${s.classAverage}%.',
              urgency: s.percentage < 60 ? 'high' : 'medium',
            );
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Past Terms Toggle Bar ──
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTermFilterChip('all', 'All Terms (Cumulative)'),
                      const SizedBox(width: 8),
                      _buildTermFilterChip('term1', 'Term 1 (Autumn)'),
                      const SizedBox(width: 8),
                      _buildTermFilterChip('midterm', 'Mid-Term Exam'),
                      const SizedBox(width: 8),
                      _buildTermFilterChip('term2', 'Term 2 (Spring)'),
                    ],
                  ),
                ),
              ),

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
                                _selectedReportTerm == 'all'
                                    ? '${rc.className} · Academic Year 2025-26 (Cumulative)'
                                    : _selectedReportTerm == 'term1'
                                        ? '${rc.className} · Term 1 (Autumn 2025)'
                                        : _selectedReportTerm == 'midterm'
                                            ? '${rc.className} · Mid-Term Assessment 2025-26'
                                            : '${rc.className} · Term 2 (Spring 2026)',
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
                                'Grade $overallGrade',
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
                              Text(
                                _selectedReportTerm == 'all' ? 'Cumulative Score' : '${_getTermName(_selectedReportTerm)} Score',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$overallPct%',
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
                                '$passedCount / ${computedSubjects.length}',
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
                              overallPct >= 80
                                  ? 'Outstanding academic standing! Consistently performing well above grade benchmark.'
                                  : overallPct >= 65
                                      ? 'Good academic standing with stable subject performance across the curriculum.'
                                      : 'Academic attention recommended to strengthen core subject concepts.',
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
              SizedBox(
                height: 195,
                child: LineChart(
                  title: 'Overall Academic Performance Trend',
                  labels: rc.termLabels.isNotEmpty ? rc.termLabels : const ['Term 1', 'Mid-Term', 'Term 2'],
                  values: rc.overallTrend.isNotEmpty ? rc.overallTrend : [rc.overallPercentage],
                  maxValue: 100.0,
                  chartColor: standingColor,
                ),
              ),
              const SizedBox(height: 24),

              // ── 2. Best Subject Card ──
              if (bestSubject != null) ...[
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
                                Text(
                                  _selectedReportTerm == 'all' ? 'Best Subject (Overall)' : 'Top Subject (${_getTermName(_selectedReportTerm)})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF00877D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              bestSubject.subjectName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${bestSubject.marksObtained} / ${bestSubject.maxMarks} (${bestSubject.percentage}%)',
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
                  itemCount: computedSubjects.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final s = computedSubjects[i];
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

              // Subject Trajectory Line Chart (Guaranteed Rendering for all subjects)
              SizedBox(
                height: 195,
                child: LineChart(
                  title: "${selectedSubject.subjectName} Trajectory Trend (%)",
                  labels: selectedSubject.termLabels.isNotEmpty
                      ? selectedSubject.termLabels
                      : const ['Term 1', 'Mid-Term', 'Term 2'],
                  values: selectedSubject.termTrend.isNotEmpty
                      ? selectedSubject.termTrend
                      : [selectedSubject.percentage],
                  maxValue: 100.0,
                  chartColor: const Color(0xFF00877D),
                ),
              ),
              const SizedBox(height: 10),

              // Subject Trajectory Term Badges
              Row(
                children: [
                  Expanded(
                    child: _buildTrajectoryPill(
                      'Term 1',
                      selectedSubject.termTrend.isNotEmpty ? '${selectedSubject.termTrend[0]}%' : '${selectedSubject.percentage}%',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTrajectoryPill(
                      'Mid-Term',
                      selectedSubject.termTrend.length > 1 ? '${selectedSubject.termTrend[1]}%' : '${selectedSubject.percentage}%',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTrajectoryPill(
                      'Term 2',
                      selectedSubject.termTrend.length > 2 ? '${selectedSubject.termTrend[2]}%' : '${selectedSubject.percentage}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 4. All Subject Marks Table ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedReportTerm == 'all' ? 'All Subject Marks Table (Cumulative)' : 'Subject Marks — ${_getTermName(_selectedReportTerm)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  GlassChip(
                    label: '${computedSubjects.length} Subjects Evaluated',
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
                    ...computedSubjects.map((sub) {
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

              if (areasNeedingWork.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F9F5),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: const Color(0xFF00D4AA).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF00877D), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No critical areas flagged for ${_getTermName(_selectedReportTerm)}! Performance is consistently solid across all subjects.',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF00877D)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...areasNeedingWork.map((area) {
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

  String _getTermName(String term) {
    switch (term) {
      case 'term1':
        return 'Term 1';
      case 'midterm':
        return 'Mid-Term Exam';
      case 'term2':
        return 'Term 2';
      default:
        return 'All Terms (Cumulative)';
    }
  }

  Widget _buildTermFilterChip(String key, String label) {
    final isSel = _selectedReportTerm == key;
    return InkWell(
      onTap: () => setState(() => _selectedReportTerm = key),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? _parentAccent : AppColors.glassFill,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isSel ? _parentAccent : AppColors.glassBorder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
            color: isSel ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTrajectoryPill(String term, String score) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Text(term, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(score, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF00877D))),
        ],
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
