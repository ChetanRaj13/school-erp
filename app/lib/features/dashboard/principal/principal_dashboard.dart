import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bar_chart.dart';
import '../../../core/widgets/line_chart.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Principal front page (the shell sidebar's "Overview" item). Kept to genuinely
/// important-at-a-glance info only: the fee-collection ring, student/staff counts, and
/// timetable slot count. The ~14 operational quick links that used to live here as a
/// scrolling list have moved into the persistent sidebar (see nav_config.dart +
/// role_shell.dart) — this page no longer duplicates them.
class PrincipalDashboard extends ConsumerWidget {
  const PrincipalDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_PrincipalSummary>(
            future: _loadSummary(client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load dashboard: ${snapshot.error}'));
              }
              final s = snapshot.data!;
              final collectedRatio = s.amountDue == 0 ? 0.0 : (s.amountPaid / s.amountDue).clamp(0.0, 1.0);

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good morning', style: Theme.of(context).textTheme.bodyMedium),
                          Text('Principal Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        GlassCard(
                          child: Row(
                            children: [
                              ProgressRing(value: collectedRatio, centerLabel: '${(collectedRatio * 100).toStringAsFixed(0)}%', centerSubtitle: 'collected'),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.eco_outlined, color: AppColors.primary, size: 18),
                                        const SizedBox(width: 6),
                                        Text('Fee Collection', style: Theme.of(context).textTheme.titleMedium),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text('₹${s.amountPaid.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineMedium),
                                    Text('of ₹${s.amountDue.toStringAsFixed(0)} due', style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _StatGlassCard(icon: Icons.groups_outlined, label: 'Students', value: '${s.studentCount}')),
                            const SizedBox(width: 12),
                            Expanded(child: _StatGlassCard(icon: Icons.badge_outlined, label: 'Staff', value: '${s.staffCount}')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _StatGlassCard(icon: Icons.calendar_month_outlined, label: 'Timetable Slots', value: '${s.timetableCount}', subtitle: 'reviewed & live', wide: true),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Use the sidebar to reach finance, operations, and communication tools.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Insights Section ──
                        Text('Insights', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),

                        // At-Risk Students summary
                        if (s.atRiskStudents.isNotEmpty) ...[
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${s.atRiskStudents.where((r) => r.riskLevel == 'high').length} students flagged high-risk',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${s.atRiskStudents.length} total at-risk students (attendance < 85% or marks below threshold)',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                ...s.atRiskStudents.take(5).map((r) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(r.fullName, style: Theme.of(context).textTheme.bodyMedium),
                                          ),
                                          _RiskBadge(level: r.riskLevel),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${r.attendancePct.toStringAsFixed(0)}% att / ${r.avgMarks.toStringAsFixed(0)} avg',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    )),
                                if (s.atRiskStudents.length > 5)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '+${s.atRiskStudents.length - 5} more — see full list in Analytics',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Attendance-Grade Correlation
                        if (s.corrChronicAvg != null && s.corrNonChronicAvg != null)
                          GlassCard(
                            child: Row(
                              children: [
                                Icon(Icons.insights_outlined, color: AppColors.primary, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Attendance ↔ Performance', style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Students with attendance below 85% average '
                                        '${s.corrChronicAvg!.toStringAsFixed(0)} marks, vs '
                                        '${s.corrNonChronicAvg!.toStringAsFixed(0)} for others.',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Grade Trend chart
                        if (s.gradeTrendValues.isNotEmpty)
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              values: s.gradeTrendValues,
                              labels: s.gradeTrendLabels,
                              title: 'School-Wide Grade Trend',
                              chartColor: AppColors.primary,
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Admission Trend chart
                        if (s.admissionTrend.isNotEmpty)
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              data: {for (final a in s.admissionTrend) '${a.year}': a.admissions.toDouble()},
                              title: 'Admissions by Year',
                              showValues: true,
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Cohort Comparison
                        if (s.cohortComparison.isNotEmpty) ...[
                          GlassCard(
                            padding: const EdgeInsets.all(0),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 16,
                                headingRowColor: WidgetStateProperty.all(AppColors.glassBorder),
                                columns: const [
                                  DataColumn(label: Text('Year')),
                                  DataColumn(label: Text('Section')),
                                  DataColumn(label: Text('Avg Marks'), numeric: true),
                                ],
                                rows: s.cohortComparison.map((c) => DataRow(
                                  cells: [
                                    DataCell(Text(c.academicYear)),
                                    DataCell(Text(c.section)),
                                    DataCell(Text(c.avgMarks.toStringAsFixed(1))),
                                  ],
                                )).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
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

  Future<_PrincipalSummary> _loadSummary(SupabaseClient client) async {
    final students = await client.schema('public').from('students').select('id');
    final staff = await client.schema('public').from('staff').select('id');
    final invoices = await client.schema('finance').from('invoices').select('amount_due, amount_paid');
    final timetable = await client.schema('scheduling').from('timetable').select('id');
    double due = 0, paid = 0;
    for (final row in invoices) {
      due += (row['amount_due'] as num).toDouble();
      paid += (row['amount_paid'] as num).toDouble();
    }

    // ── Grade trend (school-wide) ──
    List<double> gradeTrendValues = [];
    List<String> gradeTrendLabels = [];
    try {
      final res = await client.schema('analytics').rpc('get_grade_trend');
      final list = List<Map<String, dynamic>>.from(res as List);
      for (final r in list) {
        gradeTrendValues.add((r['avg_marks'] as num?)?.toDouble() ?? 0);
        final year = (r['academic_year'] as String?) ?? '';
        final term = (r['term'] as String?) ?? '';
        gradeTrendLabels.add('$year $term'.trim());
      }
    } catch (_) {}

    // ── At-risk students (school-wide) ──
    List<_AtRiskStudent> atRiskStudents = [];
    try {
      final res = await client.schema('analytics').rpc('get_at_risk_students');
      final list = List<Map<String, dynamic>>.from(res as List);
      atRiskStudents = list.map((r) => _AtRiskStudent(
        studentId: (r['student_id'] as String?) ?? '',
        fullName: (r['full_name'] as String?) ?? 'Unknown',
        attendancePct: (r['attendance_pct'] as num?)?.toDouble() ?? 0,
        avgMarks: (r['avg_marks'] as num?)?.toDouble() ?? 0,
        riskLevel: (r['risk_level'] as String?) ?? 'low',
      )).toList();
    } catch (_) {}

    // ── Attendance-grade correlation (school-wide) ──
    double? corrChronicAvg;
    double? corrNonChronicAvg;
    try {
      final res = await client.schema('analytics').rpc('get_attendance_grade_correlation');
      final list = List<Map<String, dynamic>>.from(res as List);
      for (final r in list) {
        final isChronic = r['is_chronic'] as bool? ?? false;
        final avgMarks = (r['avg_marks'] as num?)?.toDouble();
        if (isChronic) {
          corrChronicAvg = avgMarks;
        } else {
          corrNonChronicAvg = avgMarks;
        }
      }
    } catch (_) {}

    // ── Cohort comparison (school-wide) ──
    List<_CohortRow> cohortComparison = [];
    try {
      final res = await client.schema('analytics').rpc('get_cohort_comparison');
      final list = List<Map<String, dynamic>>.from(res as List);
      cohortComparison = list.map((r) => _CohortRow(
        academicYear: (r['academic_year'] as String?) ?? '',
        section: (r['section'] as String?) ?? '',
        avgMarks: (r['avg_marks'] as num?)?.toDouble() ?? 0,
      )).toList();
    } catch (_) {}

    // ── Admission trend (school-wide) ──
    List<_AdmissionTrendPoint> admissionTrend = [];
    try {
      final res = await client.schema('analytics').rpc('get_admission_trend');
      final list = List<Map<String, dynamic>>.from(res as List);
      admissionTrend = list.map((r) => _AdmissionTrendPoint(
        year: (r['year'] as num?)?.toInt() ?? 0,
        admissions: (r['admissions'] as num?)?.toInt() ?? 0,
      )).toList();
    } catch (_) {}

    return _PrincipalSummary(
      studentCount: students.length,
      staffCount: staff.length,
      amountDue: due,
      amountPaid: paid,
      timetableCount: timetable.length,
      gradeTrendValues: gradeTrendValues,
      gradeTrendLabels: gradeTrendLabels,
      atRiskStudents: atRiskStudents,
      corrChronicAvg: corrChronicAvg,
      corrNonChronicAvg: corrNonChronicAvg,
      cohortComparison: cohortComparison,
      admissionTrend: admissionTrend,
    );
  }
}

class _PrincipalSummary {
  _PrincipalSummary({
    required this.studentCount,
    required this.staffCount,
    required this.amountDue,
    required this.amountPaid,
    required this.timetableCount,
    required this.gradeTrendValues,
    required this.gradeTrendLabels,
    required this.atRiskStudents,
    this.corrChronicAvg,
    this.corrNonChronicAvg,
    required this.cohortComparison,
    required this.admissionTrend,
  });
  final int studentCount;
  final int staffCount;
  final double amountDue;
  final double amountPaid;
  final int timetableCount;
  final List<double> gradeTrendValues;
  final List<String> gradeTrendLabels;
  final List<_AtRiskStudent> atRiskStudents;
  final double? corrChronicAvg;
  final double? corrNonChronicAvg;
  final List<_CohortRow> cohortComparison;
  final List<_AdmissionTrendPoint> admissionTrend;
}

class _AtRiskStudent {
  const _AtRiskStudent({required this.studentId, required this.fullName, required this.attendancePct, required this.avgMarks, required this.riskLevel});
  final String studentId;
  final String fullName;
  final double attendancePct;
  final double avgMarks;
  final String riskLevel;
}

class _CohortRow {
  const _CohortRow({required this.academicYear, required this.section, required this.avgMarks});
  final String academicYear;
  final String section;
  final double avgMarks;
}

class _AdmissionTrendPoint {
  const _AdmissionTrendPoint({required this.year, required this.admissions});
  final int year;
  final int admissions;
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.level});
  final String level;

  @override
  Widget build(BuildContext context) {
    final color = level == 'high' ? AppColors.error : level == 'medium' ? AppColors.warning : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level[0].toUpperCase() + level.substring(1),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _StatGlassCard extends StatelessWidget {
  const _StatGlassCard({required this.icon, required this.label, required this.value, this.subtitle, this.wide = false});
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: wide
          ? Row(children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  Text(value, style: Theme.of(context).textTheme.headlineMedium),
                ]),
              ),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(height: 10),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ]),
    );
  }
}
