import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:collection/collection.dart';

import '../../core/auth/auth_providers.dart';

/// Dashboard summary data model
class DashboardSummary {
  final int totalStudents;
  final int totalStaff;
  final int activeTeachers;
  final double monthlyRevenue;
  final double outstandingFees;
  final double monthlyCollections;
  final double totalExpenses;
  final double budgetUtilization; // percentage 0-100
  final int pendingApprovals;
  final double attendancePercentage;
  final int totalVendors;
  final List<Map<String, dynamic>> recentPayments;
  final List<Map<String, dynamic>> topDefaulters;
  final List<Map<String, dynamic>> upcomingDeadlines;
  final List<Map<String, dynamic>> systemAlerts;
  final List<Map<String, dynamic>> recentActivities;

  DashboardSummary({
    required this.totalStudents,
    required this.totalStaff,
    required this.activeTeachers,
    required this.monthlyRevenue,
    required this.outstandingFees,
    required this.monthlyCollections,
    required this.totalExpenses,
    required this.budgetUtilization,
    required this.pendingApprovals,
    required this.attendancePercentage,
    required this.totalVendors,
    required this.recentPayments,
    required this.topDefaulters,
    required this.upcomingDeadlines,
    required this.systemAlerts,
    required this.recentActivities,
  });
}

/// Provider that fetches all dashboard summary data.
final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final client = ref.read(supabaseClientProvider);
  return await _loadDashboardSummary(client);
});

