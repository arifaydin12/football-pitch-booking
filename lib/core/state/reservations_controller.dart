import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/reservation.dart';
import '../repositories/repositories.dart';
import '../utils/date_utils.dart';

enum ScheduleView { day, week }

/// Free-text validation for the booking form.
class ReservationValidators {
  const ReservationValidators._();

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the customer name';
    if (text.length < 2) return 'The name is too short';
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a phone number';
    final digits = text.replaceAll(RegExp(r'\D'), '');
    final valid = RegExp(r'^\+?[0-9 ()\-]+$').hasMatch(text);
    if (!valid || digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}

/// The bookable-hours calendar: loads the week around [focusedDay], exposes
/// day/week views and creates, cancels and restores reservations.
class ReservationsController extends ChangeNotifier {
  ReservationsController({
    required ReservationRepository reservations,
    required SettingsRepository settings,
    DateTime Function()? clock,
  })  : _repo = reservations,
        _clock = clock ?? DateTime.now {
    _focusedDay = dateOnly(_clock());
    _rateSub = settings.watchHourlyRate().listen((rate) {
      _hourlyRate = rate;
      notifyListeners();
    }, onError: (Object _) {});
    _subscribe();
  }

  final ReservationRepository _repo;
  final DateTime Function() _clock;
  StreamSubscription<List<Reservation>>? _subscription;
  StreamSubscription<double>? _rateSub;

  late DateTime _focusedDay;
  ScheduleView _view = ScheduleView.day;
  List<Reservation> _reservations = const [];
  double _hourlyRate = AppConfig.defaultHourlyRate;
  bool _loading = true;
  Object? _error;

  DateTime get focusedDay => _focusedDay;
  ScheduleView get view => _view;
  DateTime get weekStart => startOfWeek(_focusedDay);
  List<DateTime> get weekDays => [for (var i = 0; i < 7; i++) addDays(weekStart, i)];
  double get hourlyRate => _hourlyRate;
  bool get isLoading => _loading;
  Object? get error => _error;
  DateTime get now => _clock();
  bool get isToday => isSameDay(_focusedDay, _clock());

  /// Active and cancelled reservations of the loaded week.
  List<Reservation> get all => _reservations;

  double priceFor(int hours) => _hourlyRate * hours;

  /// Hourly slots of the focused day.
  List<DateTime> get slotsOfFocusedDay => slotsOfDay(_focusedDay);

  void _subscribe() {
    _subscription?.cancel();
    _loading = true;
    _error = null;
    final from = weekStart;
    final to = addDays(from, 7);
    _subscription = _repo.watchRange(from, to).listen((items) {
      _reservations = items;
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object e) {
      _error = e;
      _loading = false;
      notifyListeners();
    });
  }

  void retry() {
    _subscribe();
    notifyListeners();
  }

  void selectDay(DateTime day) {
    final target = dateOnly(day);
    if (isSameDay(target, _focusedDay)) return;
    final weekChanged = startOfWeek(target) != weekStart;
    _focusedDay = target;
    if (weekChanged) {
      _subscribe();
    }
    notifyListeners();
  }

  void goToToday() => selectDay(_clock());

  /// Moves one day (day view) or one week (week view) back or forward.
  void step(int direction) {
    final days = _view == ScheduleView.day ? 1 : 7;
    selectDay(addDays(_focusedDay, direction * days));
  }

  void setView(ScheduleView view) {
    if (_view == view) return;
    _view = view;
    notifyListeners();
  }

  // --- queries ---------------------------------------------------------------

  List<Reservation> activeOn(DateTime day) =>
      _reservations.where((r) => r.isActive && isSameDay(r.start, day)).toList();

  List<Reservation> cancelledOn(DateTime day) =>
      _reservations.where((r) => !r.isActive && isSameDay(r.start, day)).toList();

  /// The active reservation occupying the hourly slot starting at [slot].
  Reservation? reservationAt(DateTime slot) {
    for (final r in _reservations) {
      if (r.isActive && !slot.isBefore(r.start) && slot.isBefore(r.end)) return r;
    }
    return null;
  }

  /// Slots that already started cannot be booked.
  bool isPast(DateTime slot) {
    final n = _clock();
    final currentHour = DateTime(n.year, n.month, n.day, n.hour);
    return slot.isBefore(currentHour);
  }

  bool isBookable(DateTime slot) => !isPast(slot) && reservationAt(slot) == null;

  /// How many consecutive hours can be booked starting at [slot] (0 if none).
  int maxHoursFrom(DateTime slot) {
    if (!isBookable(slot)) return 0;
    var hours = 0;
    while (hours < AppConfig.maxReservationHours) {
      if (slot.hour + hours >= AppConfig.closeHour) break;
      final next = DateTime(slot.year, slot.month, slot.day, slot.hour + hours);
      if (reservationAt(next) != null) break;
      hours++;
    }
    return hours;
  }

  /// Number of booked and total hourly slots of [day].
  ({int booked, int total}) occupancy(DateTime day) {
    final slots = slotsOfDay(day);
    final booked = slots.where((s) => reservationAt(s) != null).length;
    return (booked: booked, total: slots.length);
  }

  /// Revenue of active reservations on [day].
  double bookedRevenueOn(DateTime day) =>
      activeOn(day).fold(0.0, (sum, r) => sum + r.price);

  // --- commands --------------------------------------------------------------

  /// Creates a reservation priced at the current hourly rate.
  /// Throws [SlotUnavailableException] or [ArgumentError].
  Future<Reservation> book({
    required DateTime start,
    required int hours,
    required String customerName,
    required String customerPhone,
    String? createdBy,
  }) async {
    if (!fitsOpeningHours(start, hours)) {
      throw ArgumentError('The reservation is outside opening hours.');
    }
    if (hours > AppConfig.maxReservationHours) {
      throw ArgumentError('A reservation can be at most '
          '${AppConfig.maxReservationHours} hours.');
    }
    if (isPast(start)) {
      throw ArgumentError('This time slot is in the past.');
    }
    return _repo.create(
      start: start,
      hours: hours,
      customerName: customerName.trim(),
      customerPhone: customerPhone.trim(),
      price: priceFor(hours),
      createdBy: createdBy,
    );
  }

  Future<void> cancel(Reservation reservation) => _repo.cancel(reservation);

  Future<void> restore(Reservation reservation) => _repo.restore(reservation);

  @override
  void dispose() {
    _subscription?.cancel();
    _rateSub?.cancel();
    super.dispose();
  }
}
