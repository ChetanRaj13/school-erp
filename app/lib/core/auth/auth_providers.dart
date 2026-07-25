import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_role.dart';

/// The single Supabase client instance. Supabase.initialize() is called once in
/// main.dart before runApp — this provider just exposes the already-initialized
/// singleton, it does not create a new client.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Live auth state stream — emits on sign-in, sign-out, and token refresh. Everything
/// else (role, routing redirects) derives from this, so there is exactly one source of
/// truth for "is anyone logged in right now."
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// The current Supabase Session, or null if signed out. Convenience derivation from
/// authStateProvider so screens don't all need to unwrap AuthState themselves.
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.session ?? Supabase.instance.client.auth.currentSession;
});

/// Resolves the signed-in user's role.
///
/// ASSUMPTION (see README's "Auth ↔ domain data linkage" section for the full
/// explanation): role is expected in the user's app_metadata under the key 'role',
/// e.g. set via a Supabase Auth Hook or set manually per user in the Supabase
/// dashboard. This was NOT verified against a real configured auth hook — no such
/// hook exists yet in the live project as of this build. Per public.staff's RLS
/// policy (`school_id = auth.jwt() ->> 'school_id'`), the project already assumes
/// JWT custom claims are the intended mechanism — 'role' is added here following
/// that same established pattern, not invented independently.
final userRoleProvider = Provider<UserRole>((ref) {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return UserRole.unknown;
  final role = session.user.appMetadata['role'] as String?;
  return UserRole.fromString(role);
});

/// The school_id claim, same JWT-claim mechanism as role above. Needed for any
/// dashboard query that should be scoped to "this school" — though note RLS already
/// enforces this server-side; this is for client-side query filtering/display only,
/// never treat client-side use of this value as a security boundary by itself.
final schoolIdProvider = Provider<String?>((ref) {
  final session = ref.watch(currentSessionProvider);
  return session?.user.appMetadata['school_id'] as String?;
});
