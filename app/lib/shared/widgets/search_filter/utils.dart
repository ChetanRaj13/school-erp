import 'package:flutter/material.dart';
import 'dart:async';

// ============================================================================
// Data Types for Search/Filter/Sort System
// ============================================================================

/// A filter option with a value and display label.
class FilterOption {
  final String value;
  final String label;

  const FilterOption({required this.value, required this.label});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FilterOption && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// A sort option with a field value, display label, and icon.
class SortOption {
  final String value;
  final String label;
  final IconData icon;

  const SortOption({required this.value, required this.label, required this.icon});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SortOption && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Represents a filter group - a named category with multiple options.
class FilterGroup {
  final String title;
  final List<FilterOption> options;
  final String? currentValue;

  const FilterGroup({
    required this.title,
    required this.options,
    this.currentValue,
  });
}

// ============================================================================
// Utilities
// ============================================================================

/// Utility functions for sorting lists based on SortOption definitions.
class ListSorter {
  /// Sorts a list of items by the specified field and order.
  /// Assumes items are Map<String, dynamic>.
  static List<T> sortItems<T extends Map<String, dynamic>>(
    List<T> items,
    SortOption sort,
    bool ascending,
  ) {
    if (items.isEmpty) return items;

    final sorted = List<T>.from(items);

    sorted.sort((a, b) {
      final valA = a[sort.value];
      final valB = b[sort.value];

      // Handle null values - put them at the end
      if (valA == null && valB == null) return 0;
      if (valA == null) return 1;
      if (valB == null) return -1;

      // Compare different types
      if (valA is String && valB is String) {
        return ascending ? valA.compareTo(valB) : valB.compareTo(valA);
      } else if (valA is num && valB is num) {
        return ascending ? valA.compareTo(valB) : valB.compareTo(valA);
      } else if (valA is DateTime && valB is DateTime) {
        return ascending ? valA.compareTo(valB) : valB.compareTo(valA);
      } else {
        // Fallback to string comparison
        return ascending ? valA.toString().compareTo(valB.toString()) : valB.toString().compareTo(valA.toString());
      }
    });

    return sorted;
  }

