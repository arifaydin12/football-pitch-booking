import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/domain/revenue_calculator.dart';
import '../../core/state/reports_controller.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/state_views.dart';
import 'revenue_chart.dart';

/// Daily, weekly and monthly revenue with charts (administrators only).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportsController>();
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= Breakpoints.medium;
    final pad = wide ? 24.0 : 12.0;

    final Widget body;
    if (controller.error != null) {
      body = ErrorState(
        message: describeError(controller.error),
        onRetry: controller.retry,
      );
    } else if (controller.isLoading) {
      body = const LoadingView(label: 'Loading report');
    } else {
      body = _ReportBody(controller: controller, wide: wide, padding: pad);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportToolbar(controller: controller, wide: wide, padding: pad),
        Expanded(child: body),
      ],
    );
  }
}

class _ReportToolbar extends StatelessWidget {
  const _ReportToolbar({
    required this.controller,
    required this.wide,
    required this.padding,
  });

  final ReportsController controller;
  final bool wide;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = SegmentedButton<ReportPeriod>(
      showSelectedIcon: false,
      segments: [
        for (final p in ReportPeriod.values)
          ButtonSegment(value: p, label: Text(p.label)),
      ],
      selected: {controller.period},
      onSelectionChanged: (s) => controller.setPeriod(s.first),
    );
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Previous ${controller.period.label.toLowerCase()}',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => controller.step(-1),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'Next ${controller.period.label.toLowerCase()}',
          icon: const Icon(Icons.chevron_right),
          onPressed: controller.canGoForward ? () => controller.step(1) : null,
        ),
      ],
    );
    final label = Semantics(
      header: true,
      liveRegion: true,
      child: Text(
        controller.periodLabel,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    final current = TextButton(
      onPressed: controller.isCurrentPeriod ? null : controller.goToCurrent,
      child: Text('This ${controller.period.label.toLowerCase()}'),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 8, padding, 8),
      child: wide
          ? Row(
              children: [
                period,
                const SizedBox(width: 20),
                navigation,
                const SizedBox(width: 12),
                Flexible(child: label),
                const Spacer(),
                current,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                period,
                const SizedBox(height: 8),
                Row(
                  children: [
                    navigation,
                    const SizedBox(width: 12),
                    Expanded(child: label),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.controller,
    required this.wide,
    required this.padding,
  });

  final ReportsController controller;
  final bool wide;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final hasData = summary.total > 0 || summary.bookingCount > 0;

    final chartCard = Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.period == ReportPeriod.day
                  ? 'Revenue by hour'
                  : 'Revenue by day',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (hasData)
              RevenueChart(
                buckets: controller.buckets,
                period: controller.period,
                height: wide ? 300 : 230,
              )
            else
              const SizedBox(
                height: 200,
                child: EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'No revenue in this period',
                  message: 'Bookings and canteen sales will show up here.',
                ),
              ),
          ],
        ),
      ),
    );

    final products = _TopProducts(summary: summary);

    return ListView(
      padding: EdgeInsets.fromLTRB(padding, 4, padding, 24),
      children: [
        _KpiGrid(controller: controller, wide: wide),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: chartCard),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: products),
            ],
          )
        else ...[
          chartCard,
          const SizedBox(height: 16),
          products,
        ],
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.controller, required this.wide});

  final ReportsController controller;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final s = controller.summary;
    final change = controller.totalChangePercent;
    final cards = [
      _Kpi(
        label: 'Total revenue',
        value: formatMoney(s.total),
        icon: Icons.account_balance_wallet_outlined,
        emphasized: true,
        footer: _ChangeChip(
          percent: change,
          previousLabel: controller.previousLabel,
          inProgress: controller.isCurrentPeriod,
        ),
      ),
      _Kpi(
        label: 'Reservations',
        value: formatMoney(s.reservationRevenue),
        icon: Icons.sports_soccer,
        detail: '${s.bookingCount} bookings, ${s.bookedHours} h',
      ),
      _Kpi(
        label: 'Canteen',
        value: formatMoney(s.canteenRevenue),
        icon: Icons.local_cafe_outlined,
        detail: '${s.salesCount} sales, ${s.itemsSold} items',
      ),
      _Kpi(
        label: 'Occupancy',
        value: '${(controller.occupancy * 100).round()}%',
        icon: Icons.donut_large_outlined,
        detail: 'of open hours booked',
      ),
    ];
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[1]),
              const SizedBox(width: 10),
              Expanded(child: cards[2]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: cards[3])],
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.footer,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final Widget? footer;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = emphasized ? scheme.onPrimaryContainer : scheme.onSurface;
    final sub = emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Card(
      color: emphasized ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          container: true,
          label: '$label: $value${detail != null ? ', $detail' : ''}',
          excludeSemantics: footer == null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: emphasized ? fg : scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        style: theme.textTheme.labelLarge?.copyWith(color: sub)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: fg),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(detail!,
                    style: theme.textTheme.bodySmall?.copyWith(color: sub)),
              ],
              if (footer != null) ...[const SizedBox(height: 6), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({
    required this.percent,
    required this.previousLabel,
    required this.inProgress,
  });

  final double? percent;
  final String previousLabel;

  /// The period has not ended, so comparing it with a full one is misleading.
  final bool inProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (percent == null) {
      return Text(
          inProgress ? 'In progress, includes upcoming bookings' : 'No revenue in $previousLabel',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onPrimaryContainer));
    }
    final up = percent! >= 0;
    final text = '${up ? '+' : '-'}${percent!.abs().toStringAsFixed(0)}%';
    return Semantics(
      label: '${up ? 'Up' : 'Down'} ${percent!.abs().toStringAsFixed(0)} percent compared with $previousLabel',
      excludeSemantics: true,
      child: Row(
        children: [
          StatusChip(
            label: text,
            icon: up ? Icons.trending_up : Icons.trending_down,
            background: up ? scheme.primary : scheme.error,
            foreground: up ? scheme.onPrimary : scheme.onError,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text('vs $previousLabel',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.summary});

  final RevenueSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = summary.topProducts;
    final maxRevenue = top.isEmpty ? 1.0 : top.first.revenue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top canteen products', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (top.isEmpty)
              Text('No canteen sales in this period.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant))
            else
              for (final p in top)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    label:
                        '${p.name}: ${p.quantity} sold, ${formatMoney(p.revenue)}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium),
                            ),
                            Text(formatMoney(p.revenue),
                                style: theme.textTheme.labelLarge),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: p.revenue / maxRevenue,
                            minHeight: 6,
                            color: scheme.tertiary,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('${p.quantity} sold',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
