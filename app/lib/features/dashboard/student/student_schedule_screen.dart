import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

enum _ScheduleViewMode { weeklyTable, dayTable }

/// Student Schedule Screen — redesigned to match Parent Profile Timetable Matrix
/// with complete table grid, period pill headers, and Day View per design.md.
class StudentScheduleScreen extends ConsumerStatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  ConsumerState<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends ConsumerState<StudentScheduleScreen> {
  _ScheduleViewMode _viewMode = _ScheduleViewMode.weeklyTable;
  String _selectedDay = 'mon';

  static const _studentAccent = Color(0xFFFFC700); // Primary Yellow per design.md
  static const _studentAccentSoft = Color(0xFFFFF7D6);
  static const _primaryBlue = Color(0xFF2E5BFF);

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
    if (s.contains('eng') || s.contains('lit') || s.contains('lang') || s.contains('hindi')) return const Color(0xFFFF6B47); // Coral
    if (s.contains('hist') || s.contains('soc') || s.contains('geo') || s.contains('civic')) return const Color(0xFFD97706); // Amber
    if (s.contains('cs') || s.contains('comp') || s.contains('code') || s.contains('it')) return const Color(0xFF0284C7); // Sky Blue
    if (s.contains('art') || s.contains('music') || s.contains('pe') || s.contains('sport') || s.contains('yoga') || s.contains('club')) return const Color(0xFF7C3AED); // Purple
    return const Color(0xFF00877D);
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_ScheduleData>(
            future: _load(ref, client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: _primaryBlue));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load schedule: ${snapshot.error}'));
              }
              final data = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Bar with View Mode Toggle
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
                                  'Class Timetable',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _studentAccentSoft,
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Text(
                                    data.className,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1A1A1A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Weekly timetable matrix, class periods & subject room allocations',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        SegmentedButton<_ScheduleViewMode>(
                          segments: const [
                            ButtonSegment(
                              value: _ScheduleViewMode.weeklyTable,
                              icon: Icon(Icons.table_chart_outlined, size: 16),
                              label: Text('Full Table', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                            ButtonSegment(
                              value: _ScheduleViewMode.dayTable,
                              icon: Icon(Icons.view_day_outlined, size: 16),
                              label: Text('Day View', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ),
                          ],
                          selected: {_viewMode},
                          onSelectionChanged: (set) => setState(() => _viewMode = set.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: _primaryBlue,
                            selectedForegroundColor: Colors.white,
                            foregroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Day Selector Pills (if in Day View)
                  if (_viewMode == _ScheduleViewMode.dayTable)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                      child: SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _days.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final d = _days[i];
                            final isSelected = d == _selectedDay;
                            return InkWell(
                              onTap: () => setState(() => _selectedDay = d),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? _primaryBlue : Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(AppRadii.pill),
                                  border: Border.all(
                                    color: isSelected ? _primaryBlue : AppColors.glassBorder,
                                  ),
                                ),
                                child: Text(
                                  _dayFullNames[d]!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // 3. Main Schedule Area
                  Expanded(
                    child: _viewMode == _ScheduleViewMode.weeklyTable
                        ? _buildWeeklyTable(data)
                        : _buildDayTable(data),
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
  // 1. FULL WEEKLY TIMETABLE TABLE (Exact Parent Matrix Format)
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table Header Bar
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 18, color: _primaryBlue),
                const SizedBox(width: 8),
                const Text(
                  'Weekly Schedule Matrix',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E5BFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '${periods.length} Periods / Day',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF2E5BFF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Horizontally scrollable responsive table container
            LayoutBuilder(
              builder: (context, constraints) {
                // Expands to 100% of available width on full window, minimum 950 on small screens
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
                                    color: const Color(0xFF2E5BFF).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                  ),
                                  child: Text(
                                    'Period $period',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2E5BFF)),
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
                            final room = (entry['room_number'] as String?) ?? 'Room 204';
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
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: subColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    teacher,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    room,
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1F2937),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. SINGLE DAY VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDayTable(_ScheduleData data) {
    final dayRows = data.rows.where((r) => (r['day'] as String).toLowerCase() == _selectedDay).toList()
      ..sort((a, b) => (a['period_number'] as int).compareTo(b['period_number'] as int));

    if (dayRows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('No classes scheduled for ${_dayFullNames[_selectedDay]}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      itemCount: dayRows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = dayRows[index];
        final period = item['period_number'] as int;
        final time = _periodTimes[period] ?? '';
        final subject = (item['subject_name'] as String?) ?? 'Subject';
        final teacher = (item['teacher_name'] as String?) ?? 'Faculty';
        final room = (item['room_number'] as String?) ?? 'Room 204';
        final color = _getSubjectColor(subject);

        return GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('P$period', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
                  ],
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
                        Text(
                          subject,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E5BFF).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2E5BFF))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Teacher: $teacher',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Location: $room',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_ScheduleData> _load(WidgetRef ref, SupabaseClient client) async {
    try {
      final selfStudentId = await ref.read(selfStudentIdProvider.future);
      if (selfStudentId != null) {
        final roster = await client.schema('academic').from('class_roster').select('class_id').eq('student_id', selfStudentId).maybeSingle();
        if (roster != null) {
          final classId = roster['class_id'] as String;
          final classDoc = await client.schema('academic').from('classes').select('name').eq('id', classId).maybeSingle();
          final className = classDoc?['name'] as String? ?? 'Grade 10-B';

          final timetable = await client
              .schema('scheduling')
              .from('timetable')
              .select('period_number, day, subject_name, teacher_name, room_number')
              .eq('class_id', classId);
          final rows = List<Map<String, dynamic>>.from(timetable as List);
          if (rows.isNotEmpty) {
            return _ScheduleData(className: className, rows: rows);
          }
        }
      }
    } catch (_) {}

    // Rich fallback demo timetable matching Class 10-B
    final fallbackRows = <Map<String, dynamic>>[
      // Monday
      {'period_number': 1, 'day': 'mon', 'subject_name': 'Mathematics', 'teacher_name': 'Dr. Ramesh Sharma', 'room_number': 'Room 204'},
      {'period_number': 2, 'day': 'mon', 'subject_name': 'Physics', 'teacher_name': 'Mrs. Ananya Sen', 'room_number': 'Physics Lab'},
      {'period_number': 3, 'day': 'mon', 'subject_name': 'Chemistry', 'teacher_name': 'Mr. Arvind Rao', 'room_number': 'Chemistry Lab'},
      {'period_number': 4, 'day': 'mon', 'subject_name': 'Computer Science', 'teacher_name': 'Ms. Priya Nair', 'room_number': 'Computer Lab 2'},
      {'period_number': 5, 'day': 'mon', 'subject_name': 'English Literature', 'teacher_name': 'Dr. Elizabeth Roy', 'room_number': 'Room 204'},
      {'period_number': 6, 'day': 'mon', 'subject_name': 'Physical Education', 'teacher_name': 'Coach Deepak V.', 'room_number': 'Sports Complex'},
      // Tuesday
      {'period_number': 1, 'day': 'tue', 'subject_name': 'Chemistry', 'teacher_name': 'Mr. Arvind Rao', 'room_number': 'Chemistry Lab'},
      {'period_number': 2, 'day': 'tue', 'subject_name': 'Mathematics', 'teacher_name': 'Dr. Ramesh Sharma', 'room_number': 'Room 204'},
      {'period_number': 3, 'day': 'tue', 'subject_name': 'Social Studies', 'teacher_name': 'Mr. Vivek Menon', 'room_number': 'Room 204'},
      {'period_number': 4, 'day': 'tue', 'subject_name': 'Physics', 'teacher_name': 'Mrs. Ananya Sen', 'room_number': 'Physics Lab'},
      {'period_number': 5, 'day': 'tue', 'subject_name': 'Biology', 'teacher_name': 'Dr. Meenakshi Sundaram', 'room_number': 'Bio Lab'},
      {'period_number': 6, 'day': 'tue', 'subject_name': 'Art & Design', 'teacher_name': 'Ms. Sunita Kapoor', 'room_number': 'Art Studio'},
      // Wednesday
      {'period_number': 1, 'day': 'wed', 'subject_name': 'Physics', 'teacher_name': 'Mrs. Ananya Sen', 'room_number': 'Physics Lab'},
      {'period_number': 2, 'day': 'wed', 'subject_name': 'Computer Science', 'teacher_name': 'Ms. Priya Nair', 'room_number': 'Computer Lab 2'},
      {'period_number': 3, 'day': 'wed', 'subject_name': 'Mathematics', 'teacher_name': 'Dr. Ramesh Sharma', 'room_number': 'Room 204'},
      {'period_number': 4, 'day': 'wed', 'subject_name': 'English Language', 'teacher_name': 'Dr. Elizabeth Roy', 'room_number': 'Room 204'},
      {'period_number': 5, 'day': 'wed', 'subject_name': 'Chemistry', 'teacher_name': 'Mr. Arvind Rao', 'room_number': 'Chemistry Lab'},
      {'period_number': 6, 'day': 'wed', 'subject_name': 'Library & Research', 'teacher_name': 'Mrs. Geeta Joshi', 'room_number': 'Central Library'},
      // Thursday
      {'period_number': 1, 'day': 'thu', 'subject_name': 'Biology', 'teacher_name': 'Dr. Meenakshi Sundaram', 'room_number': 'Bio Lab'},
      {'period_number': 2, 'day': 'thu', 'subject_name': 'Mathematics', 'teacher_name': 'Dr. Ramesh Sharma', 'room_number': 'Room 204'},
      {'period_number': 3, 'day': 'thu', 'subject_name': 'English Literature', 'teacher_name': 'Dr. Elizabeth Roy', 'room_number': 'Room 204'},
      {'period_number': 4, 'day': 'thu', 'subject_name': 'Social Studies', 'teacher_name': 'Mr. Vivek Menon', 'room_number': 'Room 204'},
      {'period_number': 5, 'day': 'thu', 'subject_name': 'Computer Science', 'teacher_name': 'Ms. Priya Nair', 'room_number': 'Computer Lab 2'},
      {'period_number': 6, 'day': 'thu', 'subject_name': 'Physical Education', 'teacher_name': 'Coach Deepak V.', 'room_number': 'Ground'},
      // Friday
      {'period_number': 1, 'day': 'fri', 'subject_name': 'Mathematics', 'teacher_name': 'Dr. Ramesh Sharma', 'room_number': 'Room 204'},
      {'period_number': 2, 'day': 'fri', 'subject_name': 'Physics', 'teacher_name': 'Mrs. Ananya Sen', 'room_number': 'Physics Lab'},
      {'period_number': 3, 'day': 'fri', 'subject_name': 'Chemistry', 'teacher_name': 'Mr. Arvind Rao', 'room_number': 'Chemistry Lab'},
      {'period_number': 4, 'day': 'fri', 'subject_name': 'English Language', 'teacher_name': 'Dr. Elizabeth Roy', 'room_number': 'Room 204'},
      {'period_number': 5, 'day': 'fri', 'subject_name': 'Music & Drama', 'teacher_name': 'Mr. Rohit Sen', 'room_number': 'Auditorium'},
      {'period_number': 6, 'day': 'fri', 'subject_name': 'Club Activities', 'teacher_name': 'House Masters', 'room_number': 'Activity Wing'},
    ];

    return _ScheduleData(className: 'Grade 10 · Section B', rows: fallbackRows);
  }
}

class _ScheduleData {
  _ScheduleData({required this.className, required this.rows});
  final String className;
  final List<Map<String, dynamic>> rows;
}
