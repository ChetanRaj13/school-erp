import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'utils.dart';

/// A reusable search, filter, and sort bar component that provides consistent
/// UI across all list-based screens in the application.
class SearchFilterBar extends StatefulWidget {
  final String? title;
  final String hintText;
  final ValueChanged<String>? onSearch;
  final List<FilterGroup>? filterGroups;
  final ValueChanged<FilterGroup>? onFilterChanged;
  final List<SortOption>? sorts;
  final ValueChanged<SortOption>? onSortSelected;
  final String? currentFilterValue;
  final String? currentSortValue;
  final String? searchQuery;
  final bool showClearSearch;

  const SearchFilterBar({
    super.key,
    this.title,
    required this.hintText,
    this.onSearch,
    this.filterGroups,
    this.onFilterChanged,
    this.sorts,
    this.onSortSelected,
    this.currentFilterValue,
    this.currentSortValue,
    this.searchQuery,
    this.showClearSearch = false,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery ?? '');
  }

  @override
  void didUpdateWidget(SearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != null && widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showClearButton = widget.showClearSearch && (_controller.text.isNotEmpty) && widget.onSearch != null;
    final hasSorts = widget.sorts != null && widget.sorts!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              suffixIcon: (showClearButton || hasSorts)
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (showClearButton)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _controller.clear();
                              widget.onSearch?.call('');
                            },
                            splashRadius: 20,
                          ),
                        if (hasSorts) ...[
                          const SizedBox(width: 4),
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.glassFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<SortOption>(
                                value: widget.sorts!.firstWhere((s) => s.value == widget.currentSortValue, orElse: () => widget.sorts!.first),
                                items: widget.sorts!.map((sort) => DropdownMenuItem<SortOption>(
                                  value: sort,
                                  child: Text(sort.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                )).toList(),
                                onChanged: (value) => widget.onSortSelected?.call(value!),
                                style: TextStyle(color: AppColors.textPrimary),
                                icon: const Icon(Icons.tune_outlined, size: 16, color: AppColors.primary),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : null,
            ),
            onChanged: (val) {
              widget.onSearch?.call(val);
            },
          ),
          // Filter dropdowns
          if (widget.filterGroups != null && widget.filterGroups!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: _buildFilterRow(context, widget.filterGroups!),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFilterRow(BuildContext context, List<FilterGroup> groups) {
    return groups.map((group) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: _FilterDropdown(
        title: group.title,
        options: group.options,
        current: group.currentValue ?? group.options.first.value,
        onSelected: (value) {
          widget.onFilterChanged?.call(FilterGroup(
            title: group.title,
            options: group.options,
            currentValue: value,
          ));
        },
      ),
    )).toList();
  }
}

class _FilterDropdown extends StatelessWidget {
  final String title;
  final List<FilterOption> options;
  final String current;
  final Function(String) onSelected;

  const _FilterDropdown({required this.title, required this.options, required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final selected = options.firstWhere((f) => f.value == current, orElse: () => options.first);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: DropdownButton<FilterOption>(
        value: FilterOption(value: current, label: selected.label),
        items: options.map((filter) => DropdownMenuItem(
          value: filter,
          child: Text(filter.label),
        )).toList(),
        onChanged: (value) => onSelected(value!.value),
        isExpanded: true,
        style: TextStyle(color: AppColors.textPrimary),
        icon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final List<SortOption> sorts;
  final String? current;
  final ValueChanged<SortOption>? onSelected;

  const _SortDropdown({required this.sorts, this.current, this.onSelected});

  @override
  Widget build(BuildContext context) {
    final selected = sorts.firstWhere((s) => s.value == current, orElse: () => sorts.first);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: DropdownButton<SortOption>(
        value: selected,
        items: sorts.map((sort) => DropdownMenuItem(
          value: sort,
          child: Text(sort.label),
        )).toList(),
        onChanged: (value) => onSelected?.call(value!),
        isExpanded: true,
        style: TextStyle(color: AppColors.textPrimary),
        icon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}

/// A more advanced search filter bar that supports pagination and multiple data sources.
class AdvancedSearchFilterBar extends StatelessWidget {
  final String title;
  final String hintText;
  final ValueChanged<String>? onSearch;
  final List<FilterGroup>? filterGroups;
  final ValueChanged<FilterGroup>? onFilterChanged;
  final List<SortOption>? sorts;
  final ValueChanged<SortOption>? onSortSelected;
  final int? itemCount;
  final VoidCallback? onRefresh;
  final bool? showPagination;

  const AdvancedSearchFilterBar({
    super.key,
    required this.title,
    required this.hintText,
    this.onSearch,
    this.filterGroups,
    this.onFilterChanged,
    this.sorts,
    this.onSortSelected,
    this.itemCount,
    this.onRefresh,
    this.showPagination,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (showPagination ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Text('Items: ${itemCount ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: hintText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onChanged: onSearch,
                ),
              ),
              if (filterGroups != null && filterGroups!.isNotEmpty) ...[
                const SizedBox(width: 12),
                _BuildFilterDropdowns(filterGroups!),
              ]
            ],
          ),
          const SizedBox(height: 12),
          if (sorts != null && sorts!.isNotEmpty)
            _SortDropdown(sorts: sorts!, current: null, onSelected: onSortSelected),
          const SizedBox(height: 8),
          if (onRefresh != null)
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: onRefresh,
                child: Row(
                  children: [
                    const Icon(Icons.refresh_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    const Text('Refresh', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _BuildFilterDropdowns(List<FilterGroup> groups) {
    return Wrap(
      spacing: 8,
      children: groups.map((group) => FilterChip(
        label: Text(group.title),
        selected: false, // Simplified - would track selection state externally
        onSelected: (selected) {
          if (selected) {
            // Handle filter selection
          }
        },
      )).toList(),
    );
  }
}
