import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/models/reservation.dart';
import '../../core/state/reservations_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import 'reservation_actions.dart';

const double _timeColumn = 64;
const double _minDayColumn = 92;
const double _cellHeight = 48;
const double _headerHeight = 58;

/// Seven-day grid of hourly slots. Tap a free cell to book it and a booked
/// cell to see details.
class WeekView extends StatelessWidget {
  const WeekView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReservationsController>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 32;
        final dayWidth = ((available - _timeColumn) / 7).clamp(_minDayColumn, 400.0);
        final gridWidth = _timeColumn + dayWidth * 7;
        final grid = SizedBox(
          width: gridWidth,
          child: _Grid(controller: controller, dayWidth: dayWidth),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: gridWidth > available
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid)
              : grid,
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.controller, required this.dayWidth});

  final ReservationsController controller;
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    final days = controller.weekDays;
    final hours = [
      for (var h = AppConfig.openHour; h < AppConfig.closeHour; h++) h,
    ];
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: _timeColumn, height: _headerHeight),
            for (final day in days) _DayHeader(day: day, width: dayWidth, controller: controller),
          ],
        ),
        for (final hour in hours)
          Row(
            children: [
              SizedBox(
                width: _timeColumn,
                height: _cellHeight,
                child: ExcludeSemantics(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        formatHour(DateTime(2000, 1, 1, hour)),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ),
              for (final day in days)
                _Cell(
                  slot: DateTime(day.year, day.month, day.day, hour),
                  width: dayWidth,
                  controller: controller,
                ),
            ],
          ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.width, required this.controller});

  final DateTime day;
  final double width;
  final ReservationsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = isSameDay(day, controller.now);
    final selected = isSameDay(day, controller.focusedDay);
    final occupancy = controller.occupancy(day);
    return SizedBox(
      width: width,
      height: _headerHeight,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Semantics(
          button: true,
          label:
              '${formatFullDate(day)}, ${occupancy.booked} of ${occupancy.total} hours booked. Open day view',
          excludeSemantics: true,
          onTap: () => _open(),
          child: Material(
            color: isToday ? scheme.primary : (selected ? scheme.secondaryContainer : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _open,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${formatWeekday(day)} ${day.day}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isToday ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                  Text(
                    '${occupancy.booked}/${occupancy.total} h',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isToday
                          ? scheme.onPrimary.withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open() {
    controller
      ..selectDay(day)
      ..setView(ScheduleView.day);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.slot, required this.width, required this.controller});

  final DateTime slot;
  final double width;
  final ReservationsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reservation = controller.reservationAt(slot);
    final past = controller.isPast(slot);
    final range = formatTimeRange(slot, slot.add(const Duration(hours: 1)));
    final dayLabel = formatFullDate(slot);

    if (reservation != null) {
      final isFirst = reservation.start == slot;
      final isLast = slot.add(const Duration(hours: 1)) == reservation.end;
      return SizedBox(
        width: width,
        height: _cellHeight,
        child: Semantics(
          button: true,
          label:
              '$dayLabel, $range, booked by ${reservation.customerName}. Tap for details',
          excludeSemantics: true,
          onTap: () => ReservationActions.showDetails(context, reservation),
          child: Padding(
            padding: EdgeInsets.fromLTRB(2, isFirst ? 2 : 0, 2, isLast ? 2 : 0),
            child: Material(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(isFirst ? 10 : 0),
                bottom: Radius.circular(isLast ? 10 : 0),
              ),
              child: InkWell(
                onTap: () => ReservationActions.showDetails(context, reservation),
                child: isFirst
                    ? _BookedLabel(reservation: reservation)
                    : const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: _cellHeight,
      child: Semantics(
        button: !past,
        enabled: !past,
        label: past ? '$dayLabel, $range, past' : '$dayLabel, $range, available. Tap to book',
        excludeSemantics: true,
        onTap: past ? null : () => ReservationActions.book(context, slot),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: past
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: past ? null : () => ReservationActions.book(context, slot),
              child: past
                  ? const SizedBox.expand()
                  : Center(
                      child: Icon(Icons.add, size: 16, color: scheme.outline),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookedLabel extends StatelessWidget {
  const _BookedLabel({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            reservation.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${reservation.hours} h',
            maxLines: 1,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}
