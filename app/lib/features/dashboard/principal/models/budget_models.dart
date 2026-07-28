// Budget models for the advanced budget module

class BudgetLine {
  final String id;
  final String category;
  final String academicYear;
  final double plannedAmount;
  final double? actualSpend;
  final DateTime? createdAt;

  BudgetLine({
    required this.id,
    required this.category,
    required this.academicYear,
    required this.plannedAmount,
    this.actualSpend,
    this.createdAt,
  });

  double get utilizationRate => plannedAmount > 0 ? (actualSpend ?? 0) / plannedAmount : 0;
  double get remainingBudget => plannedAmount - (actualSpend ?? 0);
}

class BudgetAuditEntry {
  final String id;
  final String budgetId;
  final String operationType; // 'insert', 'update', 'delete'
  final String userId;
  final String? oldData;
  final String? newData;
  final DateTime changedAt;
  final String? ipAddress;

  BudgetAuditEntry({
    required this.id,
    required this.budgetId,
    required this.operationType,
    required this.userId,
    this.oldData,
    this.newData,
    required this.changedAt,
    this.ipAddress,
  });
}

class BudgetNote {
  final String id;
  final String category;
  final String academicYear;
  final String notes;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetNote({
    required this.id,
    required this.category,
    required this.academicYear,
    required this.notes,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });
}

class BudgetForecast {
  final double currentMonthlyBurn;
  final double projectedEndOfYear;
  final double remainingPeriodMonths;
  final double expectedUtilizationPercent;
  final bool isOnTrack;

  BudgetForecast({
    required this.currentMonthlyBurn,
    required this.projectedEndOfYear,
    required this.remainingPeriodMonths,
    required this.expectedUtilizationPercent,
    required this.isOnTrack,
  });
}

enum TimePeriod { monthly, quarterly, yearly }
enum FiscalYearRange { current, previous, both, custom }

// Helper class for PDF KPIs
class BudgetKPI {
  final String label;
  final String value;
  final String status; // 'critical', 'warning', 'healthy'

  BudgetKPI({required this.label, required this.value, required this.status});
}

// Helper class for PDF category data
class BudgetCategory {
  final String category;
  final double planned;
  final double actual;
  double get utilization => planned > 0 ? actual / planned : 0;

  BudgetCategory({required this.category, required this.planned, required this.actual});
}
