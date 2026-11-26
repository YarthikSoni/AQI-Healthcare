import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/home_shell.dart';

final prefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));
final baseUrlProvider = StateProvider<String>((ref) => kIsWeb
    ? 'http://127.0.0.1:8000/api/v1'
    : 'http://10.0.2.2:8000/api/v1');

class AQIApp extends ConsumerWidget {
  const AQIApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final theme = prefs.getString('theme') ?? 'system';
    final lang = prefs.getString('lang') ?? 'en';
    final mode = theme == 'dark'
        ? ThemeMode.dark
        : theme == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
    return MaterialApp(
      title: 'AQI Monitor',
      theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF4F6F82),
          scaffoldBackgroundColor: const Color(0xFFF7F8F6)),
      darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF91AABD),
          scaffoldBackgroundColor: const Color(0xFF171A1D)),
      themeMode: mode,
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('hi')],
      home: const HomeShell(),
    );
  }
}
