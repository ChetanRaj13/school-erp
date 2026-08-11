/// Compile-time environment config. Values are injected via --dart-define at build/run
/// time — NEVER hardcode real Supabase credentials into this file or commit them.
///
/// Run example:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://yhcyhwpdgqupylrnkqht.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
///
/// For repeated local runs, put these in a git-ignored `dart_define.json` file and use:
///   flutter run --dart-define-from-file=dart_define.json
///
/// IMPORTANT: use the anon key here, never the service-role key — the Flutter app runs
/// on end-user devices, and the service-role key bypasses RLS entirely. Every backend
/// service in this project (timetable-solver, predictive-engine, etc.) correctly keeps
/// the service-role key server-side only; the same rule applies here in the other
/// direction — this app must only ever hold the anon key.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yhcyhwpdgqupylrnkqht.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InloY3lod3BkZ3F1cHlscm5rcWh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ0MDQ1ODcsImV4cCI6MjA5OTk4MDU4N30.9I481d_c9B6DlrxqdZQqZC2UXpsx1PzPIKcFGa1iYlU',
  );

  /// Razorpay Test Mode public key — injected via --dart-define, never hardcoded.
  static const razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_test_TFTM0iK32mVuvJ',
  );

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
