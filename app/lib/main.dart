import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const ProviderScope(child: SchoolErpApp()));
}

class SchoolErpApp extends StatelessWidget {
  const SchoolErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: swap MaterialApp -> MaterialApp.router once core/router.dart
    // (role-based routing: Principal/Admin/Teacher/Student/Parent) is built.
    return const MaterialApp(
      title: 'School ERP',
      home: Scaffold(
        body: Center(child: Text('School ERP — scaffold ready')),
      ),
    );
  }
}
