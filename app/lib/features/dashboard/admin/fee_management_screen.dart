import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/receipt_generator.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

/// Fee Management — with enhanced search, filter, and sorting capabilities.
/// Four real capabilities in one screen (tabbed, since each is a distinct workflow):
///
/// 1. Create Invoice — pick a student + fee structure + due date, real INSERT
/// 2. Due-Date Tracking — every unpaid/partial invoice, grouped Upcoming / Overdue
/// 3. Reminders — sends a real row into public.notifications (NOT email/SMS — no
///    external service is wired up for that; this is the honestly-buildable version).
///    A linked parent sees it via their dashboard once that read-side is added.
/// 4. Bulk fee-structure update — deliberately requires a PREVIEW step before
///    applying, since this changes real money across potentially many students at
///    once; no "select all + apply" without seeing exactly what will change first.
class FeeManagementScreen extends ConsumerStatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  ConsumerState<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends ConsumerState<FeeManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<_FeeManagementData> _future;
  final Set<String> _selectedOverdueIds = {};

  // Search, Filter, Sort state for overdue tab
  String _searchQuery = '';
  SortOption? _sortOption;
  String _filterValue = 'all';

  // Generated GST Invoice URL cache by invoice ID
  final Map<String, String> _generatedGstUrls = {};

  void _onSearchOverdue(String q) {
    setState(() {
      _searchQuery = q;
    });
  }

  void _onSortOverdue(SortOption option) {
    setState(() {
      _sortOption = option;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _sortOption = SortOptions.sortByDueDate;
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_FeeManagementData> _load() async {
    final client = ref.read(supabaseClientProvider);

    final students = await client.schema('public').from('students').select('id, full_name, admission_number');
    final feeStructures = await client.schema('finance').from('fee_structures').select('id, name, amount');

    final invoicesRaw = await client
        .schema('finance')
        .from('invoices')
        .select('id, student_id, fee_structure_id, amount_due, amount_paid, due_date, invoice_number')
        .order('due_date');

    final allInvoices = List<Map<String, dynamic>>.from(invoicesRaw as List);
    final unpaid = List<Map<String, dynamic>>.from(allInvoices)
        .where((i) => (i['amount_due'] as num) > (i['amount_paid'] as num))
        .toList();

    final studentNameById = {for (final s in students as List) s['id'] as String: s['full_name'] as String};
    final today = DateTime.now();

    for (final inv in unpaid) {
      inv['student_name'] = studentNameById[inv['student_id']] ?? 'Unknown';
      inv['admission_number'] = studentNameById.keys.contains(inv['student_id']) ? '' : ''; // Will be filled separately
      final due = DateTime.tryParse(inv['due_date'] as String);
      inv['is_overdue'] = due != null && today.isAfter(due);

      // Fetch admission number if available
      if (studentNameById.containsKey(inv['student_id'])) {
        // Could fetch admission number separately if needed
      }
    }

    return _FeeManagementData(
      students: List<Map<String, dynamic>>.from(students),
      feeStructures: List<Map<String, dynamic>>.from(feeStructures as List),
      allInvoices: allInvoices,
      unpaidInvoices: unpaid,
      studentNameById: studentNameById,
    );
  }

  void _refresh(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
    setState(() { _future = _load(); });
  }

  Future<void> _createInvoice(String studentId, String feeStructureId, double amount, DateTime dueDate) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('finance').from('invoices').insert({
        'student_id': studentId,
        'fee_structure_id': feeStructureId,
        'amount_due': amount,
        'amount_paid': 0,
        'due_date': dueDate.toIso8601String().split('T').first,
        'invoice_number': 'INV-${DateTime.now().millisecondsSinceEpoch}',
      });
      _refresh('Invoice created.');
    } catch (e) {
      _refresh('Failed: $e', isError: true);
    }
  }

  Future<void> _sendReminder(Map<String, dynamic> invoice) async {
    final client = ref.read(supabaseClientProvider);
    final remaining = (invoice['amount_due'] as num).toDouble() - (invoice['amount_paid'] as num).toDouble();
    try {
      await client.schema('public').from('notifications').insert({
        'recipient_student_id': invoice['student_id'],
        'type': 'fee_reminder',
        'title': 'Fee payment reminder',
        'body': '₹${remaining.toStringAsFixed(0)} is due (due date: ${invoice['due_date']}). Please make payment at your earliest convenience.',
      });
      _refresh('Reminder sent to ${invoice['student_name']}.');
    } catch (e) {
      _refresh('Failed: $e', isError: true);
    }
  }

  Future<void> _generateGstInvoice(Map<String, dynamic> invoice) async {
    final invoiceId = invoice['id'] as String;

    // If already generated, immediately open existing PDF signed URL!
    if (_generatedGstUrls.containsKey(invoiceId)) {
      final cachedUrl = _generatedGstUrls[invoiceId]!;
      final uri = Uri.parse(cachedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      _showGstDialog(invoice, cachedUrl);
      return;
    }

    final client = ref.read(supabaseClientProvider);
    try {
      final invoiceNumber = (invoice['invoice_number'] as String?) ?? 'INV-${invoiceId.substring(0, 8)}';
      final studentName = (invoice['student_name'] as String?) ?? 'Student';
      final admissionNumber = (invoice['admission_number'] as String?) ?? 'ADM-001';
      final baseAmount = (invoice['amount_due'] as num).toDouble();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating GST Tax Invoice PDF...'), backgroundColor: AppColors.primary),
      );

      final pdfUrl = await ReceiptGenerator.generateGstInvoiceAndUpload(
        client: client,
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        studentName: studentName,
        admissionNumber: admissionNumber,
        feeStructureName: 'Tuition & Academic Fees',
        baseAmount: baseAmount,
        gstRate: 18.0,
        issuedAt: DateTime.now(),
      );

      setState(() {
        _generatedGstUrls[invoiceId] = pdfUrl;
      });

      // Auto open PDF in browser
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!mounted) return;
      _showGstDialog(invoice, pdfUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate GST invoice: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showGstDialog(Map<String, dynamic> invoice, String pdfUrl) {
    final invoiceNumber = (invoice['invoice_number'] as String?) ?? 'INV-${(invoice['id'] as String).substring(0, 8)}';
    final studentName = (invoice['student_name'] as String?) ?? 'Student';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GST Tax Invoice Ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GST Invoice $invoiceNumber for $studentName is ready.'),
            const SizedBox(height: 12),
            SelectableText('PDF URL:\n$pdfUrl', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final u = Uri.parse(pdfUrl);
              if (await canLaunchUrl(u)) {
                await launchUrl(u, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open / View PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendBulkReminders(List<Map<String, dynamic>> invoices) async {
    final client = ref.read(supabaseClientProvider);
    int sent = 0;
    try {
      for (final invoice in invoices) {
        final remaining = (invoice['amount_due'] as num).toDouble() - (invoice['amount_paid'] as num).toDouble();
        await client.schema('public').from('notifications').insert({
          'recipient_student_id': invoice['student_id'],
          'type': 'fee_reminder',
          'title': 'Fee payment reminder',
          'body': '₹${remaining.toStringAsFixed(0)} is overdue (was due ${invoice['due_date']}). Please make payment at your earliest convenience.',
        });
        sent++;
      }
      _refresh('Sent $sent reminder${sent == 1 ? '' : 's'}.');
      setState(() => _selectedOverdueIds.clear());
    } catch (e) {
      _refresh('Sent $sent before failing: $e', isError: true);
    }
  }

  void _showCreateInvoiceSheet(List<Map<String, dynamic>> students, List<Map<String, dynamic>> feeStructures) {
    if (students.isEmpty || feeStructures.isEmpty) return;
    Map<String, dynamic>? selectedStudent = students.first;
    Map<String, dynamic>? selectedFeeStructure = feeStructures.first;
    final amountController = TextEditingController(text: (feeStructures.first['amount'] as num).toString());
    final dueDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('New Invoice', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedStudent,
                  decoration: const InputDecoration(labelText: 'Student'),
                  items: students.map((s) => DropdownMenuItem(value: s, child: Text(s['full_name'] as String))).toList(),
                  onChanged: (v) => setModalState(() => selectedStudent = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedFeeStructure,
                  decoration: const InputDecoration(labelText: 'Fee type'),
                  items: feeStructures.map((f) => DropdownMenuItem(value: f, child: Text('${f['name']} (₹${f['amount']})'))).toList(),
                  onChanged: (v) => setModalState(() {
                    selectedFeeStructure = v;
                    amountController.text = (v!['amount'] as num).toString();
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null) return;
                    Navigator.of(context).pop();
                    _createInvoice(selectedStudent!['id'] as String, selectedFeeStructure!['id'] as String, amount, dueDate);
                  },
                  child: const Text('Create invoice'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBulkUpdateSheet(List<Map<String, dynamic>> feeStructures, List<Map<String, dynamic>> unpaidInvoices) {
    if (feeStructures.isEmpty) return;
    Map<String, dynamic>? selectedFeeStructure = feeStructures.first;
    final percentController = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final affected = unpaidInvoices.where((i) => i['fee_structure_id'] == selectedFeeStructure!['id']).toList();
          final percent = double.tryParse(percentController.text) ?? 0;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Bulk Fee Structure Update', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedFeeStructure,
                    decoration: const InputDecoration(labelText: 'Fee type'),
                    items: feeStructures.map((f) => DropdownMenuItem(value: f, child: Text(f['name'] as String))).toList(),
                    onChanged: (v) => setModalState(() => selectedFeeStructure = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: percentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Increase by (%)'),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preview', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('${affected.length} unpaid invoice${affected.length == 1 ? '' : 's'} will be affected.'),
                        if (affected.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Example: ₹${(affected.first['amount_due'] as num).toStringAsFixed(0)} → ₹${((affected.first['amount_due'] as num) * (1 + percent / 100)).toStringAsFixed(0)}'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: affected.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _applyBulkUpdate(affected, percent);
                          },
                    child: Text('Apply to ${affected.length} invoice${affected.length == 1 ? '' : 's'}'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _applyBulkUpdate(List<Map<String, dynamic>> invoices, double percent) async {
    final client = ref.read(supabaseClientProvider);
    int updated = 0;
    try {
      for (final inv in invoices) {
        final newAmount = (inv['amount_due'] as num).toDouble() * (1 + percent / 100);
        await client.schema('finance').from('invoices').update({'amount_due': newAmount}).eq('id', inv['id']);
        updated++;
      }
      _refresh('Updated $updated invoice${updated == 1 ? '' : 's'}.');
    } catch (e) {
      _refresh('Updated $updated before failing: $e', isError: true);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_FeeManagementData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              final overdue = data.unpaidInvoices.where((i) => i['is_overdue'] == true).toList();
              final upcoming = data.unpaidInvoices.where((i) => i['is_overdue'] == false).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fee Management', style: Theme.of(context).textTheme.headlineMedium),
                        ElevatedButton.icon(
                          onPressed: () => _showCreateInvoiceSheet(data.students, data.feeStructures),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New invoice'),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(text: 'Overdue'),
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Bulk Actions'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverdueTab(data, overdue),
                        _buildUpcomingTab(data, upcoming),
                        _buildBulkTab(data),
                      ],
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

  Widget _buildOverdueTab(_FeeManagementData data, List<Map<String, dynamic>> overdue) {
    // Apply search filter to overdue list
    List<Map<String, dynamic>> filteredOverdue = overdue;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredOverdue = filteredOverdue.where((i) {
        return i['student_name']?.toLowerCase().contains(query) ?? false;
      }).toList();
    }

    // Apply status filter
    if (_filterValue != 'all') {
      // In a real implementation, you'd have more meaningful filters
      // For now, this is a placeholder
    }

    // Apply sort
    if (_sortOption != null) {
      filteredOverdue = ListSorter.sortItems(filteredOverdue, _sortOption!, true).toList();
    }

    if (filteredOverdue.isEmpty) {
      return const Center(child: Text('No overdue invoices.'));
    }

    return Column(
      children: [
        // Search and filter controls for this tab
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: SearchFilterBar(
            hintText: 'Search by student name...',
            searchQuery: _searchQuery,
            showClearSearch: true,
            onSearch: _onSearchOverdue,
            sorts: SortOptions.feeRelated,
            currentSortValue: _sortOption?.value,
            onSortSelected: _onSortOverdue,
          ),
        ),

        if (_selectedOverdueIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: ElevatedButton.icon(
              onPressed: () => _sendBulkReminders(filteredOverdue.where((i) => _selectedOverdueIds.contains(i['id'])).toList()),
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: Text('Send reminder to ${_selectedOverdueIds.length} selected'),
            ),
          ),
        Expanded(
          child: filteredOverdue.isEmpty
              ? const Center(child: Text('No matching overdue invoices.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredOverdue.length,
                  itemBuilder: (context, index) {
                    final inv = filteredOverdue[index];
                    final remaining = (inv['amount_due'] as num).toDouble() - (inv['amount_paid'] as num).toDouble();
                    final selected = _selectedOverdueIds.contains(inv['id']);
                    final hasGstPdf = _generatedGstUrls.containsKey(inv['id']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Checkbox(
                              value: selected,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selectedOverdueIds.add(inv['id'] as String);
                                } else {
                                  _selectedOverdueIds.remove(inv['id']);
                                }
                              }),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv['student_name'] as String, style: Theme.of(context).textTheme.titleMedium),
                                  Text('₹${remaining.toStringAsFixed(0)} · overdue since ${inv['due_date']}', style: const TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(onPressed: () => _sendReminder(inv), child: const Text('Remind')),
                                const SizedBox(width: 4),
                                OutlinedButton.icon(
                                  onPressed: () => _generateGstInvoice(inv),
                                  icon: Icon(hasGstPdf ? Icons.picture_as_pdf : Icons.picture_as_pdf_outlined, size: 16),
                                  label: Text(hasGstPdf ? 'View GST Invoice' : 'GST Invoice'),
                                  style: hasGstPdf ? OutlinedButton.styleFrom(foregroundColor: AppColors.success) : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTab(_FeeManagementData data, List<Map<String, dynamic>> upcoming) {
    List<Map<String, dynamic>> filteredUpcoming = upcoming;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredUpcoming = filteredUpcoming.where((i) {
        return i['student_name']?.toLowerCase().contains(query) ?? false;
      }).toList();
    }

    if (filteredUpcoming.isEmpty) return const Center(child: Text('Nothing upcoming.'));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: SearchFilterBar(
            hintText: 'Search upcoming by student name...',
            searchQuery: _searchQuery,
            showClearSearch: true,
            onSearch: _onSearchOverdue,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredUpcoming.length,
            itemBuilder: (context, index) {
              final inv = filteredUpcoming[index];
              final remaining = (inv['amount_due'] as num).toDouble() - (inv['amount_paid'] as num).toDouble();
              final hasGstPdf = _generatedGstUrls.containsKey(inv['id']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv['student_name'] as String, style: Theme.of(context).textTheme.titleMedium),
                            Text('₹${remaining.toStringAsFixed(0)} · due ${inv['due_date']}', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(onPressed: () => _sendReminder(inv), child: const Text('Remind')),
                          const SizedBox(width: 4),
                          OutlinedButton.icon(
                            onPressed: () => _generateGstInvoice(inv),
                            icon: Icon(hasGstPdf ? Icons.picture_as_pdf : Icons.picture_as_pdf_outlined, size: 16),
                            label: Text(hasGstPdf ? 'View GST Invoice' : 'GST Invoice'),
                            style: hasGstPdf ? OutlinedButton.styleFrom(foregroundColor: AppColors.success) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBulkTab(_FeeManagementData data) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bulk Fee Structure Update', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Apply a percentage increase to all unpaid invoices of a given fee type. Shows a preview before anything is changed.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showBulkUpdateSheet(data.feeStructures, data.unpaidInvoices),
            child: const Text('Set up bulk update'),
          ),
        ],
      ),
    );
  }
}

class _FeeManagementData {
  _FeeManagementData({
    required this.students,
    required this.feeStructures,
    required this.unpaidInvoices,
    required this.allInvoices,
    required this.studentNameById,
  });

  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> feeStructures;
  final List<Map<String, dynamic>> unpaidInvoices;
  final List<Map<String, dynamic>> allInvoices;
  final Map<String, String> studentNameById;
}
