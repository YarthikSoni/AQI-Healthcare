import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        DropdownButtonFormField<String>(
          initialValue: prefs.getString('theme') ?? 'system',
          items: const ['light', 'dark', 'system']
              .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) async {
            if (value != null) await prefs.setString('theme', value);
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: prefs.getString('lang') ?? 'en',
          items: const {'en': 'English', 'hi': 'हिन्दी'}
              .entries
              .map((entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ))
              .toList(),
          onChanged: (value) async {
            if (value != null) await prefs.setString('lang', value);
          },
        ),
        const SizedBox(height: 12),
        const Text('Backend URL: configured in app state'),
      ],
    );
  }
}
