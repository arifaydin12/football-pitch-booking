import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/models/reservation.dart';
import '../../core/state/reservations_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/formatters.dart';
import 'reservation_actions.dart';

/// Hourly slots of the focused day, a week strip to jump between days, and a
/// summary panel (side by side on wide screens, stacked on phones).
class DayView extends StatelessWidget {
  const DayView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReservationsController>();
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    final slots = _SlotList(controller: controller);
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 24),
              children: [slots],
            ),
          ),
          SizedBox(
            width: 340,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 24, 24),
              children: [
                _WeekStrip(controller: controller),
                const SizedBox(height: 16),
                _DaySummary(controller: controller),
                const SizedBox(height: 16),
                _CancelledList(controller: controller),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _WeekStrip(controller: controller),
        const SizedBox(height: 12),
        _DaySummary(controller: controller),
        const SizedBox(height: 16),
        slots,
        const SizedBox(height: 16),
        _CancelledList(controller: controller),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.controller});

  final ReservationsController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = dateOnly(controller.now);
    return Row(
      children: [
        for (final day in controller.weekDays)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Builder(builder: (context) {
                final selected = isSameDay(day, controller.focusedDay);
                final isToday = isSameDay(day, today);
                final booked = controller.occupancy(day).booked;
                return Semantics(
                  button: true,
                  selected: selected,
                  excludeSemantics: true,
                  label:
                      '${formatFullDate(day)}${isToday ? ', today' : ''}, $booked hours booked',
                  onTap: () => controller.selectDay(day),
                  child: Material(
                    color: selected ? scheme.primary : scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected
                            ? scheme.primary
                            : (isToday ? scheme.primary : scheme.outlineVariant),
                        width: isToday && !selected ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => controller.selectDay(day),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Text(
                              formatWeekday(day),
                              style: textTheme.labelSmall?.copyWith(
                                color: selected
                                    ? scheme.onPrimary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${day.day}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: selected ? scheme.onPrimary : scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$booked h',
                              style: textTheme.labelSmall?.copyWith(
                                color: selected
                                    ? scheme.onPrimary.withValues(alpha: 0.85)
                                    : scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.controller});

  final ReservationsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = controller.focusedDay;
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.medium;
    final occupancy = controller.occupancy(day);
    final fraction = occupancy.total == 0 ? 0.0 : occupancy.booked / occupancy.total;
    final revenue = controller.bookedRevenueOn(day);
    final bookings = controller.activeOn(day).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // On phones the date is already in the toolbar above.
            if (!compact) ...[
              Text(formatFullDate(day), style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Bookings',
                    value: '$bookings',
                    icon: Icons.event_available_outlined,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Booked revenue',
                    value: formatMoney(revenue),
                    icon: Icons.payments_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              label:
                  'Occupancy: ${occupancy.booked} of ${occupancy.total} hours booked',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Occupancy', style: theme.textTheme.labelMedium),
                      Text('${occupancy.booked} / ${occupancy.total} h',
                          style: theme.textTheme.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotList extends StatelessWidget {
  const _SlotList({required this.controller});

  final ReservationsController controller;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final slots = controller.slotsOfFocusedDay;
    var i = 0;
    while (i < slots.length) {
      final slot = slots[i];
      final reservation = controller.reservationAt(slot);
      if (reservation != null) {
        // A multi-hour booking is drawn as one tall tile.
        final startsHere = reservation.start == slot;
        if (startsHere) {
          final spanned =
              reservation.slotStarts.where((s) => slots.contains(s)).length;
          children.add(_SlotRow(
            time: slot,
            height: _rowHeight * spanned,
            child: _BookedTile(reservation: reservation),
          ));
          i += spanned;
          continue;
        }
      }
      // Fold a run of free hours that already passed into one slim row.
      if (controller.isPast(slot)) {
        var run = 1;
        while (i + run < slots.length &&
            controller.isPast(slots[i + run]) &&
            controller.reservationAt(slots[i + run]) == null) {
          run++;
        }
        if (run > 1) {
          children.add(_SlotRow(
            time: slot,
            height: 52,
            child: _PastBlock(
              from: slot,
              to: slots[i + run - 1].add(const Duration(hours: 1)),
              hours: run,
            ),
          ));
          i += run;
          continue;
        }
      }
      children.add(_SlotRow(
        time: slot,
        height: _rowHeight,
        child: _FreeTile(
          slot: slot,
          past: controller.isPast(slot),
          onTap: () => ReservationActions.book(context, slot),
        ),
      ));
      i++;
    }
    return Column(children: children);
  }
}

const double _rowHeight = 68;

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.time, required this.height, required this.child});

  final DateTime time;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: ExcludeSemantics(
                child: Text(
                  formatTime(time),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _PastBlock extends StatelessWidget {
  const _PastBlock({required this.from, required this.to, required this.hours});

  final DateTime from;
  final DateTime to;
  final int hours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: '${formatTimeRange(from, to)}, past, $hours hours',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.history, size: 20, color: scheme.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Past: ${formatTimeRange(from, to)}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeTile extends StatelessWidget {
  const _FreeTile({required this.slot, required this.past, required this.onTap});

  final DateTime slot;
  final bool past;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = past
        ? '${formatTimeRange(slot, slot.add(const Duration(hours: 1)))}, past'
        : '${formatTimeRange(slot, slot.add(const Duration(hours: 1)))}, available. Tap to book';
    return Semantics(
      button: !past,
      enabled: !past,
      label: label,
      excludeSemantics: true,
      onTap: past ? null : onTap,
      child: Material(
        color: past
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: past ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  past ? Icons.history : Icons.add_circle_outline,
                  size: 20,
                  color: past ? scheme.outline : scheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  past ? 'Past' : 'Available',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: past ? scheme.outline : scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (!past)
                  Text('Book',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookedTile extends StatelessWidget {
  const _BookedTile({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = reservation;
    final label =
        '${formatTimeRange(r.start, r.end)}, booked by ${r.customerName}, ${r.hours} ${r.hours == 1 ? 'hour' : 'hours'}, ${formatMoney(r.price)}. Tap for details';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => ReservationActions.showDetails(context, r),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => ReservationActions.showDetails(context, r),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primary,
                  child: Text(
                    r.customerName.isEmpty ? '?' : r.customerName[0].toUpperCase(),
                    style: TextStyle(
                        color: scheme.onPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${r.customerPhone} - ${r.hours} h',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(r.price),
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelledList extends StatelessWidget {
  const _CancelledList({required this.controller});

  final ReservationsController controller;

  @override
  Widget build(BuildContext context) {
    final cancelled = controller.cancelledOn(controller.focusedDay);
    if (cancelled.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cancelled (${cancelled.length})',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final r in cancelled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.event_busy_outlined,
                        size: 18, color: scheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.customerName,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            formatTimeRange(r.start, r.end),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => ReservationActions.restore(
                          context, controller, r),
                      child: Text('Restore', semanticsLabel: 'Restore reservation of ${r.customerName}'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
