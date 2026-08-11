import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';

class ChildSummary {
  final double amountDue;
  final double amountPaid;
  final List<Map<String, dynamic>> attendanceRecords;

  ChildSummary({
    required this.amountDue,
    required this.amountPaid,
    required this.attendanceRecords,
  });
}

class ChildPerformance {
  final double attendancePercent;
  final double? avgMarksPercent;
  final int totalAssignments;
  final int submittedAssignments;

  ChildPerformance({
    required this.attendancePercent,
    required this.avgMarksPercent,
    required this.totalAssignments,
    required this.submittedAssignments,
  });
}

final childSummaryProvider = FutureProvider.family.autoDispose<ChildSummary, String>((ref, studentId) async {
  final client = ref.watch(supabaseClientProvider);
  
  final invoices = await client.schema('finance').from('invoices').select('amount_due, amount_paid').eq('student_id', studentId);
  double due = 0, paid = 0;
  for (final row in invoices as List) {
    due += (row['amount_due'] as num).toDouble();
    paid += (row['amount_paid'] as num).toDouble();
  }
  
  final attendance = await client.schema('attendance').from('records').select('date, status').eq('student_id', studentId).order('date', ascending: false).limit(10);
  
  return ChildSummary(
    amountDue: due,
    amountPaid: paid,
    attendanceRecords: List<Map<String, dynamic>>.from(attendance as List),
  );
});

final childPerformanceProvider = FutureProvider.family.autoDispose<ChildPerformance, String>((ref, studentId) async {
  final client = ref.watch(supabaseClientProvider);
  
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

  return ChildPerformance(
    attendancePercent: attendancePercent,
    avgMarksPercent: avgMarksPercent,
    totalAssignments: totalAssignments,
    submittedAssignments: submittedAssignments,
  );
});