  /// Filters a list based on a search query across multiple fields.
  static List<T> filterByQuery<T extends Map<String, dynamic>>(
    List<T> items,
    String query,
    List<String> fields,
  ) {
    if (query.isEmpty) return items;

    final lowerQuery = query.toLowerCase();
    return items.where((item) {
      for (final field in fields) {
        final value = item[field];
        if (value != null && value.toString().toLowerCase().contains(lowerQuery)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  /// Filters a list based on a specific filter option.
  static List<T> filterByOption<T extends Map<String, dynamic>>(
    List<T> items,
    String filterField,
    String filterValue,
  ) {
    if (filterValue == 'all' || filterValue == '') return items;

    return items.where((item) {
      final itemValue = item[filterField]?.toString() ?? '';
      return itemValue == filterValue;
    }).toList();
  }

  /// Filters a list based on a status filter value.
  static List<Map<String, dynamic>> filterOption(List<Map<String, dynamic>> items, String filterValue, String label) {
    if (filterValue == 'all' || filterValue == '') return items;
    return items.where((item) {
      final itemValue = item['status']?.toString() ?? '';
      return itemValue == filterValue;
    }).toList();
  }
}

/// Common sort options used across the application.
class SortOptions {
  static const SortOption sortByName = SortOption(
    value: 'name',
    label: 'Name',
    icon: Icons.text_fields_outlined,
  );

  static const SortOption sortByAdmissionNumber = SortOption(
    value: 'admission_number',
    label: 'Admission Number',
    icon: Icons.text_format_outlined,
  );

  static const SortOption sortByDate = SortOption(
    value: 'created_at',
    label: 'Date',
    icon: Icons.calendar_month_outlined,
  );

  static const SortOption sortByDueDate = SortOption(
    value: 'due_date',
    label: 'Due Date',
    icon: Icons.calendar_today_outlined,
  );

  static const SortOption sortByStatus = SortOption(
    value: 'status',
    label: 'Status',
    icon: Icons.label_outlined,
  );

  static const SortOption sortByAmount = SortOption(
    value: 'amount',
    label: 'Amount',
    icon: Icons.attach_money_outlined,
  );

  static const SortOption sortByMethod = SortOption(
    value: 'method',
    label: 'Method',
    icon: Icons.payment_outlined,
  );

  static const List<SortOption> nameAndDate = [
    SortOptions.sortByName,
    SortOptions.sortByAdmissionNumber,
    SortOptions.sortByDate,
  ];

  static const List<SortOption> feeRelated = [
    SortOptions.sortByAmount,
    SortOptions.sortByDueDate,
    SortOptions.sortByDate,
  ];

  static const List<SortOption> allFields = [
    SortOptions.sortByName,
    SortOptions.sortByAdmissionNumber,
    SortOptions.sortByDate,
    SortOptions.sortByDueDate,
    SortOptions.sortByStatus,
    SortOptions.sortByAmount,
    SortOptions.sortByMethod,
  ];
}

/// Common filter options used across the application.
class FilterOptions {
  static const FilterOption filterAll = FilterOption(value: 'all', label: 'All');
  static const FilterOption filterPending = FilterOption(value: 'pending', label: 'Pending');
  static const FilterOption filterCompleted = FilterOption(value: 'completed', label: 'Completed');
  static const FilterOption filterOverdue = FilterOption(value: 'overdue', label: 'Overdue');
  static const FilterOption filterPartial = FilterOption(value: 'partial', label: 'Partial');
  static const FilterOption filterApproved = FilterOption(value: 'approved', label: 'Approved');
  static const FilterOption filterRejected = FilterOption(value: 'rejected', label: 'Rejected');
  static const FilterOption filterSubmitted = FilterOption(value: 'submitted', label: 'Submitted');

  // Fee-related filters
  static const FilterOption filterPaid = FilterOption(value: 'paid', label: 'Paid');
  static const FilterOption filterUnpaid = FilterOption(value: 'unpaid', label: 'Unpaid');
  static const FilterOption filterPastDue = FilterOption(value: 'past_due', label: 'Past Due');

  // Status-based filters for approval queue
  static const List<FilterOption> statusFilters = [filterAll, filterPending, filterApproved, filterRejected];

  // Payment status filters
  static const List<FilterOption> paymentStatusFilters = [filterAll, filterPaid, filterPending, filterOverdue, filterPartial];

  // Plan status filters
  static const List<FilterOption> planStatusFilters = [filterAll, FilterOption(value: 'active', label: 'Active'), FilterOption(value: 'requested', label: 'Requested')];

  // Invoice status filters
  static const List<FilterOption> invoiceStatusFilters = [filterAll, filterUnpaid, filterPaid];

  // Generic empty filter for screens without filters
  static const List<FilterOption> none = [filterAll];

  // PO status filters
  static const List<FilterOption> poStatusFilters = [
    filterAll,
    FilterOption(value: 'pending_approval', label: 'Pending Approval'),
    FilterOption(value: 'approved', label: 'Approved'),
    FilterOption(value: 'paid', label: 'Paid'),
    FilterOption(value: 'rejected', label: 'Rejected'),
  ];

  // Vendor performance filters
  static const List<FilterOption> vendorRatingFilters = [
    filterAll,
    FilterOption(value: 'high', label: 'High (80-100%)'),
    FilterOption(value: 'medium', label: 'Medium (50-79%)'),
    FilterOption(value: 'low', label: 'Low (<50%)'),
  ];
}

/// Debounce utility - returns a function that delays invocation until after
/// wait milliseconds have elapsed since it was last called.
class Debouncer {
  final Duration wait;
  Timer? _timer;

  Debouncer({this.wait = const Duration(milliseconds: 300)});

  VoidCallback apply(VoidCallback callback) {
    return () {
      if (_timer?.isActive ?? false) {
        _timer!.cancel();
      }
      _timer = Timer(wait, callback);
    };
  }

  void clear() {
    _timer?.cancel();
  }
}
