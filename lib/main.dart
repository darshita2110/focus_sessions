import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_sessions/providers/core_providers.dart';
import 'package:focus_sessions/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FocusSessionsApp(),
    ),
  );
}

class FocusSessionsApp extends StatelessWidget {
  const FocusSessionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Focus Sessions',
      home: HomeScreen(),
    );
  }
}
