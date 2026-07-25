import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// Resolves the signed-in user's OWN row in public.staff or public.students.
///
/// UPDATED: no longer always-null. supabase/migrations/0009_auth_linkage.sql has been
/// applied live (verified directly against the DB, not assumed) — both public.staff and
/// public.students now have a nullable auth_user_id column. This queries it for real.
///
/// Still returns null for any user who hasn't been linked yet by an admin (e.g. a brand
/// new signup with no staff/student row assigned) — that's correct, not a bug, and
/// TeacherDashboard/StudentDashboard already handle null by showing "account not linked".
final selfStaffIdProvider = FutureProvider<String?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .schema('public')
      .from('staff')
      .select('id')
      .eq('auth_user_id', session.user.id)
      .maybeSingle();

  return row?['id'] as String?;
});

final selfStudentIdProvider = FutureProvider<String?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .schema('public')
      .from('students')
      .select('id')
      .eq('auth_user_id', session.user.id)
      .maybeSingle();

  return row?['id'] as String?;
});