Future<DashboardSummary> _loadDashboardSummary(SupabaseClient client) async {
  try {
    // Load all data in parallel
    final studentsFuture = client.schema('public').from('students').select('id, full_name');
    final staffFuture = client.schema('public').from('staff').select('id, role, full_name');
    final paymentsFuture = client.schema('finance').from('payments').select('id, invoice_id, amount, method, status, created_at, updated_at');
    final invoicesFuture = client.schema('finance').from('invoices').select('id, student_id, amount_due, amount_paid, due_date');
    final purchaseOrdersFuture = client.schema('finance').from('purchase_orders').select('id, status, amount, description, requested_by, created_at');
    final vendorPaymentsFuture = client.schema('finance').from('vendor_payments').select('id, amount, status, purchase_order_id, created_at');
    final payrollRunsFuture = client.schema('finance').from('payroll_runs').select('id, status, employee_id, pay_period, gross_amount, net_amount, created_at');
    final budgetsFuture = client.schema('finance').from('budgets').select('category, planned_amount, academic_year');
    final attendanceFuture = client.schema('attendance').from('records').select('student_id, date, status');
    final vendorsFuture = client.schema('finance').from('vendors').select('id, name');
    final waiverRequestsFuture = client.schema('finance').from('waiver_requests').select('id, status, student_id, requested_amount');
    final notificationsFuture = client.schema('public').from('notifications').select('id, recipient_student_id, title, body, created_at');

    await Future.wait([
      studentsFuture,
      staffFuture,
      paymentsFuture,
      invoicesFuture,
      purchaseOrdersFuture,
      vendorPaymentsFuture,
      payrollRunsFuture,
      budgetsFuture,
      attendanceFuture,
      vendorsFuture,
      waiverRequestsFuture,
      notificationsFuture,
    ]);

    final studentsList = List<Map<String, dynamic>>.from(studentsFuture as List);
    final staffList = List<Map<String, dynamic>>.from(staffFuture as List);
    final paymentList = List<Map<String, dynamic>>.from(paymentsFuture as List);
    final invoiceList = List<Map<String, dynamic>>.from(invoicesFuture as List);
    final poList = List<Map<String, dynamic>>.from(purchaseOrdersFuture as List);
    final vpList = List<Map<String, dynamic>>.from(vendorPaymentsFuture as List);
    final payrollList = List<Map<String, dynamic>>.from(payrollRunsFuture as List);
    final budgetList = List<Map<String, dynamic>>.from(budgetsFuture as List);
    final attendanceList = List<Map<String, dynamic>>.from(attendanceFuture as List);
    final vendorList = List<Map<String, dynamic>>.from(vendorsFuture as List);
    final notifications = List<Map<String, dynamic>>.from(notificationsFuture as List);

    // Build student name map
    final studentNameById = <String, String>{for (final s in studentsList) s['id'] as String: s['full_name'] as String};

    // Calculate metrics
    final totalStudentsCount = studentsList.length;
    final totalStaffCount = staffList.length;
    final activeTeachers = staffList.where((s) => (s['role'] as String?)?.toLowerCase().contains('teacher') ?? false).length;

    // Monthly revenue - completed payments this month
    final now = DateTime.now();
    final oneMonthAgo = DateTime(now.year, now.month, 1);
    final monthlyRevenue = paymentList
        .where((p) => (p['status'] as String?) == 'success')
        .fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble());

    // Outstanding fees
    final outstandingFees = invoiceList.fold<double>(0, (sum, i) {
      final due = (i['amount_due'] as num?)?.toDouble() ?? 0;
      final paid = (i['amount_paid'] as num?)?.toDouble() ?? 0;
      return sum + (due - paid);
    });

    // Monthly collections (last month's payments)
    final monthlyCollections = paymentList
        .where((p) {
          final created = DateTime.tryParse(p['created_at'] as String);
          return created != null && created.isAfter(oneMonthAgo) && ((p['status'] as String?) == 'success');
        })
        .fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble());

    // Total expenses from paid vendor payments
    final totalExpenses = vpList
        .where((v) => (v['status'] as String?) == 'paid')
        .fold<double>(0, (sum, v) => sum + (v['amount'] as num).toDouble());

    // Budget utilization
    final totalBudget = budgetList.fold<double>(0, (sum, b) => sum + (b['planned_amount'] as num).toDouble());
    final budgetUtilization = totalBudget > 0 ? (totalExpenses / totalBudget * 100).clamp(0.0, 100.0) : 0.0;

    // Pending approvals
    const pendingStatuses = ['pending_approval', 'draft'];
    final pendingPo = poList.where((p) => pendingStatuses.contains(p['status'])).length;
    const pendingVpStatuses = ['pending_approval', 'draft'];
    final pendingVp = vpList.where((v) => pendingVpStatuses.contains(v['status'])).length;
    const pendingPayrollStatuses = ['pending_approval', 'draft'];
    final pendingPayroll = payrollList.where((r) => pendingPayrollStatuses.contains(r['status'])).length;
    final pendingApprovals = pendingPo + pendingVp + pendingPayroll;

    // Attendance percentage
    double attendancePercentage = 0.0;
    if (attendanceList.isNotEmpty) {
      final present = attendanceList.where((a) => (a['status'] as String?) == 'present').length;
      attendancePercentage = (present / attendanceList.length * 100).round().toDouble();
    }

    final totalVendorCount = vendorList.length;

    // Recent payments (with student names)
    final recentPayments = paymentList
        .take(10)
        .map((p) {
          final invoiceId = p['invoice_id'];
          final invoice = invoiceList.firstWhereOrNull((i) => i['id'] == invoiceId);
          final studentId = invoice?['student_id'];
          final studentName = studentId != null ? studentNameById[studentId] ?? 'Unknown' : 'Unknown';
          final created = DateTime.tryParse(p['created_at'] as String) ?? DateTime.now();
          return {
            'id': p['id'],
            'studentName': studentName,
            'amount': (p['amount'] as num).toDouble(),
            'method': p['method'],
            'status': p['status'],
            'createdAt': created,
          };
        }).toList();

    // Top fee defaulters (highest outstanding amounts)
    final defaulters = invoiceList
        .where((i) => ((i['amount_due'] as num?)?.toDouble() ?? 0) > ((i['amount_paid'] as num?)?.toDouble() ?? 0))
        .map((i) {
          final studentId = i['student_id'];
          final name = studentId != null ? studentNameById[studentId] ?? 'Unknown' : 'Unknown';
          final due = DateTime.tryParse(i['due_date'] as String) ?? DateTime.now();
          return {
            'studentName': name,
            'amountDue': ((i['amount_due'] as num?)?.toDouble() ?? 0) - ((i['amount_paid'] as num?)?.toDouble() ?? 0),
            'dueDate': due,
          };
        })
        .toList()
        .sortDescendingBy<num>((d) => ((d as Map<String, dynamic>)['amountDue'] as num?)?.toDouble() ?? 0)
        .take(5)
        .toList();

    // Upcoming fee deadlines (next 7 days)
    const upcomingDays = 7;
    final upcomingDeadlines = invoiceList
        .where((i) => ((i['amount_due'] as num?)?.toDouble() ?? 0) > ((i['amount_paid'] as num?)?.toDouble() ?? 0))
        .map((i) {
          final due = DateTime.tryParse(i['due_date'] as String);
          if (due == null || !due.isAfter(DateTime.now()) || due.add(const Duration(days: upcomingDays)).isBefore(DateTime.now())) {
            return null;
          }
          final studentId = i['student_id'];
          final name = studentId != null ? studentNameById[studentId] ?? 'Unknown' : 'Unknown';
          return {
            'studentName': name,
            'amountDue': ((i['amount_due'] as num?)?.toDouble() ?? 0) - ((i['amount_paid'] as num?)?.toDouble() ?? 0),
            'dueDate': due,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList()
        .sortAscendingBy<DateTime>((d) => d['dueDate'] as DateTime? ?? DateTime.now())
        .take(5)
        .toList();

    // System alerts
    final systemAlerts = <Map<String, dynamic>>[];
    if (outstandingFees > 50000) {
      systemAlerts.add({'message': 'High outstanding fees detected (${outstandingFees.toStringAsFixed(0)})', 'isWarning': true});
    }
    if (pendingApprovals > 5) {
      systemAlerts.add({'message': '$pendingApprovals items pending approval', 'isWarning': true});
    }
    if (monthlyRevenue < 10000) {
      systemAlerts.add({'message': 'Low monthly revenue this period', 'isWarning': false});
    }
    if (attendancePercentage < 80) {
      systemAlerts.add({'message': 'Below average attendance (${attendancePercentage.round()}%)', 'isWarning': true});
    }

    // Recent activities (combine payments and notifications)
    final activities = <Map<String, dynamic>>[];
    for (int i = 0; i < recentPayments.length && i < 3; i++) {
      final p = recentPayments[i];
      activities.add({
        'action': 'Payment Received',
        'description': '₹${p['amount'].toStringAsFixed(2)} from ${p['studentName']} via ${p['method']}',
        'timestamp': p['createdAt'],
      });
    }
    for (final n in notifications.take(3)) {
      activities.add({
        'action': 'Notification',
        'description': n['body'] as String,
        'timestamp': DateTime.tryParse(n['created_at'] as String) ?? DateTime.now(),
      });
    }
    activities.sort((a, b) {
      final dateA = DateTime.tryParse(a['timestamp'] as String? ?? '');
      final dateB = DateTime.tryParse(b['timestamp'] as String? ?? '');
      if (dateA == null || dateB == null) return 0;
      return dateB.compareTo(dateA);
    });
    final recentActivities = activities.take(5).toList();

    return DashboardSummary(
      totalStudents: totalStudentsCount,
      totalStaff: totalStaffCount,
      activeTeachers: activeTeachers,
      monthlyRevenue: monthlyRevenue,
      outstandingFees: outstandingFees,
      monthlyCollections: monthlyCollections,
      totalExpenses: totalExpenses,
      budgetUtilization: budgetUtilization,
      pendingApprovals: pendingApprovals,
      attendancePercentage: attendancePercentage,
      totalVendors: totalVendorCount,
      recentPayments: recentPayments,
      topDefaulters: defaulters,
      upcomingDeadlines: upcomingDeadlines,
      systemAlerts: systemAlerts,
      recentActivities: recentActivities,
    );
  } catch (e) {
    throw Exception('Failed to load dashboard data: $e');
  }
}

// Extension methods for sorting
extension SortExtension<T> on List<T> {
  List<T> sortDescendingBy<K extends Comparable<K>>(K Function(T) keySelector) {
    sort((a, b) => keySelector(b).compareTo(keySelector(a)));
    return this;
  }

  List<T> sortAscendingBy<K extends Comparable<K>>(K Function(T) keySelector) {
    sort((a, b) => keySelector(a).compareTo(keySelector(b)));
    return this;
  }
}

// First where null helper
extension ListExtensions<T> on List<T> {
  T? firstWhereNull(bool Function(T test) predicate) {
    for (final item in this) {
      if (!predicate(item)) return item;
    }
    return null;
  }
}
