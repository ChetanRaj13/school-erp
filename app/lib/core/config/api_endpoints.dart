/// Compile-time endpoint config for the backend FastAPI microservices.
///
/// Mirrors the `Env` (lib/core/config/env.dart) convention: values are injected via
/// `--dart-define` at build/run time, with localhost defaults for local dev so the app
/// runs out-of-the-box against locally-started services. Nothing real is hardcoded here —
/// only dev defaults.
///
/// The Flutter app itself only ever holds the Supabase anon key (see env.dart's RLS note).
/// These endpoints point at the FastAPI services, which each hold the service-role key
/// server-side — the app never sees or sends the service-role key. The OMR /scan and
/// documents /commit endpoints do write to the DB, but through the *service's* service-
/// role client, not the app's anon client. This is the same separation already established
/// across services/timetable-solver, services/predictive-engine, etc.
///
/// Ports are the per-service defaults confirmed against each service's main.py:
///   OMR pipeline        -> 8002  (services/omr-pipeline/main.py)
///   Document extraction  -> 8003  (services/document-extraction/main.py)
///   Predictive engine    -> 8004  (services/predictive-engine/main.py)
/// (timetable-solver also runs 8003 in its docstring; that collision was flagged and the
/// services are started one at a time during dev, so it hasn't bitten us. Each port is
/// overridable via dart-define if a real collision needs resolving.)
class ApiEndpoints {
  static const _base = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost');
  static const _omrPort = int.fromEnvironment('OMR_PORT', defaultValue: 8002);
  static const _docPort = int.fromEnvironment('DOC_PORT', defaultValue: 8003);
  static const _predPort = int.fromEnvironment('PRED_PORT', defaultValue: 8004);

  static String get omrScan => '$_base:$_omrPort/scan';
  static String get docExtract => '$_base:$_docPort/documents/extract';
  static String get docCommit => '$_base:$_docPort/documents/commit';

  /// Health check for a given port — used by screens to confirm a service is actually up
  /// before attempting the real call, so a "service not started" shows as a friendly
  /// message instead of an opaque socket error.
  static String health(int port) => '$_base:$port/health';

  /// The raw port numbers, exposed so a screen can tell the user which port it's trying.
  static int get omrPort => _omrPort;
  static int get docPort => _docPort;
  static int get predictivePort => _predPort;
}
