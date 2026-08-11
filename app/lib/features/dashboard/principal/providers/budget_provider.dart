// Budget provider for advanced budget module features
// Manages fiscal year selection, time period, budget data loading, variance analysis, forecasting, etc.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_providers.dart';
import '../models/budget_models.dart';

// State container for budget dashboard
class BudgetDashboardState {
  final String selectedFiscalYear;
  final TimePeriod timePeriod;
  final bool isLoading;
  final List<BudgetLine> budgets;
  final Map<String, double> actualByCategory;
  final double totalPlannedAmount;
  final double totalActualSpend;
  final double utilizationRate;
  final List<BudgetAuditEntry> auditTrail;
  final List<BudgetNote> notes;
  final BudgetForecast? forecast;
  final String? error;

  BudgetDashboardState({
    required this.selectedFiscalYear,
    required this.timePeriod,
    required this.isLoading,
    this.budgets = const [],
    this.actualByCategory = const {},
    this.totalPlannedAmount = 0,
    this.totalActualSpend = 0,
    this.utilizationRate = 0,
    this.auditTrail = const [],
    this.notes = const [],
    this.forecast,
    this.error,
  });

  BudgetDashboardState copyWith({
    String? selectedFiscalYear,
    TimePeriod? timePeriod,
    bool? isLoading,
    List<BudgetLine>? budgets,
    Map<String, double>? actualByCategory,
    double? totalPlannedAmount,
    double? totalActualSpend,
    double? utilizationRate,
    List<BudgetAuditEntry>? auditTrail,
    List<BudgetNote>? notes,
    BudgetForecast? forecast,
    String? error,
  }) {
    return BudgetDashboardState(
      selectedFiscalYear: selectedFiscalYear ?? this.selectedFiscalYear,
      timePeriod: timePeriod ?? this.timePeriod,
      isLoading: isLoading ?? this.isLoading,
      budgets: budgets ?? this.budgets,
      actualByCategory: actualByCategory ?? this.actualByCategory,
      totalPlannedAmount: totalPlannedAmount ?? this.totalPlannedAmount,
      totalActualSpend: totalActualSpend ?? this.totalActualSpend,
      utilizationRate: utilizationRate ?? this.utilizationRate,
      auditTrail: auditTrail ?? this.auditTrail,
      notes: notes ?? this.notes,
      forecast: forecast ?? this.forecast,
      error: error ?? this.error,
    );
  }
}

// State holder for the budget provider
class BudgetDashboardHolder extends StateNotifier<BudgetDashboardState> {
  final SupabaseClient client;
  final String userRole;

  BudgetDashboardHolder(SupabaseClient client, String role, BudgetDashboardState initialState)
      : this.client = client,
        this.userRole = role,
        super(initialState);

  // Initialize with fiscal year and period
  void init({String fiscalYear = '2026-27', TimePeriod period = TimePeriod.yearly}) {
    state = state.copyWith(
      selectedFiscalYear: fiscalYear,
      timePeriod: period,
      isLoading: true,
    );
    _loadData();
  }

  // Change fiscal year
  Future<void> changeFiscalYear(String newYear) async {
    state = state.copyWith(selectedFiscalYear: newYear, isLoading: true);
    await _loadData();
  }

  // Change time period
  Future<void> changeTimePeriod(TimePeriod newPeriod) async {
    state = state.copyWith(timePeriod: newPeriod, isLoading: true);
    await _loadData();
  }

