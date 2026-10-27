import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../repositories/repositories.dart';

/// Pitch pricing settings (administrators only).
class SettingsController extends ChangeNotifier {
  SettingsController(this._repo) {
    _subscription = _repo.watchHourlyRate().listen((rate) {
      _hourlyRate = rate;
      _loading = false;
      notifyListeners();
    }, onError: (Object e) {
      _error = e;
      _loading = false;
      notifyListeners();
    });
  }

  final SettingsRepository _repo;
  StreamSubscription<double>? _subscription;

  double _hourlyRate = AppConfig.defaultHourlyRate;
  bool _loading = true;
  Object? _error;

  double get hourlyRate => _hourlyRate;
  bool get isLoading => _loading;
  Object? get error => _error;

  static String? validateAmount(String? value, {bool allowZero = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter an amount';
    final parsed = parseAmount(text);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0 || (!allowZero && parsed == 0)) return 'The amount must be greater than 0';
    if (parsed > 100000) return 'The amount is too large';
    return null;
  }

  /// Parses `12`, `12.5` or `12,5`.
  static double? parseAmount(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> setHourlyRate(double rate) => _repo.setHourlyRate(rate);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
