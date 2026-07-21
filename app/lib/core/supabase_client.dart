import 'package:supabase_flutter/supabase_flutter.dart';

/// Single shared Supabase client accessor.
/// Row Level Security on every table means this client is safe to use
/// directly from the UI layer — the DB enforces per-role visibility.
final supabase = Supabase.instance.client;
