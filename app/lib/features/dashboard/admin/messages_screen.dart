import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/self_children_provider.dart';
import '../../../core/auth/self_record_provider.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/warm_backdrop.dart';

enum _MessageFilterTab { inbox, sent }

/// Messaging screen supporting flat 1:1 messaging across staff, students, and parents.
///
/// Features:
/// - Distinct Inbox (received) and Sent (sent by user) views with real-time counts.
/// - Live recipient search & filtering during message composition.
/// - "Delete for me" (user-side deletion) persisted per authenticated user.
/// - Automatic refresh and immediate display of sent messages.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  late Future<_MessagesData> _future;
  int _loadGeneration = 0;
  _MessageFilterTab _currentTab = _MessageFilterTab.inbox;
  String _messageSearchQuery = '';
  Set<String> _deletedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String _getDeletedPrefsKey(String? authUid) {
    return 'deleted_messages_${authUid ?? 'anonymous'}';
  }

  Future<void> _loadDeletedMessageIds(String? authUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getDeletedPrefsKey(authUid);
      final list = prefs.getStringList(key) ?? [];
      _deletedMessageIds = list.toSet();
    } catch (_) {}
  }

  Future<void> _deleteMessageForUser(String messageId, String? authUid, String tabName) async {
    setState(() {
      _deletedMessageIds.add(messageId);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getDeletedPrefsKey(authUid);
      await prefs.setStringList(key, _deletedMessageIds.toList());
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message deleted from your $tabName.'),
        backgroundColor: AppColors.textPrimary,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFFFFC700),
          onPressed: () async {
            setState(() {
              _deletedMessageIds.remove(messageId);
            });
            try {
              final prefs = await SharedPreferences.getInstance();
              final key = _getDeletedPrefsKey(authUid);
              await prefs.setStringList(key, _deletedMessageIds.toList());
            } catch (_) {}
          },
        ),
      ),
    );
  }

  Future<_MessagesData> _load() async {
    final client = ref.read(supabaseClientProvider);
    final user = client.auth.currentUser;
    final selfStaffId = await ref.read(selfStaffIdProvider.future);
    final selfStudentId = await ref.read(selfStudentIdProvider.future);
    final role = ref.read(userRoleProvider);

    await _loadDeletedMessageIds(user?.id);

    // ── 1. Name Lookups ──
    final staffRows = await client.schema('public').from('staff').select('id, full_name, role');
    final allStaff = List<Map<String, dynamic>>.from(staffRows as List);
    final staffNameById = {for (final s in allStaff) s['id'] as String: s['full_name'] as String};

    final studentRows = await client.schema('public').from('students').select('id, full_name');
    final allStudents = List<Map<String, dynamic>>.from(studentRows as List);
    final studentNameById = {for (final s in allStudents) s['id'] as String: s['full_name'] as String};

    // ── 2. Messages (Both Sent and Received) ──
    List<Map<String, dynamic>> allMessages = [];

    if (selfStaffId != null) {
      final rows = await client
          .schema('communications')
          .from('messages')
          .select('id, sender_staff_id, sender_student_id, recipient_staff_id, recipient_student_id, body, created_at')
          .or('recipient_staff_id.eq.$selfStaffId,sender_staff_id.eq.$selfStaffId')
          .order('created_at', ascending: false);
      allMessages = List<Map<String, dynamic>>.from(rows as List);
    } else if (selfStudentId != null) {
      final rows = await client
          .schema('communications')
          .from('messages')
          .select('id, sender_staff_id, sender_student_id, recipient_staff_id, recipient_student_id, body, created_at')
          .or('recipient_student_id.eq.$selfStudentId,sender_student_id.eq.$selfStudentId')
          .order('created_at', ascending: false);
      allMessages = List<Map<String, dynamic>>.from(rows as List);
    } else if (role == UserRole.parent) {
      final children = await ref.read(selfChildrenProvider.future);
      if (children.isNotEmpty) {
        final childIds = children.map((c) => c.studentId).toList();
        final childIdFilter = childIds.join(',');
        final rows = await client
            .schema('communications')
            .from('messages')
            .select('id, sender_staff_id, sender_student_id, recipient_staff_id, recipient_student_id, body, created_at')
            .or('recipient_student_id.in.($childIdFilter),sender_student_id.in.($childIdFilter)')
            .order('created_at', ascending: false);
        allMessages = List<Map<String, dynamic>>.from(rows as List);
      }
    } else if (role == UserRole.admin || role == UserRole.principal) {
      final rows = await client
          .schema('communications')
          .from('messages')
          .select('id, sender_staff_id, sender_student_id, recipient_staff_id, recipient_student_id, body, created_at')
          .order('created_at', ascending: false);
      allMessages = List<Map<String, dynamic>>.from(rows as List);
    }

    // ── 3. Recipient lists by role ──
    List<Map<String, dynamic>> teacherStudents = [];
    List<Map<String, dynamic>> staffList = [];
    List<Map<String, dynamic>> parentRecipients = [];
    String? parentSenderStudentId;

    if (role == UserRole.parent) {
      final children = await ref.read(selfChildrenProvider.future);
      final recipientIds = <String>{};
      for (final s in allStaff) {
        final r = s['role'] as String?;
        if (r == 'principal' || r == 'admin') recipientIds.add(s['id'] as String);
      }

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
      if (children.isNotEmpty) parentSenderStudentId = children.first.studentId;
    } else if (selfStaffId != null) {
      final tts = await client
          .schema('scheduling')
          .from('timetable')
          .select('class_id')
          .eq('teacher_id', selfStaffId);
      final classIds = (tts as List)
          .map((t) => t['class_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final ctClasses = await client
          .schema('academic')
          .from('classes')
          .select('id')
          .eq('class_teacher_id', selfStaffId);
      for (final c in ctClasses as List) {
        final cid = c['id'] as String?;
        if (cid != null && cid.isNotEmpty) classIds.add(cid);
      }

      if (classIds.isNotEmpty) {
        final rosterRows = await client
            .schema('academic')
            .from('class_roster')
            .select('student_id, class_id')
            .inFilter('class_id', classIds.toList());
        final studentIds = (rosterRows as List).map((r) => r['student_id'] as String).toList();
        final classIdByStudent = {for (final r in rosterRows as List) r['student_id'] as String: r['class_id'] as String};

        if (studentIds.isNotEmpty) {
          final studentRows = await client
              .schema('public')
              .from('students')
              .select('id, full_name')
              .inFilter('id', studentIds)
              .order('full_name');

          final classRows = await client
              .schema('academic')
              .from('classes')
              .select('id, name')
              .inFilter('id', classIds.toList());
          final classNameById = {for (final c in classRows as List) c['id'] as String: c['name'] as String};

          teacherStudents = (studentRows as List).map((s) {
            final sid = s['id'] as String;
            final cid = classIdByStudent[sid];
            final cName = cid != null ? classNameById[cid] : null;
            return {
              'id': sid,
              'full_name': cName != null ? '${s['full_name']} ($cName)' : s['full_name'],
            };
          }).toList();
        }
      } else if (role == UserRole.teacher) {
        final rosterRows = await client
            .schema('academic')
            .from('class_roster')
            .select('student_id, class_id')
            .limit(50);
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
      staffList = allStaff;
    } else {
      staffList = allStaff;
    }

    return _MessagesData(
      selfStaffId: selfStaffId,
      selfStudentId: selfStudentId,
      authUserId: user?.id,
      messages: allMessages,
      staffNameById: staffNameById,
      studentNameById: studentNameById,
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
    String? parentSenderStudentId,
  }) async {
    final client = ref.read(supabaseClientProvider);
    try {
      final rows = <Map<String, dynamic>>[];
      for (final rid in recipientIds) {
        rows.add({
          if (selfStaffId != null) 'sender_staff_id': selfStaffId,
          if (parentSenderStudentId != null) 'sender_student_id': parentSenderStudentId,
          if (selfStudentId != null && selfStaffId == null) 'sender_student_id': selfStudentId,
          if (recipientsAreStudents) 'recipient_student_id': rid else 'recipient_staff_id': rid,
          'body': body,
        });
      }
      await client.schema('communications').from('messages').insert(rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to ${recipientIds.length} recipient(s).'), backgroundColor: AppColors.success),
      );
      setState(() {
        _currentTab = _MessageFilterTab.sent;
        _loadGeneration++;
        _future = _load();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showComposeSheet({
    required List<Map<String, dynamic>> recipientList,
    required String? selfStaffId,
    required String? selfStudentId,
    required bool recipientsAreStudents,
    String? parentSenderStudentId,
    required UserRole role,
  }) {
    if (recipientList.isEmpty) return;
    final selectedIds = <String>{};
    final bodyController = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredList = recipientList.where((r) {
            final name = (r['full_name'] as String? ?? '').toLowerCase();
            return name.contains(searchQuery.toLowerCase().trim());
          }).toList();

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('New Message', style: Theme.of(context).textTheme.titleLarge),
                      if (selectedIds.isNotEmpty)
                        GlassChip(
                          label: '${selectedIds.length} selected',
                          color: role.accentOnLight,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipientsAreStudents
                        ? 'Select one or more students (your classes)'
                        : parentSenderStudentId != null
                            ? 'Select recipients (class teacher, Principal, Admin)'
                            : 'Select one or more recipients',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),

                  // Search bar for recipients
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search recipient name or class...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setModalState(() => searchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) => setModalState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 10),

                  // Quick selection actions
                  if (filteredList.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filteredList.length} matching',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  for (final r in filteredList) {
                                    selectedIds.add(r['id'] as String);
                                  }
                                });
                              },
                              child: const Text('Select All', style: TextStyle(fontSize: 12)),
                            ),
                            if (selectedIds.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    selectedIds.clear();
                                  });
                                },
                                child: const Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.error)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),

                  // Recipient Chips list
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: filteredList.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('No matching recipients found.', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: filteredList.map((r) {
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
                                  selectedColor: role.accentSoft,
                                  labelStyle: TextStyle(
                                    color: isSelected ? role.accentOnLight : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                  backgroundColor: AppColors.backgroundAlt,
                                  side: BorderSide(
                                    color: isSelected ? role.accentOnLight : AppColors.glassBorder,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: bodyController,
                    decoration: const InputDecoration(labelText: 'Message body'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),
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
                    child: Text('Send to ${selectedIds.length} recipient${selectedIds.length == 1 ? '' : 's'}'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return DateFormat('h:mm a').format(dt);
      }
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  bool _isSentMessage(Map<String, dynamic> m, _MessagesData data) {
    if (data.selfStaffId != null && m['sender_staff_id'] == data.selfStaffId) {
      return true;
    }
    if (data.selfStudentId != null && m['sender_student_id'] == data.selfStudentId) {
      return true;
    }
    if (data.parentSenderStudentId != null && m['sender_student_id'] == data.parentSenderStudentId) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);

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

              // Filter out messages deleted on this user's device
              final visibleMessages = data.messages.where((m) => !_deletedMessageIds.contains(m['id'] as String)).toList();

              final inboxMessages = visibleMessages.where((m) => !_isSentMessage(m, data)).toList();
              final sentMessages = visibleMessages.where((m) => _isSentMessage(m, data)).toList();

              final activeList = _currentTab == _MessageFilterTab.inbox ? inboxMessages : sentMessages;

              final displayedMessages = activeList.where((m) {
                if (_messageSearchQuery.trim().isEmpty) return true;
                final q = _messageSearchQuery.toLowerCase();
                final body = (m['body'] as String? ?? '').toLowerCase();

                final senderName = m['sender_staff_id'] != null
                    ? (data.staffNameById[m['sender_staff_id']] ?? 'Staff')
                    : (data.studentNameById[m['sender_student_id']] ?? 'Student');
                final recipientName = m['recipient_staff_id'] != null
                    ? (data.staffNameById[m['recipient_staff_id']] ?? 'Staff')
                    : (data.studentNameById[m['recipient_student_id']] ?? 'Student');

                return body.contains(q) || senderName.toLowerCase().contains(q) || recipientName.toLowerCase().contains(q);
              }).toList();

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Messages', style: Theme.of(context).textTheme.headlineMedium),
                              if (data.staffList.isNotEmpty || data.teacherStudents.isNotEmpty || data.parentRecipients.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (role == UserRole.parent && data.parentRecipients.isNotEmpty) {
                                      _showComposeSheet(
                                        recipientList: data.parentRecipients,
                                        selfStaffId: data.selfStaffId,
                                        selfStudentId: data.selfStudentId,
                                        recipientsAreStudents: false,
                                        parentSenderStudentId: data.parentSenderStudentId,
                                        role: role,
                                      );
                                    } else if (role == UserRole.teacher || data.teacherStudents.isNotEmpty) {
                                      _showComposeSheet(
                                        recipientList: data.teacherStudents,
                                        selfStaffId: data.selfStaffId,
                                        selfStudentId: data.selfStudentId,
                                        recipientsAreStudents: true,
                                        role: role,
                                      );
                                    } else {
                                      _showComposeSheet(
                                        recipientList: data.staffList,
                                        selfStaffId: data.selfStaffId,
                                        selfStudentId: data.selfStudentId,
                                        recipientsAreStudents: false,
                                        role: role,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Compose'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Inbox vs Sent Segmented Switch
                          SegmentedButton<_MessageFilterTab>(
                            segments: [
                              ButtonSegment(
                                value: _MessageFilterTab.inbox,
                                icon: const Icon(Icons.inbox_outlined, size: 18),
                                label: Text('Inbox (${inboxMessages.length})'),
                              ),
                              ButtonSegment(
                                value: _MessageFilterTab.sent,
                                icon: const Icon(Icons.send_outlined, size: 18),
                                label: Text('Sent (${sentMessages.length})'),
                              ),
                            ],
                            selected: {_currentTab},
                            onSelectionChanged: (set) => setState(() => _currentTab = set.first),
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: role.accentSoft,
                              selectedForegroundColor: role.accentOnLight,
                              foregroundColor: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Search Bar
                          TextField(
                            decoration: InputDecoration(
                              hintText: _currentTab == _MessageFilterTab.inbox
                                  ? 'Search inbox messages...'
                                  : 'Search sent messages...',
                              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                              suffixIcon: _messageSearchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () => setState(() => _messageSearchQuery = ''),
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (val) => setState(() => _messageSearchQuery = val),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (displayedMessages.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentTab == _MessageFilterTab.inbox ? Icons.inbox_outlined : Icons.outgoing_mail,
                              size: 48,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _messageSearchQuery.isNotEmpty
                                  ? 'No messages match your search.'
                                  : _currentTab == _MessageFilterTab.inbox
                                      ? 'No received messages in your Inbox.'
                                      : 'No messages in your Sent folder yet.',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          displayedMessages.map((m) {
                            final isSent = _isSentMessage(m, data);
                            final messageId = m['id'] as String;

                            final otherPartyLabel = isSent ? 'To' : 'From';
                            final otherPartyName = isSent
                                ? (m['recipient_staff_id'] != null
                                    ? (data.staffNameById[m['recipient_staff_id']] ?? 'Staff')
                                    : (data.studentNameById[m['recipient_student_id']] ?? 'Student'))
                                : (m['sender_staff_id'] != null
                                    ? (data.staffNameById[m['sender_staff_id']] ?? 'Staff')
                                    : (data.studentNameById[m['sender_student_id']] ?? 'Student'));

                            final timeStr = _formatDate(m['created_at'] as String?);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isSent ? role.accentSoft : AppColors.backgroundAlt,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isSent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                            size: 18,
                                            color: isSent ? role.accentOnLight : AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: RichText(
                                                      text: TextSpan(
                                                        style: Theme.of(context).textTheme.titleMedium,
                                                        children: [
                                                          TextSpan(
                                                            text: '$otherPartyLabel: ',
                                                            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                                          ),
                                                          TextSpan(
                                                            text: otherPartyName,
                                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                                          ),
                                                        ],
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (timeStr.isNotEmpty)
                                                    Text(
                                                      timeStr,
                                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textSecondary),
                                          tooltip: 'Delete for me',
                                          splashRadius: 18,
                                          onPressed: () => _deleteMessageForUser(
                                            messageId,
                                            data.authUserId,
                                            isSent ? 'Sent list' : 'Inbox',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundAlt,
                                        borderRadius: BorderRadius.circular(AppRadii.input),
                                      ),
                                      child: Text(
                                        m['body'] as String? ?? '',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: AppColors.textPrimary,
                                              height: 1.4,
                                            ),
                                      ),
                                    ),
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
    required this.authUserId,
    required this.messages,
    required this.staffNameById,
    required this.studentNameById,
    required this.staffList,
    required this.teacherStudents,
    required this.parentRecipients,
    this.parentSenderStudentId,
  });

  final String? selfStaffId;
  final String? selfStudentId;
  final String? authUserId;
  final List<Map<String, dynamic>> messages;
  final Map<String, String> staffNameById;
  final Map<String, String> studentNameById;
  final List<Map<String, dynamic>> staffList;
  final List<Map<String, dynamic>> teacherStudents;
  final List<Map<String, dynamic>> parentRecipients;
  final String? parentSenderStudentId;
}
