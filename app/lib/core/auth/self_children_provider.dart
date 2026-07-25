import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// Resolves the signed-in parent's linked children via public.parent_links — the table
/// added specifically to close this gap (see supabase migration applied live tonight).
/// Returns an empty list, not null, when nothing is linked yet — a parent with zero
/// linked children is a valid, expected state (nobody's added them yet), distinct from
/// "still loading" (AsyncLoading) or "not signed in" (empty list here too, harmless
/// since ParentDashboard only calls this when a session exists).
final selfChildrenProvider = FutureProvider<List<LinkedChild>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];

  final client = ref.watch(supabaseClientProvider);

  final links = await client
      .schema('public')
      .from('parent_links')
      .select('student_id, relationship')
      .eq('parent_auth_user_id', session.user.id);

  if ((links as List).isEmpty) return [];

  final studentIds = links.map((l) => l['student_id'] as String).toList();
  final students = await client
      .schema('public')
      .from('students')
      .select('id, full_name, admission_number')
      .inFilter('id', studentIds);

  final relationshipByStudentId = {
    for (final l in links) l['student_id'] as String: l['relationship'] as String,
  };

  return (students as List)
      .map((s) => LinkedChild(
            studentId: s['id'] as String,
            fullName: s['full_name'] as String,
            admissionNumber: s['admission_number'] as String,
            relationship: relationshipByStudentId[s['id']] ?? 'guardian',
          ))
      .toList();
});

class LinkedChild {
  LinkedChild({
    required this.studentId,
    required this.fullName,
    required this.admissionNumber,
    required this.relationship,
  });

  final String studentId;
  final String fullName;
  final String admissionNumber;
  final String relationship;
}
