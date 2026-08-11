import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';
import '../../../shared/widgets/search_filter/search_filter_bar.dart';
import '../../../shared/widgets/search_filter/utils.dart';

/// Vendor/Procurement — enhanced with search and filtering capabilities.
/// Lists real finance.vendors + finance.purchase_orders.
class VendorProcurementScreen extends ConsumerStatefulWidget {
  const VendorProcurementScreen({super.key});

  @override
  ConsumerState<VendorProcurementScreen> createState() => _VendorProcurementScreenState();
}

class _VendorProcurementScreenState extends ConsumerState<VendorProcurementScreen> {
  late Future<_VendorData> _future;

  // Search and filter state
  String _searchQuery = '';
  SortOption? _sortOption;

  @override
  void initState() {
    super.initState();
    _sortOption = SortOptions.sortByDate;
    _future = _load();
  }

  Future<void> _refresh([String? message]) async {
    setState(() { _future = _load(); });
    if (message != null) {
      _showSnack(message);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.error : AppColors.success),
    );
  }

  Future<_VendorData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final vendors = await client.schema('finance').from('vendors').select('id, name, contact_info');
    final orders = await client
        .schema('finance')
        .from('purchase_orders')
        .select('id, vendor_id, description, amount, status, category, created_at')
        .order('created_at', ascending: false);

    // Apply search filter to vendors
    List<Map<String, dynamic>> filteredVendors = List<Map<String, dynamic>>.from(vendors as List);
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredVendors = filteredVendors.where((v) => v['name']?.toLowerCase().contains(query) ?? false).toList();
    }

    // Apply sort to orders
    List<Map<String, dynamic>> filteredOrders = List<Map<String, dynamic>>.from(orders as List);
    if (_sortOption != null) {
      filteredOrders = ListSorter.sortItems(filteredOrders, _sortOption!, true).toList();
    }

    return _VendorData(
      vendors: filteredVendors,
      orders: filteredOrders,
    );
  }

  Future<void> _addVendor(String name, String contact) async {
    final client = ref.read(supabaseClientProvider);
    try {
      await client.schema('finance').from('vendors').insert({
        'school_id': '11111111-1111-1111-1111-111111111111',
        'name': name,
        'contact_info': contact,
      });
      _refresh('Vendor added.');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _createOrder(String vendorId, String description, double amount, String category) async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await client
        .schema('public')
        .from('staff')
        .select('id')
        .eq('auth_user_id', client.auth.currentUser?.id ?? '')
        .maybeSingle();

    try {
      await client.schema('finance').from('purchase_orders').insert({
        'school_id': '11111111-1111-1111-1111-111111111111',
        'vendor_id': vendorId,
        'description': description,
        'amount': amount,
        'category': category,
        'status': 'pending_approval',
        'requested_by': selfStaffId?['id'],
      });
      _refresh('Purchase order created — sent to Approval Queue.');
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
  }

  void _showCreateOrderSheet(List<Map<String, dynamic>> vendors) {
    if (vendors.isEmpty) {
      final nameController = TextEditingController();
      final contactController = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add New Vendor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Vendor Name')),
              const SizedBox(height: 8),
              TextField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact Info')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context);
                _addVendor(nameController.text.trim(), contactController.text.trim());
              },
              child: const Text('Add Vendor'),
            ),
          ],
        ),
      );
      return;
    }
    Map<String, dynamic>? selectedVendor = vendors.first;
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController(text: 'supplies');

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
                Text('New Purchase Order', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: selectedVendor,
                  decoration: const InputDecoration(labelText: 'Vendor'),
                  items: vendors.map((v) => DropdownMenuItem(value: v, child: Text(v['name'] as String))).toList(),
                  onChanged: (v) => setModalState(() => selectedVendor = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                ),
                const SizedBox(height: 12),
                TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: selectedVendor == null
                      ? null
                      : () {
                          final amount = double.tryParse(amountController.text);
                          if (amount == null || descriptionController.text.trim().isEmpty) return;
                          Navigator.of(context).pop();
                          _createOrder(
                            selectedVendor!['id'] as String,
                            descriptionController.text.trim(),
                            amount,
                            categoryController.text.trim(),
                          );
                        },
                  child: const Text('Create & Send for Approval'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FutureBuilder<_VendorData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showCreateOrderSheet(snapshot.data!.vendors),
            icon: const Icon(Icons.add),
            label: const Text('New Order'),
          );
        },
      ),
      body: WarmBackdrop(
        child: SafeArea(
          child: FutureBuilder<_VendorData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;
              final vendorNameById = {for (final v in data.vendors) v['id'] as String: v['name'] as String};

              var filteredVendors = data.vendors;
              var filteredOrders = data.orders;
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                filteredVendors = filteredVendors.where((v) {
                  final name = (v['name'] as String?)?.toLowerCase() ?? '';
                  final contact = (v['contact_info'] as String?)?.toLowerCase() ?? '';
                  return name.contains(query) || contact.contains(query);
                }).toList();

                filteredOrders = filteredOrders.where((o) {
                  final desc = (o['description'] as String?)?.toLowerCase() ?? '';
                  final cat = (o['category'] as String?)?.toLowerCase() ?? '';
                  final vName = (vendorNameById[o['vendor_id']] as String?)?.toLowerCase() ?? '';
                  return desc.contains(query) || cat.contains(query) || vName.contains(query);
                }).toList();
              }

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Vendors & Procurement', style: Theme.of(context).textTheme.headlineMedium),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: SearchFilterBar(
                        hintText: 'Search vendors or purchase orders...',
                        onSearch: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        sorts: [
                          SortOptions.sortByAmount,
                          SortOptions.sortByDate,
                        ],
                        currentSortValue: _sortOption?.value,
                        onSortSelected: (option) {
                          setState(() {
                            _sortOption = option;
                            _future = _load();
                          });
                        },
                      ),
                    ),
                  ),
                  if (data.vendors.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(padding: EdgeInsets.all(20), child: Text('No vendors yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Text('${filteredVendors.length} vendor${filteredVendors.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 8),
                          ...filteredVendors.map((v) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GlassCard(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(v['name'] as String, style: Theme.of(context).textTheme.titleMedium),
                                              if ((v['contact_info'] as String?)?.isNotEmpty ?? false)
                                                Text(v['contact_info'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                          const SizedBox(height: 20),
                          Text('Purchase Orders', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (filteredOrders.isEmpty)
                            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No matching purchase orders.'))
                          else
                            ...filteredOrders.map((o) {
                              final status = o['status'] as String;
                              final statusColor = switch (status) {
                                'paid' => AppColors.success,
                                'approved' => AppColors.primary,
                                'pending_approval' => AppColors.warning,
                                'rejected' => AppColors.error,
                                _ => AppColors.textSecondary,
                              };
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(o['description'] as String, style: Theme.of(context).textTheme.titleMedium),
                                            Text(
                                              '${vendorNameById[o['vendor_id']] ?? 'Unknown'} · ${o['category'] ?? 'uncategorized'}',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('₹${(o['amount'] as num).toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                                          GlassChip(label: status.replaceAll('_', ' '), color: statusColor),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ]),
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

class _VendorData {
  _VendorData({required this.vendors, required this.orders});

  final List<Map<String, dynamic>> vendors;
  final List<Map<String, dynamic>> orders;
}
