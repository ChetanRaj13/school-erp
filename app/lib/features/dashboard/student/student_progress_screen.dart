import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/line_chart.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Student Grades & Academic Progress Screen.
///
/// Features:
/// 1. Subject Grades & Official Report Card (no overlapping graphics, clean cards, and faculty remarks).
/// 2. Holistic Conduct & Extra-Curricular Activities section (matching teacher profile).
/// 3. Grade & Academic Performance Analytics (term trajectories, strength radar, peer benchmarking).
/// 4. Attendance Analytics with interactive Student Leave Request application.
class StudentProgressScreen extends ConsumerStatefulWidget {
  const StudentProgressScreen({super.key});

  @override
  ConsumerState<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends ConsumerState<StudentProgressScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedAnalyticsSubject = 'Mathematics';

  static const _studentAccent = Color(0xFFFFC700); // Primary Yellow per design.md
  static const _studentAccentSoft = Color(0xFFFFF7D6);
  static const _primaryBlue = Color(0xFF2E5BFF);

  // Live submitted student leaves
  final List<Map<String, dynamic>> _leaveRequests = [
    {
      'type': 'Medical / Sick Leave',
      'dates': '11 Aug 2026 – 11 Aug 2026 (1 Day)',
      'reason': 'Viral fever and doctor-advised rest.',
      'status': 'Approved',
      'statusColor': Color(0xFF059669),
      'appliedOn': '10 Aug 2026',
    },
    {
      'type': 'Academic Olympiad',
      'dates': '24 Aug 2026 – 25 Aug 2026 (2 Days)',
      'reason': 'Selected for Inter-School State Science & Robotics Olympiad Finals.',
      'status': 'Pending Approval',
      'statusColor': Color(0xFFD97706),
      'appliedOn': '17 Aug 2026',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openLeaveRequestDialog() {
    String leaveType = 'Medical / Sick Leave';
    final reasonCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '2026-08-28');
    final endCtrl = TextEditingController(text: '2026-08-29');
    bool parentConsent = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.event_note_rounded, color: _primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Apply for Student Leave', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('Submit formal absence request to Class Teacher', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Leave Category *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: leaveType,
                    items: const [
                      DropdownMenuItem(value: 'Medical / Sick Leave', child: Text('Medical / Sick Leave')),
                      DropdownMenuItem(value: 'Family Event / Function', child: Text('Family Event / Function')),
                      DropdownMenuItem(value: 'Academic Olympiad', child: Text('Academic Olympiad / Competition')),
                      DropdownMenuItem(value: 'Other Personal Leave', child: Text('Other Personal Leave')),
                    ],
                    onChanged: (v) => setModalState(() => leaveType = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.input), borderSide: const BorderSide(color: AppColors.glassBorder)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('2. Duration / Date Range *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: startCtrl,
                          decoration: InputDecoration(
                            labelText: 'Start Date (YYYY-MM-DD)',
                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: _primaryBlue),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.input), borderSide: const BorderSide(color: AppColors.glassBorder)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: endCtrl,
                          decoration: InputDecoration(
                            labelText: 'End Date (YYYY-MM-DD)',
                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: _primaryBlue),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.input), borderSide: const BorderSide(color: AppColors.glassBorder)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text('3. Reason for Absence *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Provide brief details for school records & teacher notice...',
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.input), borderSide: const BorderSide(color: AppColors.glassBorder)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Checkbox(
                        value: parentConsent,
                        activeColor: _primaryBlue,
                        onChanged: (v) => setModalState(() => parentConsent = v ?? true),
                      ),
                      const Expanded(
                        child: Text(
                          'Parent / Guardian is informed and approves this absence request.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Submit Leave Request', style: TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () {
                final reason = reasonCtrl.text.trim().isEmpty ? 'Personal family commitment.' : reasonCtrl.text.trim();
                setState(() {
                  _leaveRequests.insert(0, {
                    'type': leaveType,
                    'dates': '${startCtrl.text.trim()} – ${endCtrl.text.trim()}',
                    'reason': reason,
                    'status': 'Pending Approval',
                    'statusColor': const Color(0xFFD97706),
                    'appliedOn': 'Today',
                  });
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Leave application submitted to Class Teacher for approval!'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_StudentAcademicData>(
            future: _loadAcademicData(ref, client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: _primaryBlue));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load academic progress: ${snapshot.error}'));
              }
              final data = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Grades & Academic Analytics',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                    border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                                  ),
                                  child: const Text('GPA: 9.1 / 10.0 (Grade A+)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF059669))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Term performance, subject-wise assessment breakdowns, holistic development & leave requests',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.event_note_rounded, size: 16),
                          label: const Text('Apply for Leave', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                          onPressed: _openLeaveRequestDialog,
                        ),
                      ],
                    ),
                  ),

                  // 2. Tab Navigation Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Report Card'),
                          Tab(icon: Icon(Icons.insights_rounded, size: 18), text: 'Grade Analytics'),
                          Tab(icon: Icon(Icons.event_available_rounded, size: 18), text: 'Attendance & Leaves'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Tab Content Area
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReportCardTab(data),
                        _buildGradeAnalyticsTab(data),
                        _buildAttendanceAnalyticsTab(data),
                      ],
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

  // ── Tab 1: Subject Grades, Report Card & Holistic Development ──
  Widget _buildReportCardTab(_StudentAcademicData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Pristine Executive Performance Banner (No overlapping graphics!)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Clean circular score container
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4), width: 3),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('89.4%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF059669), letterSpacing: -0.5)),
                      Text('GRADE A1', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFF059669))),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('Academic Performance Standing', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          SizedBox(width: 8),
                          Icon(Icons.verified_rounded, size: 18, color: Color(0xFF059669)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Class 10 · Section B · Term 1 Periodic Evaluation · Academic Year 2026-27', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      // 4 Mini Summary Metrics
                      Row(
                        children: [
                          _buildExecutiveChip('CGPA', '9.1 / 10.0', const Color(0xFF2E5BFF)),
                          const SizedBox(width: 10),
                          _buildExecutiveChip('Class Rank', 'Rank #2', const Color(0xFF059669)),
                          const SizedBox(width: 10),
                          _buildExecutiveChip('Attendance', '96.8%', const Color(0xFFD97706)),
                          const SizedBox(width: 10),
                          _buildExecutiveChip('Status', 'Distinction', const Color(0xFF9333EA)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Subject Cards Grid
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final sub = data.subjects[i];
              return _buildSubjectReportCard(sub);
            },
          ),
          const SizedBox(height: 16),

          // 3. Holistic Conduct, Co-Curriculars & Faculty Observations (Matching Teacher Profile!)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology_outlined, color: Color(0xFF00877D), size: 20),
                    SizedBox(width: 8),
                    Text('Holistic Development & Faculty Remarks', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 14),

                // Discipline & Conduct
                Row(
                  children: [
                    const Text('Discipline & General Conduct: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00877D).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: const Color(0xFF00877D).withValues(alpha: 0.3)),
                      ),
                      child: const Text('Exemplary (Grade A1)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF00877D))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Co-Curricular & Club Participations
                const Text('Co-Curricular & Club Participations:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '🤖 Robotics & AI Club (Lead Programmer)',
                    '🏆 Inter-School Science Olympiad (Gold Medalist)',
                    '🎤 School Debate Society (Speaker)',
                    '🏸 Badminton Junior Team (Vice Captain)',
                  ].map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.25)),
                    ),
                    child: Text(c, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                  )).toList(),
                ),
                const SizedBox(height: 16),

                // Work Habits & Social Skills
                const Text('Work Habits & Social Skills:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSkillPill('Leadership & Initiative', 'Grade A+'),
                    const SizedBox(width: 10),
                    _buildSkillPill('Peer Collaboration', 'Grade A+'),
                    const SizedBox(width: 10),
                    _buildSkillPill('Homework Punctuality', '100% On-Time'),
                  ],
                ),
                const SizedBox(height: 16),

                // Class Teacher & Principal Recommendation
                const Text('Class Teacher & Head Faculty Observation:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Text(
                    '"Aarav demonstrates extraordinary intellectual curiosity and exceptional problem-solving abilities in STEM disciplines. He shows admirable leadership during collaborative laboratory assignments and maintains a 100% on-time submission record."',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontStyle: FontStyle.italic, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildSkillPill(String skill, String rating) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(skill, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(rating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectReportCard(_SubjectScore sub) {
    final gradeColor = sub.scorePercent >= 90
        ? const Color(0xFF059669)
        : sub.scorePercent >= 80
            ? const Color(0xFF2E5BFF)
            : const Color(0xFFD97706);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.school_outlined, size: 20, color: gradeColor),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('Faculty: ${sub.teacher} · ${sub.credits} Credits', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${sub.scorePercent.toStringAsFixed(0)}% (${sub.gradeLetter})', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: gradeColor)),
                  const SizedBox(height: 2),
                  Text('${sub.marksObtained}/${sub.maxMarks} Marks', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const Divider(height: 22),

          // Assessment Breakdown Matrix
          Row(
            children: [
              _buildMiniScorePill('Periodic Test 1', '${sub.pt1Marks}/20'),
              const SizedBox(width: 8),
              _buildMiniScorePill('Mid-Term Exam', '${sub.midTermMarks}/80'),
              const SizedBox(width: 8),
              _buildMiniScorePill('Practical / Lab', '${sub.practicalMarks}/20'),
              const SizedBox(width: 8),
              _buildMiniScorePill('Assignments', '${sub.submittedAssignments}/${sub.totalAssignments} Done'),
            ],
          ),
          const SizedBox(height: 12),

          // Faculty Remarks
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadii.input),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF2E5BFF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sub.facultyRemark,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textPrimary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniScorePill(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: Grade & Academic Performance Analytics ──
  Widget _buildGradeAnalyticsTab(_StudentAcademicData data) {
    // Find active subject for subject-wise trajectory
    final selectedSub = data.subjects.firstWhere(
      (s) => s.name == _selectedAnalyticsSubject,
      orElse: () => data.subjects.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Overall Term-by-Term Academic Trajectory (LineChart) ──
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.insights_rounded, size: 20, color: Color(0xFF2E5BFF)),
                        SizedBox(width: 8),
                        Text('Overall Academic Trajectory Trend', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up_rounded, size: 14, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('+5.2% Improvement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF059669))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: LineChart(
                    title: 'Multi-Term Overall Score Growth (%)',
                    labels: const ['Unit Test 1', 'Mid-Term Exam', 'Unit Test 2', 'Final Target'],
                    values: const [84.2, 87.5, 89.4, 95.0],
                    maxValue: 100.0,
                    chartColor: const Color(0xFF2E5BFF),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildTrajectoryMetricPill('Current Score', '89.4%', 'Grade A1 Distinction', const Color(0xFF059669)),
                    const SizedBox(width: 10),
                    _buildTrajectoryMetricPill('Term Growth', '+5.2%', 'Consistent Gain', const Color(0xFF2E5BFF)),
                    const SizedBox(width: 10),
                    _buildTrajectoryMetricPill('Class Highest', '92.4%', 'Gap: 3.0%', const Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    _buildTrajectoryMetricPill('Target Goal', '95.0%', 'Expected Term 3', const Color(0xFF9333EA)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── 2. Subject-wise Marks Trend (Interactive Selector & LineChart) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.show_chart_rounded, size: 20, color: Color(0xFF2E5BFF)),
                  SizedBox(width: 8),
                  Text('Subject-wise Marks Trend & Analysis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
              GlassChip(
                label: '${data.subjects.length} Subjects Evaluated',
                color: const Color(0xFF2E5BFF),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subject Selection Pills
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.subjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = data.subjects[i];
                final isSel = s.name == selectedSub.name;
                return InkWell(
                  onTap: () => setState(() => _selectedAnalyticsSubject = s.name),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF2E5BFF) : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: isSel ? const Color(0xFF2E5BFF) : AppColors.glassBorder,
                      ),
                    ),
                    child: Text(
                      s.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Selected Subject Line Chart
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedSub.name} (${selectedSub.subjectCode})',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          'Faculty: ${selectedSub.teacher} · Class Avg: ${selectedSub.classAverage}%',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        '${selectedSub.scorePercent.toStringAsFixed(0)}% (${selectedSub.gradeLetter})',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 185,
                  child: LineChart(
                    title: '${selectedSub.name} Term-by-Term Trajectory (%)',
                    labels: selectedSub.termLabels,
                    values: selectedSub.termTrend,
                    maxValue: 100.0,
                    chartColor: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(selectedSub.termLabels.length, (idx) {
                    final term = selectedSub.termLabels[idx];
                    final val = selectedSub.termTrend[idx];
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: idx < selectedSub.termLabels.length - 1 ? 8 : 0),
                        child: _buildTrajectoryTermPill(term, '$val%'),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 3. Comparison with Class Average Matrix (Class Benchmark Analysis) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.compare_arrows_rounded, size: 20, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Text('Subject vs. Class Average Benchmark', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Exceeding in 6/6 Subjects', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
              ),
            ],
          ),
          const SizedBox(height: 10),

          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.subjects.length,
              separatorBuilder: (_, __) => const Divider(height: 20, color: AppColors.glassBorder),
              itemBuilder: (context, i) {
                final sub = data.subjects[i];
                final delta = sub.scorePercent - sub.classAverage;
                final isAbove = delta >= 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundAlt,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(sub.subjectCode, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'You: ${sub.scorePercent.toStringAsFixed(0)}%',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF059669)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Class: ${sub.classAverage}%',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isAbove ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${isAbove ? '+' : ''}${delta.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isAbove ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Dual Progress Bar Gauge
                    Stack(
                      children: [
                        // Background Bar
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Student Score Bar
                        FractionallySizedBox(
                          widthFactor: (sub.scorePercent / 100.0).clamp(0.0, 1.0),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        // Class Average Indicator Marker
                        FractionallySizedBox(
                          widthFactor: (sub.classAverage / 100.0).clamp(0.0, 1.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 3,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade800,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── 4. Class-wise Grade Distribution & Percentile Standing ──
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 20, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Text('Class 10 Section B Performance Distribution', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your Percentile Standing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('94th Percentile · Rank #2 of 48', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: 0.94,
                      backgroundColor: Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 14),

                    // Tier Breakdown Pills
                    Row(
                      children: [
                        _buildTierPill('Distinction (≥85%)', '8 Students', 'You are here ✨', const Color(0xFF059669), true),
                        const SizedBox(width: 8),
                        _buildTierPill('First Class (70-84%)', '22 Students', 'Above Avg', const Color(0xFF2E5BFF), false),
                        const SizedBox(width: 8),
                        _buildTierPill('Second Class (50-69%)', '14 Students', 'Average', const Color(0xFFD97706), false),
                        const SizedBox(width: 8),
                        _buildTierPill('Passing (40-49%)', '4 Students', 'Support', AppColors.textSecondary, false),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── 5. Academic Strengths & Recommended Focus Areas ──
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.star_rounded, size: 20, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Text('Academic Strengths', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildBulletItem('Mathematics (96%): Exceptional algebraic reasoning and calculus fluency.'),
                      const SizedBox(height: 6),
                      _buildBulletItem('Physics (94%): High practical lab comprehension and formula accuracy.'),
                      const SizedBox(height: 6),
                      _buildBulletItem('Computer Science (92%): Clean Python algorithms and OOP logic structure.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.trending_up_rounded, size: 20, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Text('Recommended Focus Areas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildBulletItem('English Literature (82%): Strengthen formal essay structuring and thematic critique.'),
                      const SizedBox(height: 6),
                      _buildBulletItem('Social Studies (85%): Review timeline chronology for 20th century world history.'),
                      const SizedBox(height: 6),
                      _buildBulletItem('Weekly Review: Complete practice revision sets on weekend mornings.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrajectoryMetricPill(String label, String value, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildTrajectoryTermPill(String term, String score) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Text(term, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(score, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
        ],
      ),
    );
  }

  Widget _buildTierPill(String label, String count, String sub, Color color, bool highlighted) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlighted ? color.withValues(alpha: 0.15) : AppColors.backgroundAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: highlighted ? color : AppColors.glassBorder, width: highlighted ? 1.5 : 1.0),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: highlighted ? color : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: highlighted ? color : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.35, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  // ── Tab 3: Attendance Analytics & Student Leave Requests ──
  Widget _buildAttendanceAnalyticsTab(_StudentAcademicData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Attendance Executive Cards
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4), width: 2),
                        ),
                        child: const Center(
                          child: Text('96.8%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF059669))),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Regular Attendance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            SizedBox(height: 2),
                            Text('62 of 64 Working Days attended', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                            SizedBox(height: 4),
                            Text('2 Days Excused Medical Leave', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded, size: 22, color: Color(0xFFD97706)),
                          SizedBox(width: 6),
                          Text('Active Presence Streak', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('18 Consecutive Days', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFD97706))),
                      const SizedBox(height: 2),
                      const Text('Zero late arrivals logged this academic month', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Student Submitted Leave Requests Section
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
                        Icon(Icons.assignment_ind_outlined, size: 20, color: _primaryBlue),
                        SizedBox(width: 8),
                        Text('My Leave Applications & Absence Records', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('New Leave Application', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      onPressed: _openLeaveRequestDialog,
                    ),
                  ],
                ),
                const Divider(height: 20),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _leaveRequests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final leave = _leaveRequests[index];
                    final statusColor = leave['statusColor'] as Color;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadii.input),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.event_busy_rounded, size: 18, color: statusColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(leave['type'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.textPrimary)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(AppRadii.pill),
                                      ),
                                      child: Text(leave['status'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('Dates: ${leave['dates']} · Applied on ${leave['appliedOn']}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 3),
                                Text('Reason: ${leave['reason']}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Day of Week Distribution
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Day-of-Week Presence Analysis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildDayBar('Monday', '98%', 0.98),
                    const SizedBox(width: 10),
                    _buildDayBar('Tuesday', '100%', 1.00),
                    const SizedBox(width: 10),
                    _buildDayBar('Wednesday', '96%', 0.96),
                    const SizedBox(width: 10),
                    _buildDayBar('Thursday', '94%', 0.94),
                    const SizedBox(width: 10),
                    _buildDayBar('Friday', '96%', 0.96),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBar(String day, String rate, double val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Text(day, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(rate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF2E5BFF))),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: val,
              backgroundColor: Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E5BFF)),
              minHeight: 5,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<_StudentAcademicData> _loadAcademicData(WidgetRef ref, SupabaseClient client) async {
    final subjects = <_SubjectScore>[
      _SubjectScore(
        name: 'Mathematics',
        subjectCode: 'MATH-101',
        teacher: 'Dr. Ramesh Sharma',
        credits: 4,
        scorePercent: 96.0,
        classAverage: 78.2,
        gradeLetter: 'A1',
        marksObtained: 96,
        maxMarks: 100,
        pt1Marks: 20,
        midTermMarks: 76,
        practicalMarks: 20,
        submittedAssignments: 8,
        totalAssignments: 8,
        termLabels: const ['Unit Test 1', 'Mid-Term', 'Unit Test 2', 'Final Target'],
        termTrend: const [90.0, 94.0, 96.0, 98.0],
        facultyRemark: 'Demonstrates exceptional mastery of calculus and quadratic formulas. Solves advanced problem sets with precision.',
      ),
      _SubjectScore(
        name: 'Physics',
        subjectCode: 'PHY-102',
        teacher: 'Mrs. Ananya Sen',
        credits: 4,
        scorePercent: 94.0,
        classAverage: 75.5,
        gradeLetter: 'A1',
        marksObtained: 94,
        maxMarks: 100,
        pt1Marks: 19,
        midTermMarks: 75,
        practicalMarks: 20,
        submittedAssignments: 7,
        totalAssignments: 7,
        termLabels: const ['Unit Test 1', 'Mid-Term', 'Unit Test 2', 'Final Target'],
        termTrend: const [88.0, 91.0, 94.0, 97.0],
        facultyRemark: 'Consistently leads laboratory experiments. Clear conceptual grasp of ray optics and magnetic fields.',
      ),
      _SubjectScore(
        name: 'Chemistry',
        subjectCode: 'CHEM-103',
        teacher: 'Mr. Arvind Rao',
        credits: 4,
        scorePercent: 90.0,
        classAverage: 72.0,
        gradeLetter: 'A1',
        marksObtained: 90,
        maxMarks: 100,
        pt1Marks: 18,
        midTermMarks: 72,
        practicalMarks: 19,
        submittedAssignments: 6,
        totalAssignments: 6,
        termLabels: const ['Unit Test 1', 'Mid-Term', 'Unit Test 2', 'Final Target'],
        termTrend: const [84.0, 88.0, 90.0, 95.0],
        facultyRemark: 'Strong chemical equation balancing and stoichiometry skills. Active participant in lab sessions.',
      ),
      _SubjectScore(
        name: 'Computer Science',
        subjectCode: 'CS-104',
        teacher: 'Ms. Priya Nair',
        credits: 3,
        scorePercent: 92.0,
        classAverage: 80.4,
        gradeLetter: 'A1',
        marksObtained: 92,
        maxMarks: 100,
        pt1Marks: 19,
        midTermMarks: 73,
        practicalMarks: 20,
        submittedAssignments: 8,
        totalAssignments: 8,
        termLabels: const ['Unit Test 1', 'Mid-Term', 'Unit Test 2', 'Final Target'],
        termTrend: const [86.0, 90.0, 92.0, 96.0],
        facultyRemark: 'Solid grasp of Python programming, object-oriented concepts, and data structures.',
      ),
      _SubjectScore(
        name: 'English Literature',
        subjectCode: 'ENG-105',
        teacher: 'Dr. Elizabeth Roy',
        credits: 3,
        scorePercent: 82.0,
        classAverage: 76.0,
        gradeLetter: 'A2',
        marksObtained: 82,
        maxMarks: 100,
        pt1Marks: 16,
        midTermMarks: 66,
        practicalMarks: 18,
        submittedAssignments: 6,
        totalAssignments: 7,
        termLabels: const ['Unit Test 1', 'Mid-Term', 'Unit Test 2', 'Final Target'],
        termTrend: const [78.0, 80.0, 82.0, 90.0],
        facultyRemark: 'Thoughtful comprehension of texts. Encouraged to add more analytical depth to comparative essay prompts.',
      ),
      _SubjectScore(
        name: 'Social Studies',
        subjectCode: 'SOC-106',
        teacher: 'Mr. Vivek Menon',
        credits: 3,
        scorePercent: 85.0,
        classAverage: 74.5,
        gradeLetter: 'A2',
        marksObtained: 85,
        maxMarks: 100,
        pt1Marks: 17,
        midTermMarks: 68,
        practicalMarks: 18,
        submittedAssignments: 5,
        totalAssignments: 5,
        termLabels: const ['Unit Test 1', 'Mid-Term', 'Unit Test 2', 'Final Target'],
        termTrend: const [80.0, 83.0, 85.0, 92.0],
        facultyRemark: 'Very good grasp of geography maps and civic principles. Keep up the active classroom discussions.',
      ),
    ];

    return _StudentAcademicData(subjects: subjects);
  }
}

class _StudentAcademicData {
  _StudentAcademicData({required this.subjects});
  final List<_SubjectScore> subjects;
}

class _SubjectScore {
  _SubjectScore({
    required this.name,
    required this.subjectCode,
    required this.teacher,
    required this.credits,
    required this.scorePercent,
    required this.classAverage,
    required this.gradeLetter,
    required this.marksObtained,
    required this.maxMarks,
    required this.pt1Marks,
    required this.midTermMarks,
    required this.practicalMarks,
    required this.submittedAssignments,
    required this.totalAssignments,
    required this.termLabels,
    required this.termTrend,
    required this.facultyRemark,
  });

  final String name;
  final String subjectCode;
  final String teacher;
  final int credits;
  final double scorePercent;
  final double classAverage;
  final String gradeLetter;
  final int marksObtained;
  final int maxMarks;
  final int pt1Marks;
  final int midTermMarks;
  final int practicalMarks;
  final int submittedAssignments;
  final int totalAssignments;
  final List<String> termLabels;
  final List<double> termTrend;
  final String facultyRemark;
}
