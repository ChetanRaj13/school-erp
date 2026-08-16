import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

/// Student Library — the read-only counterpart to Teacher's Lesson Resources screen.
/// Same real table (academic.lesson_resources), filtered to whichever class this
/// student belongs to.
class StudentLibraryScreen extends ConsumerStatefulWidget {
  const StudentLibraryScreen({super.key});

  @override
  ConsumerState<StudentLibraryScreen> createState() => _StudentLibraryScreenState();
}

class _StudentLibraryScreenState extends ConsumerState<StudentLibraryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  // Search and Sort state
  String _searchQuery = '';
  SortOption _sortOption = const SortOption(value: 'date_desc', label: 'Date: Newest First', icon: Icons.calendar_today);

  static const _sortOptions = [
    SortOption(value: 'date_desc', label: 'Date: Newest First', icon: Icons.calendar_today),
    SortOption(value: 'date_asc', label: 'Date: Oldest First', icon: Icons.calendar_today_outlined),
    SortOption(value: 'title_asc', label: 'Title: A → Z', icon: Icons.sort_by_alpha),
    SortOption(value: 'title_desc', label: 'Title: Z → A', icon: Icons.sort_by_alpha),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStudentId = await ref.read(selfStudentIdProvider.future);
    if (selfStudentId == null) return [];

    final roster = await client.schema('academic').from('class_roster').select('class_id').eq('student_id', selfStudentId).maybeSingle();
    if (roster == null) return [];

    final resources = await client
        .schema('academic')
        .from('lesson_resources')
        .select('id, title, description, file_url, created_at')
        .eq('class_id', roster['class_id'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(resources as List);
  }

  List<Map<String, dynamic>> _applyFilterAndSort(List<Map<String, dynamic>> source) {
    var list = source.where((r) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (r['title'] as String? ?? '').toLowerCase();
        final desc = (r['description'] as String? ?? '').toLowerCase();
        if (!title.contains(q) && !desc.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sortOption.value) {
        case 'date_asc':
          final dA = a['created_at'] as String? ?? '';
          final dB = b['created_at'] as String? ?? '';
          return dA.compareTo(dB);
        case 'date_desc':
          final dA = a['created_at'] as String? ?? '';
          final dB = b['created_at'] as String? ?? '';
          return dB.compareTo(dA);
        case 'title_asc':
          return (a['title'] as String? ?? '').compareTo(b['title'] as String? ?? '');
        case 'title_desc':
          return (b['title'] as String? ?? '').compareTo(a['title'] as String? ?? '');
        default:
          return 0;
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final rawResources = snapshot.data!;
              final displayedList = _applyFilterAndSort(rawResources);

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text('Library', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: SearchFilterBar(
                        hintText: 'Search library resources...',
                        onSearch: (val) => setState(() => _searchQuery = val),
                        sorts: _sortOptions,
                        currentSortValue: _sortOption.value,
                        onSortSelected: (option) => setState(() => _sortOption = option),
                      ),
                    ),
                  ),
                  if (displayedList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No matching resources found.'
                              : 'No resources shared for your class yet.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          displayedList.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassCard(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.menu_book_outlined, color: AppColors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r['title'] as String, style: Theme.of(context).textTheme.titleMedium),
                                            if ((r['description'] as String?)?.isNotEmpty == true)
                                              Text(r['description'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                          ],
                                        ),
                                      ),
                                      if (r['file_url'] != null)
                                        IconButton(
                                          icon: const Icon(Icons.open_in_new, color: AppColors.primary),
                                          tooltip: 'Open resource',
                                          onPressed: () => launchUrl(Uri.parse(r['file_url'] as String), webOnlyWindowName: '_blank'),
                                        ),
                                    ],
                                  ),
                                ),
                              ))
                              .toList(),
                        ),
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
