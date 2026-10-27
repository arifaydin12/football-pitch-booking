import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_manager/app/app.dart';
import 'package:pitch_manager/app/app_theme.dart';
import 'package:pitch_manager/core/domain/revenue_calculator.dart';
import 'package:pitch_manager/core/models/product.dart';
import 'package:pitch_manager/core/repositories/repositories.dart';
import 'package:pitch_manager/core/state/reports_controller.dart';
import 'package:pitch_manager/features/reports/revenue_chart.dart';
import 'package:pitch_manager/shared/widgets/state_views.dart';

import 'helpers.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('state views', () {
    testWidgets('LoadingView exposes a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const LoadingView(label: 'Loading reservations')));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Loading reservations'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('EmptyState shows title, message and action', (tester) async {
      await tester.pumpWidget(host(EmptyState(
        icon: Icons.inbox,
        title: 'Nothing here',
        message: 'Add something first',
        action: FilledButton(onPressed: () {}, child: const Text('Add')),
      )));
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Add something first'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('ErrorState offers a retry', (tester) async {
      var retried = 0;
      await tester.pumpWidget(host(ErrorState(message: 'Network down', onRetry: () => retried++)));
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Network down'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    test('describeError strips the Exception prefix', () {
      expect(describeError(Exception('boom')), 'boom');
      expect(describeError(null), 'Unknown error');
    });
  });

  group('RevenueChart', () {
    final buckets = [
      for (var i = 0; i < 7; i++)
        RevenueBucket(
          start: DateTime(2026, 10, 26 + i),
          reservations: 40.0 * i,
          canteen: 5.0 * i,
        ),
    ];

    testWidgets('renders one bar group per bucket with a spoken summary', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(SizedBox(
        width: 700,
        height: 400,
        child: RevenueChart(buckets: buckets, period: ReportPeriod.week),
      )));
      await tester.pumpAndSettle();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups, hasLength(7));
      // The tallest bar is the last day: 40*6 + 5*6 = 270.
      expect(chart.data.barGroups.last.barRods.single.toY, 270);
      expect(chart.data.maxY, greaterThanOrEqualTo(270));
      expect(find.bySemanticsLabel(RegExp('Revenue chart for week.*Total \\\$945\\.00.*Highest')),
          findsOneWidget);
      expect(find.text('Reservations'), findsOneWidget);
      expect(find.text('Canteen'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('copes with all-zero data', (tester) async {
      await tester.pumpWidget(host(SizedBox(
        width: 700,
        height: 400,
        child: RevenueChart(
          buckets: [for (var i = 0; i < 7; i++) RevenueBucket(start: DateTime(2026, 10, 26 + i))],
          period: ReportPeriod.week,
        ),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<BarChart>(find.byType(BarChart)).data.maxY, 100);
    });
  });

  group('Product', () {
    test('stock flags', () {
      const out = Product(id: 'a', name: 'A', price: 1, stock: 0);
      const low = Product(id: 'b', name: 'B', price: 1, stock: 5);
      const fine = Product(id: 'c', name: 'C', price: 1, stock: 6);
      expect(out.isOutOfStock, isTrue);
      expect(out.isLowStock, isFalse);
      expect(low.isLowStock, isTrue);
      expect(fine.isLowStock, isFalse);
    });
  });

  group('demo banner', () {
    testWidgets('is visible and announced in demo mode', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(PitchManagerApp(repositories: testRepositories()));
      await tester.pumpAndSettle();
      expect(find.text('Demo mode - sample data, resets on reload'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Demo mode')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('is absent when running against a real backend', (tester) async {
      useScreen(tester);
      final demo = testRepositories();
      final real = AppRepositories(
        auth: demo.auth,
        reservations: demo.reservations,
        canteen: demo.canteen,
        settings: demo.settings,
        clock: testClock,
      );
      await tester.pumpWidget(PitchManagerApp(repositories: real));
      await tester.pumpAndSettle();
      expect(find.textContaining('Demo mode'), findsNothing);
      expect(find.text('Demo accounts'), findsNothing, reason: 'no demo shortcuts');
    });
  });
}
