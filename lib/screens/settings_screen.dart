// screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(context, 'settings'))),
      body: ListView(
        children: [
          // ── Tema ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              AppStrings.of(context, 'theme'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            title: Text(AppStrings.of(context, 'theme_system')),
            secondary: const Icon(Icons.brightness_auto),
            onChanged: (mode) =>
                mode != null ? themeProvider.setMode(mode) : null,
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            title: Text(AppStrings.of(context, 'theme_light')),
            secondary: const Icon(Icons.light_mode),
            onChanged: (mode) =>
                mode != null ? themeProvider.setMode(mode) : null,
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            title: Text(AppStrings.of(context, 'theme_dark')),
            secondary: const Icon(Icons.dark_mode),
            onChanged: (mode) =>
                mode != null ? themeProvider.setMode(mode) : null,
          ),

          const Divider(height: 32),

          // ── Bahasa ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              AppStrings.of(context, 'language'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile<String>(
            value: 'id',
            groupValue: localeProvider.locale.languageCode,
            title: Text(AppStrings.of(context, 'lang_id')),
            secondary: const Text('🇮🇩', style: TextStyle(fontSize: 20)),
            onChanged: (code) {
              if (code != null) localeProvider.setLocale(Locale(code));
            },
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: localeProvider.locale.languageCode,
            title: Text(AppStrings.of(context, 'lang_en')),
            secondary: const Text('🇬🇧', style: TextStyle(fontSize: 20)),
            onChanged: (code) {
              if (code != null) localeProvider.setLocale(Locale(code));
            },
          ),
        ],
      ),
    );
  }
}
