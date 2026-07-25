import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Simple messaging — flat 1:1 (communications.messages has no threading), works for
/// both staff and student accounts by checking self_staff_id/self_student_id and
/// querying whichever applies. Shows inbox (received) and lets you compose to any
/// staff member (kept simple — staff-only recipients for this first version, since a
/// combined staff+student recipient picker adds real UI complexity for a feature
/// that's explicitly the simplest item in tonight's batch).
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  late Future<_MessagesData> _future;
  int _loadGeneration = 0; // bumped each time we reload, used as FutureBuilder key

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MessagesData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    final selfStudentId = await ref.read(selfStudentIdProvider.future);

    List<Map<String, dynamic>> messages = [];
    if (selfStaffId != null) {
      final rows = await client.schema('communications').from('messages').select('id, sender_staff_id, sender_student_id, body, created_at').eq('recipient_staff_id', selfStaffId).order('created_at', ascending: false);
      messages = List<Map<String, dynamic>>.from(rows as List);
    } else if (selfStudentId != null) {
      final rows = await client.schema('communications').from('messages').select('id, sender_staff_id, sender_student_id, body, created_at').eq('recipient_student_id', selfStudentId).order('created_at', ascending: false);
      messages = List<Map<String, dynamic>>.from(rows as List);
    }

    final staff = await client.schema('public').from('staff').select('id, full_name');
    final staffNameById = {for (final s in staff as List) s['id'] as String: s['full_name'] as String};

    return _MessagesData(
      selfStaffId: selfStaffId,
      selfStudentId: selfStudentId,
      messages: messages,
      staffNameById: staffNameById,
      staffList: List<Map<String, dynamic>>.from(staff),
    );
  }

  Future<void> _send(List<String> recipientStaffIds, String body, String? selfStaffId, String? selfStudentId) async {
    final client = ref.read(supabaseClientProvider);
    try {
      final rows = <Map<String, dynamic>>[];
      for (final rid in recipientStaffIds) {
        rows.add({
          if (selfStaffId != null) 'sender_staff_id': selfStaffId,
          if (selfStudentId != null) 'sender_student_id': selfStudentId,
          'recipient_staff_id': rid,
          'body': body,
        });
      }
      debugPrint('[Messages] Sending to ${recipientStaffIds.length} recipients: $recipientStaffIds');
      await client.schema('communications').from('messages').insert(rows);
      debugPrint('[Messages] Insert succeeded.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to ${recipientStaffIds.length} recipient(s).'), backgroundColor: AppColors.success));
      setState(() { _loadGeneration++; _future = _load(); });
    } catch (e, stack) {
      debugPrint('[Messages] Send FAILED: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  void _showComposeSheet(List<Map<String, dynamic>> staffList, String? selfStaffId, String? selfStudentId) {
    if (staffList.isEmpty) return;
    final selectedIds = <String>{};
    final bodyController = TextEditingController();

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
                Text('New Message', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Select one or more recipients', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: staffList.map((s) {
                        final id = s['id'] as String;
                        final isSelected = selectedIds.contains(id);
                        return ChoiceChip(
                          label: Text(s['full_name'] as String),
                          selected: isSelected,
                          onSelected: (_) => setModalState(() {
                            if (isSelected) {
                              selectedIds.remove(id);
                            } else {
                              selectedIds.add(id);
                            }
                          }),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                          backgroundColor: AppColors.glassFill,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: bodyController, decoration: const InputDecoration(labelText: 'Message'), maxLines: 3),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (bodyController.text.trim().isEmpty || selectedIds.isEmpty) return;
                    Navigator.of(context).pop();
                    _send(selectedIds.toList(), bodyController.text.trim(), selfStaffId, selfStudentId);
                  },
                  child: const Text('Send'),
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
          child: FutureBuilder<_MessagesData>(
            key: ValueKey(_loadGeneration),
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load: ${snapshot.error}'));
              }
              final data = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Messages', style: Theme.of(context).textTheme.headlineMedium),
                          ElevatedButton.icon(
                            onPressed: () => _showComposeSheet(data.staffList, data.selfStaffId, data.selfStudentId),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Compose'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (data.messages.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No messages yet.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          data.messages.map((m) {
                            final senderName = m['sender_staff_id'] != null
                                ? (data.staffNameById[m['sender_staff_id']] ?? 'Unknown')
                                : 'A student';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(senderName, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(m['body'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
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

class _MessagesData {
  _MessagesData({
    required this.selfStaffId,
    required this.selfStudentId,
    required this.messages,
    required this.staffNameById,
    required this.staffList,
  });
  final String? selfStaffId;
  final String? selfStudentId;
  final List<Map<String, dynamic>> messages;
  final Map<String, String> staffNameById;
  final List<Map<String, dynamic>> staffList;
}