  // Load all budget data for selected fiscal year and period
  Future<void> _loadData() async {
    try {
      // Load budgets with their category, academic year, planned amount
      final budgetsRows = await client.schema('finance')
          .from('budgets')
          .select('id, category, academic_year, planned_amount, created_at')
          .order('category');

      final budgetsList = List<Map<String, dynamic>>.from(budgetsRows);

      // Get actual spend data by category
      final actualByCategory = await _getActualSpentByCategory();

      // Calculate totals
      final totalPlanned = budgetsList.map((b) => (b['planned_amount'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b);
      final totalActual = actualByCategory.values.reduce((a, b) => a + b);
      final utilization = totalPlanned > 0 ? (totalActual / totalPlanned * 100).clamp(0.0, 150.0) : 0.0;

      // Load audit trail
      final auditTrailRows = await client.schema('finance')
          .from('budget_audit_trail')
          .select('id, budget_id, operation_type, user_id, old_data, new_data, changed_at, ip_address')
          .order('changed_at', ascending: false)
          .limit(100);

      final auditTrailList = List<Map<String, dynamic>>.from(auditTrailRows).map((row) => BudgetAuditEntry(
        id: row['id'],
        budgetId: row['budget_id'],
        operationType: row['operation_type'],
        userId: row['user_id'],
        oldData: row['old_data'] as String?,
        newData: row['new_data'] as String?,
        changedAt: row['changed_at'] as DateTime,
        ipAddress: row['ip_address'],
      )).toList();

      // Load budget notes (filtered by current fiscal year only)
      final notesRows = await client.schema('finance')
          .from('budget_notes')
          .select('id, category, academic_year, notes, created_by, created_at, updated_at')
          .order('category');

      final notesList = List<Map<String, dynamic>>.from(notesRows);

      // Build forecasts
      final forecast = _calculateForecast(totalPlanned, totalActual, budgetsList);

      state = state.copyWith(
        budgets: budgetsList.map((b) => BudgetLine(
          id: b['id'],
          category: b['category'],
          academicYear: b['academic_year'],
          plannedAmount: (b['planned_amount'] as num?)?.toDouble() ?? 0.0,
          actualSpend: actualByCategory[b['category']],
          createdAt: b['created_at'],
        )).toList(),
        actualByCategory: actualByCategory,
        totalPlannedAmount: totalPlanned,
        totalActualSpend: totalActual,
        utilizationRate: utilization,
        auditTrail: auditTrailList,
        notes: notesList.map((n) => BudgetNote(
          id: n['id'],
          category: n['category'],
          academicYear: n['academic_year'],
          notes: n['notes'],
          createdByName: 'User', // Need to fetch staff name
          createdAt: n['created_at'] as DateTime,
          updatedAt: n['updated_at'] as DateTime,
        )).toList(),
        forecast: forecast,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Calculate actual spend by category based on related purchase orders, payroll, etc.
  Future<Map<String, double>> _getActualSpentByCategory() async {
    final Map<String, double> result = {};

    // Get purchase orders (paid ones)
    final poRows = await client.schema('finance').from('purchase_orders')
        .select('id, category, amount, status, created_at')
        .order('created_at', ascending: false);

    final poList = List<Map<String, dynamic>>.from(poRows);
    final vpRows = await client.schema('finance').from('vendor_payments')
        .select('id, purchase_order_id, amount, status, created_at')
        .order('created_at', ascending: false);

    final vpList = List<Map<String, dynamic>>.from(vpRows);

    final Set<String> paidPoIds = {};
    for (final vp in vpList) {
      if (vp['status'] == 'paid' && vp['purchase_order_id'] != null) {
        paidPoIds.add(vp['purchase_order_id'].toString());
      }
    }

    for (final po in poList) {
      final cat = (po['category'] ?? 'uncategorized').toString().trim();
      final amt = (po['amount'] as num?)?.toDouble() ?? 0.0;
      final poId = po['id'].toString();
      bool isSpent = (po['status'] == 'paid') || (paidPoIds.contains(poId));
      if (isSpent) {
        result[cat] = (result[cat] ?? 0.0) + amt;
      }
    }

    // Get payroll runs (net amount for paid payroll)
    final payrollRows = await client.schema('finance').from('payroll_runs')
        .select('id, net_amount, status');
    final payrollList = List<Map<String, dynamic>>.from(payrollRows);
    double totalPayrollNet = 0;
    for (final p in payrollList) {
      if (p['status'] == 'paid') {
        totalPayrollNet += (p['net_amount'] as num?)?.toDouble() ?? 0.0;
      }
    }

    // Add payroll as "administrative" category if no specific category exists
    if (!result.containsKey('Administrative')) {
      result['Administrative'] = 0.0;
    }
    result['Administrative'] = (result['Administrative'] ?? 0.0) + totalPayrollNet;

    return result;
  }

  // Calculate end-of-year forecast based on current burn rate
  BudgetForecast? _calculateForecast(double totalPlanned, double totalActual, List<dynamic> budgets) {
    try {
      final now = DateTime.now();
      // Assume fiscal year starts April 1st
      int fyStartMonth = now.month;
      int fyStartYear = now.year;
      if (fyStartMonth >= 4) {
        fyStartYear = now.year;
      } else {
        fyStartYear = now.year - 1;
      }
      final fyStart = DateTime(fyStartYear, 4, 1);

      // Check if we're before the start of the fiscal year (e.g., Jan-Mar of next year after Apr 1)
      final fyEnd = DateTime(fyStartYear + 1, 4, 1);
      if (now.isBefore(fyStart)) {
        // If we're between Oct-Mar and FY hasn't started yet, use previous FY
        final prevFyStart = DateTime(fyStartYear - 1, 4, 1);
        final prevFyEnd = DateTime(fyStartYear, 4, 1);
        if (now.isAfter(prevFyStart) && now.isBefore(prevFyEnd)) {
          // We're in the next calendar year but before April - treat as previous FY still ongoing or skip
          return null;
        }
        // Use the FY that has already started most recently
        return _calculateForecastWithDates(now, fyStart, fyEnd, totalPlanned, totalActual);
      }
      return _calculateForecastWithDates(now, fyStart, fyEnd, totalPlanned, totalActual);
    } catch (e) {
      return null;
    }
  }

  BudgetForecast? _calculateForecastWithDates(DateTime now, DateTime fyStart, DateTime fyEnd, double totalPlanned, double totalActual) {
    try {
      final daysElapsed = now.difference(fyStart).inDays;
      const totalDaysInFy = 365; // Simplified - fiscal year is 12 months approx 365 days
      if (daysElapsed <= 0 || daysElapsed >= totalDaysInFy) return null;

      // Monthly burn rate based on actual spend so far
      final monthsElapsed = (daysElapsed / 30.44).ceil();
      if (monthsElapsed == 0) return null;

      final monthlyBurn = totalActual / monthsElapsed;
      const totalMonthsInFy = 12;
      final remainingMonths = totalMonthsInFy - monthsElapsed.toDouble();
      if (remainingMonths <= 0) return null;

      // Projected end of year spending
      final projectedEndOfYear = totalActual + (monthlyBurn * remainingMonths);
      final expectedUtil = (projectedEndOfYear / totalPlanned * 100).clamp(0.0, 200.0);
      final isOnTrack = expectedUtil >= 80 && expectedUtil <= 120;

      return BudgetForecast(
        currentMonthlyBurn: monthlyBurn,
        projectedEndOfYear: projectedEndOfYear,
        remainingPeriodMonths: remainingMonths,
        expectedUtilizationPercent: expectedUtil,
        isOnTrack: isOnTrack,
      );
    } catch (e) {
      return null;
    }
  }

  // Add a new budget line
  Future<void> addBudgetLine(String category, String academicYear, double plannedAmount) async {
    try {
      await client.schema('finance').from('budgets').insert({
        'school_id': '', // Would get from context in real app
        'category': category,
        'academic_year': academicYear,
        'planned_amount': plannedAmount,
      });
      _loadData(); // Refresh data
    } catch (e) {
      throw Exception('Failed to add budget line: ${e.toString()}');
    }
  }

  // Update an existing budget line
  Future<void> updateBudgetLine(String budgetId, String category, String academicYear, double plannedAmount) async {
    try {
      await client.schema('finance').from('budgets').update({
        'category': category,
        'academic_year': academicYear,
        'planned_amount': plannedAmount,
      }).eq('id', budgetId);
      _loadData();
    } catch (e) {
      throw Exception('Failed to update budget line: ${e.toString()}');
    }
  }

  // Delete a budget line
  Future<void> deleteBudgetLine(String budgetId) async {
    try {
      await client.schema('finance').from('budgets').delete().eq('id', budgetId);
      _loadData();
    } catch (e) {
      throw Exception('Failed to delete budget line: ${e.toString()}');
    }
  }

  // Add a budget note
  Future<void> addBudgetNote(String category, String academicYear, String notes) async {
    try {
      await client.schema('finance').from('budget_notes').insert({
        'school_id': '', // Would get from context
        'category': category,
        'academic_year': academicYear,
        'notes': notes,
        'created_by': '', // Would get from auth
      });
      _loadData();
    } catch (e) {
      throw Exception('Failed to add budget note: ${e.toString()}');
    }
  }

  // Update budget note
  Future<void> updateBudgetNote(String noteId, String notes) async {
    try {
      await client.schema('finance').from('budget_notes').update({
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', noteId);
      _loadData();
    } catch (e) {
      throw Exception('Failed to update budget note: ${e.toString()}');
    }
  }
}

// Provider for budget dashboard data
final budgetDashboardProvider = StateNotifierProvider<BudgetDashboardHolder, BudgetDashboardState>((ref) {
  final client = ref.read(supabaseClientProvider);
  // In a real implementation, we'd get the school_id from the auth context
  final defaultYear = '2026-27';

  return BudgetDashboardHolder(client, 'principal', BudgetDashboardState(
    selectedFiscalYear: defaultYear,
    timePeriod: TimePeriod.yearly,
    isLoading: false,
  ));
});
