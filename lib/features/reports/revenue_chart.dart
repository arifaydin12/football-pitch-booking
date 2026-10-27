import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/domain/revenue_calculator.dart';
import '../../core/state/reports_controller.dart';
import '../../core/utils/formatters.dart';

/// Stacked bar chart of reservation and canteen revenue per hour or day.
class RevenueChart extends StatelessWidget {
  const RevenueChart({
    super.key,
    required this.buckets,
    required this.period,
    this.height = 280,
  });

  final List<RevenueBucket> buckets;
  final ReportPeriod period;
  final double height;

  String _bucketLabel(RevenueBucket b) {
    switch (period) {
      case ReportPeriod.day:
        return formatTimeRange(b.start, b.start.add(const Duration(hours: 1)));
      case ReportPeriod.week:
      case ReportPeriod.month:
        return '${formatWeekday(b.start)}, ${formatShortDate(b.start)}';
    }
  }

  String _axisLabel(int index) {
    final b = buckets[index];
    switch (period) {
      case ReportPeriod.day:
        return formatHour(b.start).replaceAll(' ', '').toLowerCase();
      case ReportPeriod.week:
        return formatWeekday(b.start);
      case ReportPeriod.month:
        return '${b.start.day}';
    }
  }

  bool _showAxisLabel(int index) {
    switch (period) {
      case ReportPeriod.day:
        return buckets.length <= 8 || index.isEven;
      case ReportPeriod.week:
        return true;
      case ReportPeriod.month:
        return index == 0 || (index + 1) % 5 == 0;
    }
  }

  /// A "nice" axis ceiling above the largest bar.
  double _niceMax() {
    final maxValue = buckets.fold<double>(0, (m, b) => math.max(m, b.total));
    if (maxValue <= 0) return 100;
    final exponent = math.pow(10, (math.log(maxValue) / math.ln10).floor()).toDouble();
    final scaled = maxValue / exponent;
    final nice = scaled <= 1
        ? 1
        : scaled <= 2
            ? 2
            : scaled <= 5
                ? 5
                : 10;
    return nice * exponent * 1.0;
  }

  String get _summary {
    if (buckets.isEmpty) return 'No data';
    final peak = buckets.reduce((a, b) => b.total > a.total ? b : a);
    final total = buckets.fold<double>(0, (s, b) => s + b.total);
    return 'Revenue chart for ${period.label.toLowerCase()}. Total ${formatMoney(total)}. '
        'Highest: ${_bucketLabel(peak)} with ${formatMoney(peak.total)}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reservationColor = scheme.primary;
    final canteenColor = scheme.tertiary;
    final maxY = _niceMax();
    final barWidth = switch (period) {
      ReportPeriod.day => 16.0,
      ReportPeriod.week => 28.0,
      ReportPeriod.month => 8.0,
    };

    final groups = [
      for (var i = 0; i < buckets.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: buckets[i].total,
              width: barWidth,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              rodStackItems: [
                BarChartRodStackItem(0, buckets[i].reservations, reservationColor),
                BarChartRodStackItem(
                    buckets[i].reservations, buckets[i].total, canteenColor),
              ],
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: _summary,
          image: true,
          excludeSemantics: true,
          child: SizedBox(
            height: height,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barGroups: groups,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: maxY / 5,
                      getTitlesWidget: (value, meta) {
                        if (value > maxY + 0.001) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            formatMoneyCompact(value),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 ||
                            index >= buckets.length ||
                            !_showAxisLabel(index)) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _axisLabel(index),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => scheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final b = buckets[group.x];
                      final style = TextStyle(
                        color: scheme.onInverseSurface,
                        fontSize: 12,
                      );
                      return BarTooltipItem(
                        '${_bucketLabel(b)}\n',
                        style.copyWith(fontWeight: FontWeight.w700),
                        children: [
                          TextSpan(
                            text: 'Reservations ${formatMoney(b.reservations)}\n'
                                'Canteen ${formatMoney(b.canteen)}\n'
                                'Total ${formatMoney(b.total)}',
                            style: style,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _LegendDot(color: reservationColor, label: 'Reservations'),
            _LegendDot(color: canteenColor, label: 'Canteen'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

