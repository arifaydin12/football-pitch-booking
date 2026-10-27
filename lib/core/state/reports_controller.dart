import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../domain/revenue_calculator.dart';
import '../models/reservation.dart';
import '../models/sale.dart';
import '../repositories/repositories.dart';
import '../utils/date_utils.dart';
import '../utils/formatters.dart';

enum ReportPeriod {
  day('Day'),
  week('Week'),
  month('Month');

  const ReportPeriod(this.label);
  final String label;
}

/// Loads reservations and sales for the selected period (plus the previous
/// period, for comparison) and exposes revenue figures for the charts.
class ReportsController extends ChangeNotifier {
  ReportsController({
    required ReservationRepository reservations,
    required CanteenRepository canteen,
    DateTime Function()? clock,
  })  : _reservationRepo = reservations,
        _canteenRepo = canteen,
        _clock = clock ?? DateTime.now {
    _anchor = dateOnly(_clock());
    _subscribe();
  }

  final ReservationRepository _reservationRepo;
  final CanteenRepository _canteenRepo;
  final DateTime Function() _clock;
  StreamSubscription<List<Reservation>>? _reservationSub;
  StreamSubscription<List<Sale>>? _salesSub;

  late DateTime _anchor;
  ReportPeriod _period = ReportPeriod.week;
  List<Reservation> _reservations = const [];
  List<Sale> _sales = const [];
  bool _reservationsLoaded = false;
  bool _salesLoaded = false;
  Object? _error;

  ReportPeriod get period => _period;
  DateTime get anchor => _anchor;
  bool get isLoading => !(_reservationsLoaded && _salesLoaded) && _error == null;
  Object? get error => _error;

  DateTime get from => _rangeStart(_anchor);
  DateTime get to => _rangeEnd(_anchor);
  DateTime get previousFrom => _rangeStart(_previousAnchor(_anchor));

  DateTime _rangeStart(DateTime a) {
    switch (_period) {
      case ReportPeriod.day:
        return dateOnly(a);
      case ReportPeriod.week:
        return startOfWeek(a);
      case ReportPeriod.month:
        return startOfMonth(a);
    }
  }

  DateTime _rangeEnd(DateTime a) {
    switch (_period) {
      case ReportPeriod.day:
        return addDays(dateOnly(a), 1);
      case ReportPeriod.week:
        return addDays(startOfWeek(a), 7);
      case ReportPeriod.month:
        return startOfNextMonth(a);
    }
  }

  DateTime _previousAnchor(DateTime a) => _shift(a, -1);

  DateTime _shift(DateTime a, int direction) {
    switch (_period) {
      case ReportPeriod.day:
        return addDays(a, direction);
      case ReportPeriod.week:
        return addDays(a, 7 * direction);
      case ReportPeriod.month:
        return DateTime(a.year, a.month + direction, 1);
    }
  }

  /// Whether the selected period already contains the present day.
  bool get isCurrentPeriod {
    final now = _clock();
    return !now.isBefore(from) && now.isBefore(to);
  }

  bool get canGoForward => !isCurrentPeriod && to.isBefore(_clock());

  String get periodLabel {
    switch (_period) {
      case ReportPeriod.day:
        return formatFullDate(_anchor);
      case ReportPeriod.week:
        return formatDateRange(from, addDays(to, -1));
      case ReportPeriod.month:
        return formatMonth(_anchor);
    }
  }

  String get previousLabel {
    switch (_period) {
      case ReportPeriod.day:
        return 'the previous day';
      case ReportPeriod.week:
        return 'the previous week';
      case ReportPeriod.month:
        return 'the previous month';
    }
  }

  void _subscribe() {
    _reservationSub?.cancel();
    _salesSub?.cancel();
    _reservationsLoaded = false;
    _salesLoaded = false;
    _error = null;
    final start = previousFrom;
    final end = to;
    _reservationSub = _reservationRepo.watchRange(start, end).listen((items) {
      _reservations = items;
      _reservationsLoaded = true;
      notifyListeners();
    }, onError: _onError);
    _salesSub = _canteenRepo.watchSales(start, end).listen((items) {
      _sales = items;
      _salesLoaded = true;
      notifyListeners();
    }, onError: _onError);
  }

  void _onError(Object e) {
    _error = e;
    notifyListeners();
  }

  void retry() {
    _subscribe();
    notifyListeners();
  }

  void setPeriod(ReportPeriod period) {
    if (_period == period) return;
    _period = period;
    _subscribe();
    notifyListeners();
  }

  void step(int direction) {
    _anchor = _shift(_anchor, direction);
    _subscribe();
    notifyListeners();
  }

  void goToCurrent() {
    _anchor = dateOnly(_clock());
    _subscribe();
    notifyListeners();
  }

  // --- figures ---------------------------------------------------------------

  RevenueSummary get summary =>
      RevenueCalculator.summarize(_reservations, _sales, from, to);

  RevenueSummary get previousSummary =>
      RevenueCalculator.summarize(_reservations, _sales, previousFrom, from);

  /// Change of the total versus the previous period, or `null` when there is
  /// nothing meaningful to compare: the period is still running (its figures
  /// are incomplete) or the previous period had no revenue.
  double? get totalChangePercent => isCurrentPeriod
      ? null
      : RevenueCalculator.percentChange(summary.total, previousSummary.total);

  /// Chart buckets: hours for the day view, days otherwise.
  List<RevenueBucket> get buckets {
    if (_period == ReportPeriod.day) {
      return RevenueCalculator.byHour(
        _reservations,
        _sales,
        _anchor,
        firstHour: AppConfig.openHour,
        lastHour: AppConfig.closeHour,
      );
    }
    return RevenueCalculator.byDay(_reservations, _sales, from, to);
  }

  /// Share of open hours that were booked, in `[0, 1]`.
  double get occupancy {
    final days = to.difference(from).inHours ~/ 24;
    final available = days * (AppConfig.closeHour - AppConfig.openHour);
    if (available <= 0) return 0;
    return (summary.bookedHours / available).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _reservationSub?.cancel();
    _salesSub?.cancel();
    super.dispose();
  }
}
