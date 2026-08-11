import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/line_chart.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Teacher Attendance Marking — genuinely new: until now the ONLY way attendance got
/// recorded was OMR (Admin-only, bulk photo scan) or dummy-data SQL. A teacher had no
/// way to mark their own class's attendance directly in the app. Writes with
/// method='manual' — the real, existing check constraint value (NOT 'app', which was
/// a real bug found and fixed elsewhere tonight — attendance.records only accepts
/// 'manual', 'omr', 'app_checkin').
///
/// Only shows classes this teacher actually teaches (via scheduling.timetable), not
/// every class in the school.
class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  ConsumerState<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends ConsumerState<TeacherAttendanceScreen> {
  late Future<_AttendanceData> _future;
  String? _selectedClassId;
  final Map<String, bool> _presentByStudentId = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AttendanceData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    if (selfStaffId == null) return _AttendanceData(selfStaffId: null, classes: []);

    final timetableRows = await client.schema('scheduling').from('timetable').select('class_id').eq('teacher_id', selfStaffId);
    final classIds = (timetableRows as List).map((r) => r['class_id'] as String).toSet().toList();
    if (classIds.isEmpty) return _AttendanceData(selfStaffId: selfStaffId, classes: []);

    final classes = await client
        .schema('academic')
        .from('classes')
        .select('id, name')
        .inFilter('id', classIds)
        .eq('is_archived', false)
        .order('name');
    final classList = List<Map<String, dynamic>>.from(classes as List);

    // Rank classes by historical attendance count so default selection has the most data (7-A/6-A)
    try {
      final counts = <String, int>{};
      await Future.wait(classIds.map((cid) async {
        final res = await client
            .schema('attendance')
            .from('records')
            .select('id')
            .eq('class_id', cid)
            .count(CountOption.exact);
        counts[cid] = res.count;
      }));
      classList.sort((a, b) {
        final countA = counts[a['id']] ?? 0;
        final countB = counts[b['id']] ?? 0;
        if (countB != countA) return countB.compareTo(countA);
        return (a['name'] as String).compareTo(b['name'] as String);
      });
    } catch (_) {}

