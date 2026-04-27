// providers/theme_provider.dart

import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
