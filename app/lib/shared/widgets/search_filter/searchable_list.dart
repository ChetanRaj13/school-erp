import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../search_filter/search_filter_bar.dart';
import '../search_filter/utils.dart';

/// A generic data list component with built-in search, filter, and sort capabilities.
/// Ideal for any screen displaying large datasets like fees, approvals, vendors, etc.
class SearchableListScreen<T extends Map<String, dynamic>, C extends ConsumerStatefulWidget>
    extends ConsumerStatefulWidget {
  final String title;
  final String hintText;
  final Future<List<T>> Function() loadData;
  final ValueChanged<String>? onSearch;
  final List<FilterGroup>? initialFilterGroups;
  final List<SortOption> availableSorts;
  final Widget Function(BuildContext, T) buildItem;
  final List<String> searchFields;
  final FilterGroup? Function(FilterGroup?)? onFilterChange;
  final SortOption? Function(SortOption?)? onSortChange;
  final int itemsPerPage;
  final bool enablePagination;
  final VoidCallback? onRefresh;

  const SearchableListScreen({
    super.key,
    required this.title,
    required this.hintText,
    required this.loadData,
    this.onSearch,
    this.initialFilterGroups,
    required this.availableSorts,
    required this.buildItem,
    this.searchFields = const ['name', 'full_name', 'admission_number', 'status'],
    this.onFilterChange,
    this.onSortChange,
    this.itemsPerPage = 20,
    this.enablePagination = true,
    this.onRefresh,
  });

  @override
  ConsumerState<SearchableListScreen<T, C>> createState() => _SearchableListState<T, C>();
}

class _SearchableListState<T extends Map<String, dynamic>, C extends ConsumerStatefulWidget>
    extends ConsumerState<SearchableListScreen<T, C>> {
  List<T> _items = [];
  String _searchQuery = '';
  List<FilterGroup>? _filterGroups;
  SortOption? _sortOption;
  bool _ascending = true;
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filterGroups = widget.initialFilterGroups?.map((g) => FilterGroup(
      title: g.title,
      options: g.options,
      currentValue: g.currentValue,
    )).toList();
    _sortOption = widget.availableSorts.first;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_loading && _page > 1) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var rawItems = await widget.loadData();

      // Apply search filtering
      rawItems = ListSorter.filterByQuery(rawItems, _searchQuery, widget.searchFields);

      // Apply filter groups
      if (_filterGroups != null) {
        for (final group in _filterGroups!) {
          if (group.currentValue != null && group.currentValue != 'all') {
            rawItems = ListSorter.filterByOption(rawItems, group.currentValue!, group.options.firstWhere((o) => o.value == group.currentValue!).label);
          }
        }
      }

      // Apply sorting
      if (_sortOption != null) {
        rawItems = ListSorter.sortItems(rawItems, _sortOption!, _ascending);
      }

      // Pagination
      if (widget.enablePagination) {
        final start = (_page - 1) * widget.itemsPerPage;
        final end = start + widget.itemsPerPage;
        if (rawItems.length <= start) {
          _hasMore = false;
        } else {
          _items = List<T>.from(rawItems.sublist(start, end > rawItems.length ? rawItems.length : end));
        }
      } else {
        _items = rawItems;
        _hasMore = rawItems.length >= widget.itemsPerPage;
      }

      setState(() {
        _loading = false;
        _page++;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearch(String value) {
    if (!mounted) return;
    setState(() {
      _searchQuery = value;
      _page = 1;
      _items.clear;
    });
    _loadData();
  }

  void _onFilterChanged(FilterGroup group) {
    if (!mounted) return;
    setState(() {
      _filterGroups = _filterGroups?.map((g) =>
        g.title == group.title ? FilterGroup(title: g.title, options: g.options, currentValue: group.currentValue) : g,
      ).toList();
      _page = 1;
      _items.clear;
    });
    _loadData();
  }

  void _onSortChanged(SortOption option) {
    if (!mounted) return;
    setState(() {
      _sortOption = option;
      _ascending = !_ascending; // Toggle order on each change
      _items = ListSorter.sortItems(_items, option, _ascending);
    });
  }

  void _refresh() {
    setState(() {
      _page = 1;
      _items.clear;
      _hasMore = true;
    });
    _loadData();
  }

  Widget _buildHeader(BuildContext context) {
    return SearchFilterBar(
      title: widget.title,
      hintText: widget.hintText,
      onSearch: _searchQuery.isEmpty ? null : (value) => _onSearch(value),
      filterGroups: _filterGroups,
      onFilterChanged: (group) => _onFilterChanged(group),
      sorts: widget.availableSorts,
      onSortSelected: (option) => _onSortChanged(option),
      currentSortValue: _sortOption?.value,
      searchQuery: _searchQuery,
      showClearSearch: _searchQuery.isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error, size: 40),
                      const SizedBox(height: 16),
                      Text(_error!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_items.isEmpty && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('No items found.', style: Theme.of(context).textTheme.bodyMedium)),
                ),
              ),
            if (_loading && _items.isEmpty)
              SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            if (!_loading && _items.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Container(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: widget.buildItem(context, _items[index]),
                    ),
                    childCount: _items.length,
                  ),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: double.infinity,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                ),
              ),
            if (_hasMore && !_loading && widget.enablePagination)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Load More'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Extension methods for easier usage