    return _AttendanceData(selfStaffId: selfStaffId, classes: classList);
  }

  Future<List<Map<String, dynamic>>> _loadRoster(String classId) async {
    final client = ref.read(supabaseClientProvider);
    final roster = await client.schema('academic').from('class_roster').select('student_id, roll_no').eq('class_id', classId).order('roll_no');
    final studentIds = (roster as List).map((r) => r['student_id'] as String).toList();
    final students = studentIds.isEmpty
        ? []
        : await client.schema('public').from('students').select('id, full_name').inFilter('id', studentIds);
    final nameById = {for (final s in students) s['id'] as String: s['full_name'] as String};

    final rows = roster.map((r) => {
          'student_id': r['student_id'],
          'roll_no': r['roll_no'],
          'full_name': nameById[r['student_id']] ?? 'Unknown',
        }).toList();

    for (final r in rows) {
      _presentByStudentId.putIfAbsent(r['student_id'] as String, () => true);
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> _loadAttendanceTrend(String classId) async {
    final client = ref.read(supabaseClientProvider);
    try {
      final res = await client.schema('analytics').rpc('get_attendance_trend', params: {'p_class_id': classId});
      final list = List<Map<String, dynamic>>.from(res as List);
      if (list.length >= 2) return list;
    } catch (_) {
      try {
        final res = await client.rpc('get_attendance_trend', params: {'p_class_id': classId});
        final list = List<Map<String, dynamic>>.from(res as List);
        if (list.length >= 2) return list;
      } catch (_) {}
    }

    // Try computing directly from attendance.records for this class
    try {
      final recordsRaw = await client
          .schema('attendance')
          .from('records')
          .select('date, status')
          .eq('class_id', classId);
      final records = List<Map<String, dynamic>>.from(recordsRaw as List);
      if (records.isNotEmpty) {
        final byMonth = <String, List<String>>{};
        for (final r in records) {
          final dateStr = r['date'] as String?;
          if (dateStr == null || dateStr.length < 7) continue;
          final month = dateStr.substring(0, 7);
          byMonth.putIfAbsent(month, () => []).add(r['status'] as String? ?? 'absent');
        }
        if (byMonth.length >= 2) {
          final sortedMonths = byMonth.keys.toList()..sort();
          return sortedMonths.map((m) {
            final stList = byMonth[m]!;
            final presentCount = stList.where((s) => s == 'present').length;
            final pct = (presentCount / stList.length) * 100;
            return {'month': m, 'pct_present': double.parse(pct.toStringAsFixed(1))};
          }).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  Future<void> _submit(String classId, List<Map<String, dynamic>> roster) async {
    final client = ref.read(supabaseClientProvider);
    final today = DateTime.now().toIso8601String().split('T').first;
    try {
      await client.schema('attendance').from('records').delete().eq('class_id', classId).eq('date', today).eq('method', 'manual');

      final rows = roster.map((r) => {
            'student_id': r['student_id'],
            'class_id': classId,
            'date': today,
            'status': (_presentByStudentId[r['student_id']] ?? true) ? 'present' : 'absent',
            'method': 'manual',
          }).toList();
      await client.schema('attendance').from('records').insert(rows);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance submitted.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_AttendanceData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              if (data.selfStaffId == null) {
                return const Center(child: Text("Your account isn't linked to a staff record yet."));
              }
              if (data.classes.isEmpty) {
                return const Center(child: Text("You don't have any classes on the timetable yet."));
              }

              _selectedClassId ??= data.classes.first['id'] as String;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text('Mark Attendance', style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedClassId,
                      decoration: const InputDecoration(labelText: 'Class'),
                      items: data.classes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                      onChanged: (v) => setState(() => _selectedClassId = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      key: ValueKey('trend-$_selectedClassId'),
                      future: _loadAttendanceTrend(_selectedClassId!),
                      builder: (context, snapshot) {
                        final trend = snapshot.data ?? [];
                        if (trend.length < 2) {
                          return GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.show_chart_outlined, color: AppColors.textSecondary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Not enough historical data yet for this class',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        }
                        final labels = trend.map((t) => t['month']?.toString() ?? '').toList();
                        final values = trend.map((t) => (t['pct_present'] as num?)?.toDouble() ?? 0.0).toList();
                        return SizedBox(
                          height: 160,
                          child: LineChart(
                            title: 'Attendance Trend (% Present)',
                            labels: labels,
                            values: values,
                            maxValue: 100.0,
                            chartColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      key: ValueKey(_selectedClassId),
                      future: _loadRoster(_selectedClassId!),
                      builder: (context, rosterSnapshot) {
                        if (rosterSnapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }
                        final roster = rosterSnapshot.data ?? [];
                        if (roster.isEmpty) {
                          return const Center(child: Text('No students in this class yet.'));
                        }
                        return Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(20),
                                children: roster.map((r) {
                                  final present = _presentByStudentId[r['student_id']] ?? true;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: GlassCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Row(
                                        children: [
                                          Text('${r['roll_no']}', style: Theme.of(context).textTheme.bodyMedium),
                                          const SizedBox(width: 12),
                                          Expanded(child: Text(r['full_name'] as String, style: Theme.of(context).textTheme.titleMedium)),
                                          Switch(
                                            value: present,
                                            activeColor: AppColors.success,
                                            onChanged: (v) => setState(() => _presentByStudentId[r['student_id'] as String] = v),
                                          ),
                                          Text(present ? 'Present' : 'Absent', style: TextStyle(color: present ? AppColors.success : AppColors.error)),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _submit(_selectedClassId!, roster),
                                  child: const Text('Submit attendance'),
                                ),
                              ),
                            ),
                          ],
                        );
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
}

class _AttendanceData {
  _AttendanceData({required this.selfStaffId, required this.classes});
  final String? selfStaffId;
  final List<Map<String, dynamic>> classes;
}
