import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/state/reservations_controller.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/state_views.dart';
import 'day_view.dart';
import 'reservation_actions.dart';
import 'week_view.dart';

/// Calendar of hourly slots with day and week views.
class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReservationsController>();
    final Widget content;
    if (controller.error != null) {
      content = ErrorState(
        message: describeError(controller.error),
        onRetry: controller.retry,
      );
    } else if (controller.isLoading) {
      content = const LoadingView(label: 'Loading reservations');
    } else {
      content = controller.view == ScheduleView.day
          ? const DayView()
          : const WeekView();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(controller: controller),
        Expanded(child: content),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final ReservationsController controller;

  String get _title {
    if (controller.view == ScheduleView.day) {
      return formatFullDate(controller.focusedDay);
    }
    final days = controller.weekDays;
    return formatDateRange(days.first, days.last);
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.focusedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Go to date',
    );
    if (picked != null) controller.selectDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final dayView = controller.view == ScheduleView.day;

    final nav = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: dayView ? 'Previous day' : 'Previous week',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => controller.step(-1),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: dayView ? 'Next day' : 'Next week',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => controller.step(1),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: controller.goToToday,
          child: const Text('Today'),
        ),
      ],
    );

    final title = Semantics(
      header: true,
      child: TextButton.icon(
        onPressed: () => _pickDate(context),
        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
        label: Text(
          _title,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );

    final viewToggle = SegmentedButton<ScheduleView>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ScheduleView.day,
          label: Text('Day'),
          icon: Icon(Icons.view_agenda_outlined),
        ),
        ButtonSegment(
          value: ScheduleView.week,
          label: Text('Week'),
          icon: Icon(Icons.calendar_view_week),
        ),
      ],
      selected: {controller.view},
      onSelectionChanged: (s) => controller.setView(s.first),
    );

    final add = FilledButton.icon(
      onPressed: () => ReservationActions.bookFirstFree(context),
      icon: const Icon(Icons.add),
      label: const Text('New reservation'),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 8, wide ? 24 : 12, 8),
      child: wide
          ? Row(
              children: [
                nav,
                const SizedBox(width: 8),
                Flexible(child: title),
                const Spacer(),
                viewToggle,
                const SizedBox(width: 12),
                add,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: dayView ? 'Previous day' : 'Previous week',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => controller.step(-1),
                    ),
                    Expanded(child: Center(child: title)),
                    IconButton.filledTonal(
                      tooltip: dayView ? 'Next day' : 'Next week',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => controller.step(1),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: viewToggle),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: controller.goToToday,
                      child: const Text('Today'),
                    ),
                    IconButton.filled(
                      tooltip: 'New reservation',
                      icon: const Icon(Icons.add),
                      onPressed: () => ReservationActions.bookFirstFree(context),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
