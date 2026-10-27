import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/models/app_user.dart';
import '../../core/repositories/repositories.dart';
import '../../core/state/reservations_controller.dart';
import '../../core/utils/formatters.dart';

/// Form for creating a reservation: start time, duration, customer details.
/// Pops with the created `Reservation`.
class BookingDialog extends StatefulWidget {
  const BookingDialog({super.key, required this.initialStart});

  final DateTime initialStart;

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late DateTime _start = widget.initialStart;
  int _hours = 1;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit(ReservationsController controller) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await controller.book(
        start: _start,
        hours: _hours,
        customerName: _name.text,
        customerPhone: _phone.text,
        createdBy: context.read<AppUser>().shownName,
      );
      if (mounted) Navigator.of(context).pop(created);
    } on RepositoryException catch (e) {
      setState(() => _error = e.message);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message.toString());
    } catch (_) {
      setState(() => _error = 'Could not save the reservation. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReservationsController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final options = controller.slotsOfFocusedDay
        .where((s) => s == _start || controller.isBookable(s))
        .toList();
    final maxHours = controller.maxHoursFrom(_start).clamp(1, AppConfig.maxReservationHours);
    if (_hours > maxHours) _hours = maxHours;
    final end = _start.add(Duration(hours: _hours));
    final total = controller.priceFor(_hours);

    return AlertDialog(
      title: const Text('New reservation'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatFullDate(_start),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                DropdownButtonFormField<DateTime>(
                  initialValue: _start,
                  decoration: const InputDecoration(
                    labelText: 'Start time',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: [
                    for (final slot in options)
                      DropdownMenuItem(value: slot, child: Text(formatTime(slot))),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) setState(() => _start = value);
                        },
                ),
                const SizedBox(height: 16),
                Text('Duration', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    for (var h = 1; h <= AppConfig.maxReservationHours; h++)
                      ButtonSegment(
                        value: h,
                        label: Text('$h h'),
                        enabled: h <= maxHours,
                        tooltip: h <= maxHours
                            ? '$h ${h == 1 ? 'hour' : 'hours'}'
                            : 'Not available: the next hour is booked or the pitch closes',
                      ),
                  ],
                  selected: {_hours},
                  onSelectionChanged: _submitting
                      ? null
                      : (value) => setState(() => _hours = value.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                  enabled: !_submitting,
                  validator: ReservationValidators.name,
                  decoration: const InputDecoration(
                    labelText: 'Customer name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  enabled: !_submitting,
                  validator: ReservationValidators.phone,
                  onFieldSubmitted: (_) => _submit(controller),
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+1 555 0100',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatTimeRange(_start, end),
                                style: theme.textTheme.labelLarge),
                            Text(
                              '$_hours h x ${formatMoney(controller.hourlyRate)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Total price ${formatMoney(total)}',
                        child: Text(
                          formatMoney(total),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : () => _submit(controller),
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Book'),
        ),
      ],
    );
  }
}
