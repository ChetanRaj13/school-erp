import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

enum _ScheduleViewMode { weeklyTable, dayTable }

class ParentScheduleScreen extends ConsumerStatefulWidget {
  const ParentScheduleScreen({super.key});

  @override
  ConsumerState<ParentScheduleScreen> createState() => _ParentScheduleScreenState();
}

class _ParentScheduleScreenState extends ConsumerState<ParentScheduleScreen> {
  String? _selectedStudentId;
  _ScheduleViewMode _viewMode = _ScheduleViewMode.weeklyTable;
  String _selectedDay = 'mon';

  static const _parentAccent = Color(0xFFFF6B9D);
  static const _parentAccentSoft = Color(0xFFFFE8F0);

  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri'];
  static const _dayFullNames = {
    'mon': 'Monday',
    'tue': 'Tuesday',
    'wed': 'Wednesday',
    'thu': 'Thursday',
    'fri': 'Friday',
  };

  static const _periodTimes = {
    1: '08:30 - 09:15',
    2: '09:15 - 10:00',
    3: '10:15 - 11:00',
    4: '11:00 - 11:45',
    5: '12:30 - 01:15',
    6: '01:15 - 02:00',
    7: '02:00 - 02:45',
    8: '02:45 - 03:30',
  };

  Color _getSubjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return const Color(0xFF4F46E5); // Indigo
    if (s.contains('phys') || s.contains('sci') || s.contains('chem') || s.contains('bio')) return const Color(0xFF00877D); // Teal
    if (s.contains('eng') || s.contains('lit') || s.contains('lang') || s.contains('hindi')) return const Color(0xFFFF6B9D); // Hot Pink
    if (s.contains('hist') || s.contains('soc') || s.contains('geo') || s.contains('civic')) return const Color(0xFFD97706); // Amber
    if (s.contains('cs') || s.contains('comp') || s.contains('code') || s.contains('it')) return const Color(0xFF0284C7); // Sky Blue
    if (s.contains('art') || s.contains('music') || s.contains('pe') || s.contains('sport') || s.contains('yoga')) return const Color(0xFF7C3AED); // Purple
    return const Color(0xFF00877D);
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(selfChildrenProvider);
    final client = ref.watch(supabaseClientProvider);

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
                  // Title & View Mode Switcher
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Class Timetable',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        SegmentedButton<_ScheduleViewMode>(
                          segments: const [
                            ButtonSegment(
                              value: _ScheduleViewMode.weeklyTable,
                              icon: Icon(Icons.table_chart_outlined, size: 16),
                              label: Text('Full Table', style: TextStyle(fontSize: 12)),
                            ),
                            ButtonSegment(
                              value: _ScheduleViewMode.dayTable,
                              icon: Icon(Icons.view_day_outlined, size: 16),
                              label: Text('Day View', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          selected: {_viewMode},
                          onSelectionChanged: (set) => setState(() => _viewMode = set.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: _parentAccentSoft,
                            selectedForegroundColor: _parentAccent,
                            foregroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Child Switcher Tabs (if multiple children)
                  if (children.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
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
                              onTap: () => setState(() => _selectedStudentId = c.studentId),
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
                                child: Text(
                                  c.fullName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Main Schedule Area
                  Expanded(
                    child: FutureBuilder<_ScheduleData>(
                      key: ValueKey('schedule-${selected.studentId}'),
                      future: _load(client, selected.studentId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator(color: _parentAccent));
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Failed to load: ${snapshot.error}'));
                        }
                        final data = snapshot.data!;
                        if (data.rows.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_busy, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'No timetable scheduled yet for ${selected.fullName}.',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        }

                        if (_viewMode == _ScheduleViewMode.weeklyTable) {
                          return _buildWeeklyTable(data);
                        } else {
                          return _buildDayTable(data);
                        }
                      },
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. FULL WEEKLY TIMETABLE TABLE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWeeklyTable(_ScheduleData data) {
    final periods = data.rows.map((r) => r['period_number'] as int).toSet().toList()..sort();

    // Map: period -> (day -> schedule entry)
    final Map<int, Map<String, Map<String, dynamic>>> grid = {};
    for (final p in periods) {
      grid[p] = {};
    }
    for (final row in data.rows) {
      final p = row['period_number'] as int;
      final d = (row['day'] as String).toLowerCase();
      grid[p]?[d] = row;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table Header Bar
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: _parentAccent),
                const SizedBox(width: 8),
                const Text(
                  'Weekly Schedule Matrix',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _parentAccentSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '${periods.length} Periods / Day',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _parentAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Horizontally scrollable table container expanding to 100% full card width
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 950 ? 950.0 : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Table(
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      columnWidths: const {
                        0: FixedColumnWidth(140), // Period Col
                        1: FlexColumnWidth(1),    // Mon
                        2: FlexColumnWidth(1),    // Tue
                        3: FlexColumnWidth(1),    // Wed
                        4: FlexColumnWidth(1),    // Thu
                        5: FlexColumnWidth(1),    // Fri
                      },
                      border: TableBorder.all(
                        color: AppColors.glassBorder.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        width: 1,
                      ),
                      children: [
                        // Header Row
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F4F6),
                          ),
                          children: [
                            _buildHeaderCell('Period / Time'),
                            ..._days.map((day) => _buildHeaderCell(_dayFullNames[day]!)),
                          ],
                        ),

                        // Data Rows (one per period)
                        ...periods.map((period) {
                          final timeLabel = _periodTimes[period] ?? 'Period $period';
                          return TableRow(
                            decoration: BoxDecoration(
                              color: period % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                            ),
                            children: [
                              // Period indicator cell
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _parentAccentSoft,
                                        borderRadius: BorderRadius.circular(AppRadii.pill),
                                      ),
                                      child: Text(
                                        'Period $period',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _parentAccent),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      timeLabel,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),

                              // Day cells
                              ..._days.map((day) {
                                final entry = grid[period]?[day];
                                if (entry == null) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '—',
                                      style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }

                                final subject = entry['subject_name'] as String;
                                final teacher = entry['teacher_name'] as String;
                                final subColor = _getSubjectColor(subject);

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: subColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: subColor.withValues(alpha: 0.28)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(color: subColor, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              subject,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: subColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              teacher,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. DAY-BY-DAY TABLE VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDayTable(_ScheduleData data) {
    final dayRows = data.rows.where((r) => (r['day'] as String).toLowerCase() == _selectedDay).toList()
      ..sort((a, b) => (a['period_number'] as int).compareTo(b['period_number'] as int));

    return Column(
      children: [
        // Day selector chips
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: _days.map((day) {
              final isSel = _selectedDay == day;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDay = day),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? _parentAccent : AppColors.glassFill,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          color: isSel ? _parentAccent : AppColors.glassBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _dayFullNames[day]!.substring(0, 3),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Day Schedule Table Card
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_dayFullNames[_selectedDay]} Schedule',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${dayRows.length} classes',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (dayRows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No classes scheduled on this day.', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    Table(
                      columnWidths: const {
                        0: FixedColumnWidth(90),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(2),
                      },
                      border: TableBorder.all(
                        color: AppColors.glassBorder.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
                          children: [
                            _buildHeaderCell('Period'),
                            _buildHeaderCell('Subject'),
                            _buildHeaderCell('Teacher'),
                          ],
                        ),
                        ...dayRows.map((row) {
                          final period = row['period_number'] as int;
                          final subject = row['subject_name'] as String;
                          final teacher = row['teacher_name'] as String;
                          final subColor = _getSubjectColor(subject);
                          final time = _periodTimes[period] ?? '';

                          return TableRow(
                            decoration: BoxDecoration(
                              color: period % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                            ),
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Text('Period $period', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _parentAccent)),
                                    if (time.isNotEmpty)
                                      Text(time, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(color: subColor, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        subject,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        teacher,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<_ScheduleData> _load(SupabaseClient client, String studentId) async {
    final roster = await client.schema('academic').from('class_roster').select('class_id').eq('student_id', studentId).maybeSingle();
    if (roster == null) return _ScheduleData(rows: []);
    final classId = roster['class_id'] as String;

    final timetableRows = await client.schema('scheduling').from('timetable').select('slot_id, subject_id, teacher_id').eq('class_id', classId);
    if ((timetableRows as List).isEmpty) return _ScheduleData(rows: []);

    final slotIds = timetableRows.map((r) => r['slot_id']).toSet().toList();
    final subjectIds = timetableRows.map((r) => r['subject_id']).toSet().toList();
    final teacherIds = timetableRows.map((r) => r['teacher_id']).toSet().toList();

    final slots = await client.schema('scheduling').from('time_slots').select('id, day, period_number').inFilter('id', slotIds);
    final subjects = await client.schema('academic').from('subjects').select('id, name').inFilter('id', subjectIds);
    final teachers = await client.schema('public').from('staff').select('id, full_name').inFilter('id', teacherIds);

    final slotById = {for (final s in slots as List) s['id']: s};
    final subjectNameById = {for (final s in subjects as List) s['id']: s['name']};
    final teacherNameById = {for (final t in teachers as List) t['id']: t['full_name']};

    final rows = timetableRows.map((r) {
      final slot = slotById[r['slot_id']] as Map<String, dynamic>?;
      return {
        'day': slot?['day'],
        'period_number': slot?['period_number'],
        'subject_name': subjectNameById[r['subject_id']] ?? 'Unknown',
        'teacher_name': teacherNameById[r['teacher_id']] ?? 'Unknown',
      };
    }).where((r) => r['day'] != null).toList();

    return _ScheduleData(rows: rows);
  }
}

class _ScheduleData {
  _ScheduleData({required this.rows});
  final List<Map<String, dynamic>> rows;
}
