import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Vendor/Procurement — lists real finance.vendors + finance.purchase_orders, lets an
/// admin add a vendor and create a new PO. Same deliberate pattern as PayrollScreen:
/// a new PO is created with status='pending_approval' and flows into the existing
/// ApprovalQueueScreen for the actual approve/reject decision — no duplicate approval
/// logic here.
class VendorProcurementScreen extends ConsumerStatefulWidget {
  const VendorProcurementScreen({super.key});

  @override
  ConsumerState<VendorProcurementScreen> createState() => _VendorProcurementScreenState();
}

class _VendorProcurementScreenState extends ConsumerState<VendorProcurementScreen> {
  late Future<_VendorData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_VendorData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final vendors = await client.schema('finance').from('vendors').select('id, name, contact_info');
    final orders = await client
        .schema('finance')
        .from('purchase_orders')
        .select('id, vendor_id, description, amount, status, category, created_at')
        .order('created_at', ascending: false);
    return _VendorData(
      vendors: List<Map<String, dynamic>>.from(vendors as List),
      orders: List<Map<String, dynamic>>.from(orders as List),
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

  void _refresh(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
    setState(() { _future = _load(); });
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
  }

  void _showAddVendorSheet() {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
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
              Text('New Vendor', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Vendor name')),
              const SizedBox(height: 12),
              TextField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact info')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  Navigator.of(context).pop();
                  _addVendor(nameController.text.trim(), contactController.text.trim());
                },
                child: const Text('Add vendor'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateOrderSheet(List<Map<String, dynamic>> vendors) {
    if (vendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a vendor first.'), backgroundColor: AppColors.warning),
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

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Vendors & Procurement', style: Theme.of(context).textTheme.headlineMedium),
                          Row(
                            children: [
                              OutlinedButton(onPressed: _showAddVendorSheet, child: const Text('+ Vendor')),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _showCreateOrderSheet(data.vendors),
                                child: const Text('+ Order'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Text('${data.vendors.length} vendors', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        ...data.vendors.map((v) => Padding(
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
                        if (data.orders.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No purchase orders yet.'))
                        else
                          ...data.orders.map((o) {
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
                                        Text('₹${(o['amount'] as num).toStringAsFixed(0)}',
                                            style: Theme.of(context).textTheme.titleMedium),
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
