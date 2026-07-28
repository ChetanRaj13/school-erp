import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

/// Simple messaging — flat 1:1 (communications.messages has no threading), works for
/// both staff and student accounts by checking self_staff_id / self_student_id.
///
/// Recipient list varies by sender role:
/// - Admin/principal: all staff members.
/// - Teacher: students in classes they actually teach (via timetable).
/// - Student: staff members only.
/// - Parent: ONLY class teacher(s) of linked child(ren), Principal, and Admin.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  late Future<_MessagesData> _future;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MessagesData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    final selfStudentId = await ref.read(selfStudentIdProvider.future);
    final role = ref.read(userRoleProvider);

    // ── Messages ──
    List<Map<String, dynamic>> messages = [];
    if (selfStaffId != null) {
      final rows = await client
          .schema('communications')
          .from('messages')
          .select('id, sender_staff_id, sender_student_id, body, created_at')
          .or('recipient_staff_id.eq.$selfStaffId,recipient_student_id.eq.$selfStaffId')
          .order('created_at', ascending: false);
      messages = List<Map<String, dynamic>>.from(rows as List);
    } else if (selfStudentId != null) {
      final rows = await client
          .schema('communications')
          .from('messages')
          .select('id, sender_staff_id, sender_student_id, body, created_at')
          .eq('recipient_student_id', selfStudentId)
          .order('created_at', ascending: false);
      messages = List<Map<String, dynamic>>.from(rows as List);
    } else if (role == UserRole.parent) {
      // Parent: messages sent by any of their linked children.
      final children = await ref.read(selfChildrenProvider.future);
      if (children.isNotEmpty) {
        final childIds = children.map((c) => c.studentId).toList();
        // Messages received BY the children (or sent by them).
        final rows = await client
            .schema('communications')
            .from('messages')
            .select('id, sender_staff_id, sender_student_id, recipient_staff_id, body, created_at')
            .inFilter('recipient_student_id', childIds)
            .order('created_at', ascending: false);
        messages = List<Map<String, dynamic>>.from(rows as List);
      }
    }

    // ── Recipient list ──
    List<Map<String, dynamic>> teacherStudents = [];
    List<Map<String, dynamic>> staffList = [];
    List<Map<String, dynamic>> parentRecipients = [];
    String? parentSenderStudentId;
    Map<String, String> staffNameById = {};

    // Always load staff (needed for sender name lookup and most recipient lists).
    final staffRows = await client.schema('public').from('staff').select('id, full_name, role');
    final allStaff = List<Map<String, dynamic>>.from(staffRows as List);
    staffNameById = {for (final s in allStaff) s['id'] as String: s['full_name'] as String};

    if (role == UserRole.parent) {
      // ── Parent: class teachers of linked children + Principal + Admin ──
      final children = await ref.read(selfChildrenProvider.future);
      final staffRoleById = {for (final s in allStaff) s['id'] as String: s['role'] as String};

      // Collect candidate IDs: Principal + Admin always.
      final recipientIds = <String>{};
      for (final s in allStaff) {
        final r = s['role'] as String?;
        if (r == 'principal' || r == 'admin') recipientIds.add(s['id'] as String);
      }

      // Resolve each child's class_teacher_id.
      for (final child in children) {
        final roster = await client
            .schema('academic')
            .from('class_roster')
            .select('class_id')
            .eq('student_id', child.studentId)
            .maybeSingle();
        if (roster == null) continue;
        final classId = roster['class_id'] as String?;
        if (classId == null) continue;

        final cls = await client
            .schema('academic')
            .from('classes')
            .select('class_teacher_id')
            .eq('id', classId)
            .maybeSingle();
        if (cls == null) continue;
        final classTeacherId = cls['class_teacher_id'] as String?;
        if (classTeacherId != null) recipientIds.add(classTeacherId);
      }

      parentRecipients = allStaff.where((s) => recipientIds.contains(s['id'])).toList();
      // Use the first linked child's student_id as the sender identity.
      if (children.isNotEmpty) parentSenderStudentId = children.first.studentId;
    } else if (selfStaffId != null) {
      // ── Staff member: check if they're a teacher with timetable entries ──
      final tts = await client
          .schema('scheduling')
          .from('timetable')
          .select('class_id')
          .eq('teacher_id', selfStaffId);
      final classIds = (tts as List).map((t) => t['class_id'] as String).where((id) => id.isNotEmpty).toSet().toList();

      if (classIds.isNotEmpty) {
        // Teacher with classes — show their students.
        final rosterRows = await client
            .schema('academic')
            .from('class_roster')
            .select('student_id')
            .inFilter('class_id', classIds);
        final studentIds = (rosterRows as List).map((r) => r['student_id'] as String).toList();

        if (studentIds.isNotEmpty) {
          final studentRows = await client
              .schema('public')
              .from('students')
              .select('id, full_name')
              .inFilter('id', studentIds)
              .order('full_name');
          teacherStudents = List<Map<String, dynamic>>.from(studentRows as List);
        }
      }

      // Fallback: all staff.
      staffList = allStaff;
    } else {
      // Student or unlinked user: all staff.
      staffList = allStaff;
    }

    return _MessagesData(
      selfStaffId: selfStaffId,
      selfStudentId: selfStudentId,
      messages: messages,
      staffNameById: staffNameById,
      staffList: staffList,
      teacherStudents: teacherStudents,
      parentRecipients: parentRecipients,
      parentSenderStudentId: parentSenderStudentId,
    );
  }

  Future<void> _send({
    required List<String> recipientIds,
    required String body,
    String? selfStaffId,
    String? selfStudentId,
    bool recipientsAreStudents = false,
    String? parentSenderStudentId, // when a parent sends, they use their child's student_id
  }) async {
    final client = ref.read(supabaseClientProvider);
    try {
      final rows = <Map<String, dynamic>>[];
      for (final rid in recipientIds) {
        rows.add({
          // Sender: staff/student/parent (parent uses their child's student_id).
          if (selfStaffId != null) 'sender_staff_id': selfStaffId,
          if (parentSenderStudentId != null) 'sender_student_id': parentSenderStudentId,
          if (selfStudentId != null && selfStaffId == null) 'sender_student_id': selfStudentId,
          // Recipient.
          if (recipientsAreStudents) 'recipient_student_id': rid else 'recipient_staff_id': rid,
          'body': body,
        });
      }
      debugPrint('[Messages] Sending to ${recipientIds.length} recipients: $recipientIds');
      await client.schema('communications').from('messages').insert(rows);
      debugPrint('[Messages] Insert succeeded.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to ${recipientIds.length} recipient(s).'), backgroundColor: AppColors.success),
      );
      setState(() { _loadGeneration++; _future = _load(); });
    } catch (e, stack) {
      debugPrint('[Messages] Send FAILED: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    }
  }

  void _showComposeSheet({
    required List<Map<String, dynamic>> recipientList,
    required String? selfStaffId,
    required String? selfStudentId,
    required bool recipientsAreStudents,
    String? parentSenderStudentId,
  }) {
    if (recipientList.isEmpty) return;
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
                Text(
                  recipientsAreStudents
                      ? 'Select one or more students (your classes only)'
                      : parentSenderStudentId != null
                          ? 'Select recipients (class teacher, Principal, Admin)'
                          : 'Select one or more recipients',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recipientList.map((r) {
                        final id = r['id'] as String;
                        final isSelected = selectedIds.contains(id);
                        return ChoiceChip(
                          label: Text(r['full_name'] as String),
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
                    _send(
                      recipientIds: selectedIds.toList(),
                      body: bodyController.text.trim(),
                      selfStaffId: selfStaffId,
                      selfStudentId: selfStudentId,
                      recipientsAreStudents: recipientsAreStudents,
                      parentSenderStudentId: parentSenderStudentId,
                    );
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
                          if (data.staffList.isNotEmpty || data.teacherStudents.isNotEmpty || data.parentRecipients.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () {
                                if (data.parentRecipients.isNotEmpty) {
                                  // Parent: use linked child's id as sender.
                                  _showComposeSheet(
                                    recipientList: data.parentRecipients,
                                    selfStaffId: data.selfStaffId,
                                    selfStudentId: data.selfStudentId,
                                    recipientsAreStudents: false,
                                    parentSenderStudentId: data.parentSenderStudentId,
                                  );
                                } else if (data.teacherStudents.isNotEmpty) {
                                  _showComposeSheet(
                                    recipientList: data.teacherStudents,
                                    selfStaffId: data.selfStaffId,
                                    selfStudentId: data.selfStudentId,
                                    recipientsAreStudents: true,
                                  );
                                } else {
                                  _showComposeSheet(
                                    recipientList: data.staffList,
                                    selfStaffId: data.selfStaffId,
                                    selfStudentId: data.selfStudentId,
                                    recipientsAreStudents: false,
                                  );
                                }
                              },
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
    required this.teacherStudents,
    required this.parentRecipients,
    this.parentSenderStudentId,
  });

  final String? selfStaffId;
  final String? selfStudentId;
  final List<Map<String, dynamic>> messages;
  final Map<String, String> staffNameById;
  final List<Map<String, dynamic>> staffList;
  final List<Map<String, dynamic>> teacherStudents;
  final List<Map<String, dynamic>> parentRecipients;

  /// For parent senders: the student_id of the first linked child, used as
  /// sender_student_id so the message row passes the FK+CHECK constraint.
  final String? parentSenderStudentId;
}
