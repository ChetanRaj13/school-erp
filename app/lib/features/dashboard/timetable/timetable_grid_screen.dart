import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

// Weekday constants shared across views.
const _dayCodes = ['mon', 'tue', 'wed', 'thu', 'fri'];
const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
const _periodCount = 6;

/// School-wide weekly timetable grid for admin/principal.
///
/// Two views:
///   - Whole School: per-class summary cards (filled/total slots, compact layout)
///   - By Class: class dropdown + clean weekly grid for one class
///
/// DATA LOADING — flat-fetch-and-join in Dart (same pattern as existing dashboard
/// screens). PostgREST cannot auto-resolve cross-schema foreign keys.
class TimetableGridScreen extends ConsumerStatefulWidget {
  const TimetableGridScreen({super.key});

  @override
  ConsumerState<TimetableGridScreen> createState() =>
      _TimetableGridScreenState();
}

class _TimetableGridScreenState extends ConsumerState<TimetableGridScreen> {
  // Tracks which view is active.
  bool _showWholeSchool = true;

  // Selected class ID for "By Class" view (null until data loads).
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseClientProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_TimetableData>(
            future: _loadTimetable(client),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load timetable:\n${snapshot.error}',
                        textAlign: TextAlign.center),
                  ),
                );
              }

              final data = snapshot.data!;

              // Auto-select first class for "By Class" view.
              if (_selectedClassId == null && data.classList.isNotEmpty) {
                _selectedClassId = data.classList.first.id;
              }

              return Column(
                children: [
                  _buildViewToggle(data),
                  Expanded(
                    child: data.timetableCount == 0
                        ? _EmptyState(hint: data.emptyHint)
                        : _showWholeSchool
                            ? _WholeSchoolView(data: data)
                            : _ByClassView(
                                data: data,
                                selectedClassId: _selectedClassId,
                                onClassChanged: (id) =>
                                    setState(() => _selectedClassId = id),
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

  Widget _buildViewToggle(_TimetableData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          ToggleButtons(
            isSelected: [_showWholeSchool, !_showWholeSchool],
            onPressed: (index) =>
                setState(() => _showWholeSchool = index == 0),
            borderRadius: BorderRadius.circular(12),
            constraints: const BoxConstraints(minWidth: 100, minHeight: 36),
            selectedColor: Colors.white,
            fillColor: AppColors.primary,
            children: [
              Text('Whole School',
                  style: TextStyle(
                      fontWeight:
                          _showWholeSchool ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
              Text('By Class',
                  style: TextStyle(
                      fontWeight:
                          !_showWholeSchool
                              ? FontWeight.bold
                              : FontWeight.normal,
                      fontSize: 13)),
            ],
          ),
          const Spacer(),
          Chip(
            label: Text('${data.placedCount}/${data.totalPossible} slots',
                style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<_TimetableData> _loadTimetable(SupabaseClient client) async {
    // One query per table — see class doc comment for why.
    final timetableRows = await client
        .schema('scheduling')
        .from('timetable')
        .select('id, teacher_id, subject_id, class_id, slot_id');

    final slotRows = await client
        .schema('scheduling')
        .from('time_slots')
        .select('id, day, period_number, start_time, end_time');

    final subjectRows = await client
        .schema('academic')
        .from('subjects')
        .select('id, name, periods_per_week');

    final classRows =
        await client.schema('academic').from('classes').select('id, name');

    final staffRows =
        await client.schema('public').from('staff').select('id, full_name');

    // Lookup maps.
    final slotById = {for (final s in slotRows) s['id'] as int: s};
    final subjectName = {
      for (final s in subjectRows)
        s['id'] as String: s['name'] as String? ?? '—'
    };
    final teacherName = {
      for (final t in staffRows) t['id'] as String: t['full_name'] as String? ?? '—'
    };

    // Grid: classId -> dayCode -> periodNumber -> cell.
    final gridByClass = <String, Map<String, Map<int, _Cell>>>{};
    // Per-class slot counts.
    final perClassTotal = <String, int>{};
    final perClassPlaced = <String, int>{};

    for (final cl in classRows) {
      gridByClass[cl['id'] as String] = {
        for (final d in _dayCodes) d: {},
      };
      perClassTotal[cl['id'] as String] = 0;
      perClassPlaced[cl['id'] as String] = 0;
    }

    // Compute total possible slots per class from subjects.
    for (final s in subjectRows) {
      final cid = s['class_id'] as String?;
      if (cid != null && perClassTotal.containsKey(cid)) {
        perClassTotal[cid] =
            (perClassTotal[cid] ?? 0) + (s['periods_per_week'] as int? ?? 0);
      }
    }

    int placed = 0;
    for (final row in timetableRows) {
      final slot = slotById[row['slot_id'] as int?];
      if (slot == null) continue;
      final day = slot['day'] as String?;
      final period = slot['period_number'] as int?;
      final cid = row['class_id'] as String?;
      if (day == null || period == null || cid == null) continue;
      if (!_dayCodes.contains(day)) continue;

      final classGrid = gridByClass[cid];
      if (classGrid == null) continue;

      classGrid[day]![period] = _Cell(
        subject: subjectName[row['subject_id'] as String?] ?? '—',
        teacher: teacherName[row['teacher_id'] as String?] ?? '—',
      );
      placed++;
      perClassPlaced[cid] = (perClassPlaced[cid] ?? 0) + 1;
    }

    // Total possible across all classes.
    final totalPossible =
        perClassTotal.values.fold(0, (a, b) => a + b);

    final classList = classRows
        .map((r) => _ClassInfo(
              id: r['id'] as String,
              name: r['name'] as String? ?? '—',
              placed: perClassPlaced[r['id'] as String] ?? 0,
              total: perClassTotal[r['id'] as String] ?? 0,
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final emptyHint = timetableRows.isEmpty
        ? 'No timetable rows returned. If you expected rows, this is likely '
            'the school-scoped RLS filter: your JWT must carry a matching '
            'school_id claim.'
        : null;

    return _TimetableData(
      gridByClass: gridByClass,
      classList: classList,
      timetableCount: timetableRows.length,
      placedCount: placed,
      totalPossible: totalPossible,
      emptyHint: emptyHint,
      subjectName: subjectName,
      teacherName: teacherName,
    );
  }
}

// ── Whole School View ────────────────────────────────────────────────

class _WholeSchoolView extends StatelessWidget {
  const _WholeSchoolView({required this.data});
  final _TimetableData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Class Overview', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: data.classList.map((cl) => _ClassCard(cl: cl)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.cl});
  final _ClassInfo cl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = cl.total > 0 ? cl.placed / cl.total : 0.0;
    return SizedBox(
      width: 160,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cl.name,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${cl.placed} / ${cl.total} slots',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_progressColor(fraction)),
            ),
          ),
          const SizedBox(height: 4),
          Text('${(fraction * 100).toInt()}% full',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      )),
    );
  }

  Color _progressColor(double f) {
    if (f >= 0.95) return Colors.green;
    if (f >= 0.7) return Colors.orange;
    return Colors.red;
  }
}

// ── By Class View ────────────────────────────────────────────────────

class _ByClassView extends StatelessWidget {
  const _ByClassView({
    required this.data,
    required this.selectedClassId,
    required this.onClassChanged,
  });

  final _TimetableData data;
  final String? selectedClassId;
  final ValueChanged<String> onClassChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class dropdown.
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedClassId,
              isExpanded: true,
              hint: const Text('Select a class'),
              items: data.classList
                  .map((cl) => DropdownMenuItem(
                        value: cl.id,
                        child: Text(cl.name,
                            style: theme.textTheme.titleMedium),
                      ))
                  .toList(),
              onChanged: (id) {
                if (id != null) onClassChanged(id);
              },
            ),
          ),
          const SizedBox(height: 16),
          // Weekly grid.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildGrid(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(ThemeData theme) {
    if (selectedClassId == null) {
      return const Center(child: Text('Select a class to view its timetable'));
    }

    final classGrid = data.gridByClass[selectedClassId];
    if (classGrid == null) return const SizedBox.shrink();

    const dayColumnWidth = 150.0;
    const periodColumnWidth = 56.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(dayColumnWidth),
          border: TableBorder.all(
            color: theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            // Header row.
            TableRow(
              children: [
                _headerCell(theme, 'Period', periodColumnWidth),
                for (final label in _dayLabels)
                  _headerCell(theme, label, dayColumnWidth),
              ],
            ),
            // One row per period.
            for (var p = 1; p <= _periodCount; p++)
              TableRow(
                children: [
                  _periodCell(theme, p),
                  for (final day in _dayCodes)
                    _slotCell(theme, classGrid[day]?[p]),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(ThemeData theme, String label, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Text(label,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
      ),
    );
  }

  Widget _periodCell(ThemeData theme, int period) {
    return SizedBox(
      width: 56,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Center(
          child: Text('$period',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _slotCell(ThemeData theme, _Cell? cell) {
    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: cell == null
            ? Center(
                child: Text('—',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cell.subject,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(cell.teacher,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hint});
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('No timetable rows to display.'),
            if (hint != null) ...[
              const SizedBox(height: 12),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data classes ─────────────────────────────────────────────────────

class _Cell {
  const _Cell({required this.subject, required this.teacher});
  final String subject;
  final String teacher;
}

class _ClassInfo {
  const _ClassInfo({
    required this.id,
    required this.name,
    required this.placed,
    required this.total,
  });
  final String id;
  final String name;
  final int placed;
  final int total;
}

class _TimetableData {
  _TimetableData({
    required this.gridByClass,
    required this.classList,
    required this.timetableCount,
    required this.placedCount,
    required this.totalPossible,
    required this.emptyHint,
    required this.subjectName,
    required this.teacherName,
  });

  final Map<String, Map<String, Map<int, _Cell>>> gridByClass;
  final List<_ClassInfo> classList;
  final int timetableCount;
  final int placedCount;
  final int totalPossible;
  final String? emptyHint;
  final Map<String, String> subjectName;
  final Map<String, String> teacherName;
}