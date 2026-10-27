import 'package:flutter/material.dart';

/// Holds the selected theme mode. Defaults to following the system setting.
class ThemeController extends ChangeNotifier {
  ThemeController([ThemeMode initial = ThemeMode.system]) : _mode = initial;

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  /// Switches between light and dark, based on what is currently shown.
  void toggle(Brightness current) =>
      setMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}
