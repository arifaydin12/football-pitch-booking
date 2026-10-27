import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_manager/app/app.dart';
import 'package:pitch_manager/core/models/reservation.dart';
import 'package:pitch_manager/core/repositories/repositories.dart';
import 'package:pitch_manager/features/canteen/product_grid.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester tester, AppRepositories repos) async {
  await tester.pumpWidget(PitchManagerApp(repositories: repos));
  await tester.pumpAndSettle();
}

Future<void> signInAs(WidgetTester tester, String email) async {
  await tester.tap(find.textContaining(email));
  await tester.pumpAndSettle();
}

Future<void> goTo(WidgetTester tester, String label) async {
  final inNav = find.descendant(
    of: find.byType(NavigationRail),
    matching: find.text(label),
  );
  await tester.tap(inNav.evaluate().isNotEmpty
      ? inNav
      : find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

/// The tappable product tile (the name also appears in the cart).
Finder productTile(String name) =>
    find.descendant(of: find.byType(ProductGrid), matching: find.text(name));

void main() {
  group('login and roles', () {
    testWidgets('shows the demo banner and both demo accounts', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());

      expect(find.text('Pitch Manager'), findsOneWidget);
      expect(find.text('Demo mode - sample data, resets on reload'), findsOneWidget);
      expect(find.text('Demo accounts'), findsOneWidget);
      expect(find.textContaining('admin@pitch.test'), findsOneWidget);
      expect(find.textContaining('staff@pitch.test'), findsOneWidget);
    });

    testWidgets('validates the form before signing in', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your e-mail'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);

      await tester.enterText(field('E-mail'), 'not-an-email');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid e-mail address'), findsOneWidget);
    });

    testWidgets('shows an error for wrong credentials', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());

      await tester.enterText(field('E-mail'), 'staff@pitch.test');
      await tester.enterText(field('Password'), 'wrong-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect e-mail or password.'), findsOneWidget);
      expect(find.text('Reservations'), findsNothing);
    });

    testWidgets('staff only get reservations and canteen', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');

      final rail = find.byType(NavigationRail);
      expect(rail, findsOneWidget);
      expect(find.descendant(of: rail, matching: find.text('Reservations')), findsOneWidget);
      expect(find.descendant(of: rail, matching: find.text('Canteen')), findsOneWidget);
      expect(find.descendant(of: rail, matching: find.text('Reports')), findsNothing);
      expect(find.descendant(of: rail, matching: find.text('Pricing')), findsNothing);
      expect(find.descendant(of: rail, matching: find.text('Users')), findsNothing);
    });

    testWidgets('administrators also get reports, pricing and users', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'admin@pitch.test');

      final rail = find.byType(NavigationRail);
      for (final label in ['Reservations', 'Canteen', 'Reports', 'Pricing', 'Users']) {
        expect(find.descendant(of: rail, matching: find.text(label)), findsOneWidget, reason: label);
      }
    });

    testWidgets('signing out returns to the login screen', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Demo accounts'), findsOneWidget);
    });

    testWidgets('phones get a bottom navigation bar', (tester) async {
      useScreen(tester, width: 390, height: 844);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'admin@pitch.test');

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Bookings')),
          findsOneWidget);
    });
  });

  group('reservations', () {
    final evening = DateTime(2026, 10, 27, 18);

    testWidgets('lists free and booked hours of the day', (tester) async {
      useScreen(tester);
      await pumpApp(
          tester, testRepositories(reservations: [reservation('a', evening, name: 'Ann Lee', hours: 2)]));
      await signInAs(tester, 'staff@pitch.test');

      expect(find.text('Tuesday, October 27, 2026'), findsWidgets);
      expect(find.text('Ann Lee'), findsOneWidget);
      expect(find.text(r'$80.00'), findsWidgets);
      // 10 AM - 12 PM are past at 12:30; 12 PM onwards can be booked.
      expect(find.text('Past: 10:00 AM - 12:00 PM'), findsOneWidget);
      expect(find.text('Available'), findsWidgets);
    });

    testWidgets('books a slot, shows it and can undo the booking', (tester) async {
      useScreen(tester);
      final handle = tester.ensureSemantics();
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');

      await tester.tap(find.bySemanticsLabel(RegExp(r'^6:00 PM - 7:00 PM, available')));
      await tester.pumpAndSettle();
      expect(find.text('New reservation'), findsWidgets);

      // The form validates its fields.
      await tester.tap(find.widgetWithText(FilledButton, 'Book'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the customer name'), findsOneWidget);
      expect(find.text('Enter a phone number'), findsOneWidget);

      await tester.enterText(field('Customer name'), 'Maria Gomez');
      await tester.enterText(field('Phone number'), '+1 555 0123');
      await tester.tap(find.text('2 h'));
      await tester.pumpAndSettle();
      expect(find.text(r'$80.00'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Book'));
      await tester.pumpAndSettle();

      expect(find.text('Booked 6:00 PM - 8:00 PM for Maria Gomez'), findsOneWidget);
      expect(find.text('Maria Gomez'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Booking undone'), findsOneWidget);
      expect(find.text('Cancelled (1)'), findsOneWidget, reason: 'kept as a cancelled record');
      handle.dispose();
    });

    testWidgets('rejects a phone number that is too short', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');

      await tester.tap(find.widgetWithText(FilledButton, 'New reservation'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Customer name'), 'Maria');
      await tester.enterText(field('Phone number'), '123');
      await tester.tap(find.widgetWithText(FilledButton, 'Book'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid phone number'), findsOneWidget);
    });

    testWidgets('cancels a reservation after confirmation and restores it with undo',
        (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories(reservations: [reservation('a', evening, name: 'Ann Lee')]));
      await signInAs(tester, 'staff@pitch.test');

      await tester.tap(find.text('Ann Lee'));
      await tester.pumpAndSettle();
      expect(find.text('Booked'), findsOneWidget);
      expect(find.text('+1 555 0100'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel reservation'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this reservation?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel reservation'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelled the reservation of Ann Lee'), findsOneWidget);
      expect(find.text('Cancelled (1)'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled (1)'), findsNothing);
      expect(find.text('Ann Lee'), findsOneWidget);
    });

    testWidgets('a cancelled reservation can be restored from the list', (tester) async {
      useScreen(tester);
      await pumpApp(
        tester,
        testRepositories(reservations: [
          reservation('a', evening, name: 'Ann Lee', status: ReservationStatus.cancelled),
        ]),
      );
      await signInAs(tester, 'staff@pitch.test');

      expect(find.text('Cancelled (1)'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled (1)'), findsNothing);
      expect(find.text('Reservation of Ann Lee restored'), findsOneWidget);
    });

    testWidgets('week view shows seven days and opens a day', (tester) async {
      useScreen(tester, width: 1500, height: 1000);
      await pumpApp(tester, testRepositories(reservations: [reservation('a', evening, name: 'Ann Lee')]));
      await signInAs(tester, 'staff@pitch.test');

      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      expect(find.text('Oct 26 - Nov 1'), findsOneWidget);
      for (final day in ['Mon 26', 'Tue 27', 'Wed 28', 'Thu 29', 'Fri 30', 'Sat 31', 'Sun 1']) {
        expect(find.text(day), findsOneWidget, reason: day);
      }
      expect(find.text('Ann Lee'), findsOneWidget);

      await tester.tap(find.text('Wed 28'));
      await tester.pumpAndSettle();
      expect(find.text('Wednesday, October 28, 2026'), findsWidgets);
    });

    testWidgets('navigating days with the arrows', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');

      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      expect(find.text('Wednesday, October 28, 2026'), findsWidgets);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('Tuesday, October 27, 2026'), findsWidgets);
    });

    testWidgets('works on a phone-sized screen', (tester) async {
      useScreen(tester, width: 390, height: 844);
      await pumpApp(tester, testRepositories(reservations: [reservation('a', evening, name: 'Ann Lee')]));
      await signInAs(tester, 'staff@pitch.test');

      expect(find.text('Ann Lee'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('canteen', () {
    testWidgets('sells products, updates stock and can undo the sale', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');
      await goTo(tester, 'Canteen');

      expect(find.textContaining('Low stock:'), findsOneWidget);
      expect(find.text('The cart is empty'), findsOneWidget);

      await tester.tap(productTile('Water'));
      await tester.tap(productTile('Water'));
      await tester.pumpAndSettle();
      expect(find.text(r'Charge $4.00'), findsOneWidget);
      expect(find.text('The cart is empty'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, r'Charge $4.00'));
      await tester.pumpAndSettle();
      expect(find.text(r'Sale of $4.00 completed'), findsOneWidget);
      expect(find.text('8 in stock'), findsOneWidget, reason: 'stock 10 - 2');
      expect(find.text('The cart is empty'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Sale undone, stock restored'), findsOneWidget);
      expect(find.text('10 in stock'), findsOneWidget);
    });

    testWidgets('does not allow selling more than the stock', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');
      await goTo(tester, 'Canteen');

      for (var i = 0; i < 4; i++) {
        await tester.tap(productTile('Coffee'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('No more Coffee in stock.'), findsOneWidget);
      expect(find.text(r'Charge $9.00'), findsOneWidget);
    });

    testWidgets('out-of-stock products cannot be added', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');
      await goTo(tester, 'Canteen');

      await tester.tap(productTile('Chips'));
      await tester.pumpAndSettle();
      expect(find.text('The cart is empty'), findsOneWidget);
      expect(find.text('Out'), findsOneWidget);
    });

    testWidgets("today's sales list lets staff void a sale", (tester) async {
      useScreen(tester);
      await pumpApp(
          tester, testRepositories(sales: [sale('s1', DateTime(2026, 10, 27, 9, 15))]));
      await signInAs(tester, 'staff@pitch.test');
      await goTo(tester, 'Canteen');

      await tester.tap(find.textContaining("Today's sales"));
      await tester.pumpAndSettle();
      expect(find.text('9:15 AM'), findsOneWidget);
      expect(find.text(r'$4.00'), findsWidgets);

      await tester.tap(find.byTooltip(r'Void sale of $4.00 at 9:15 AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Void sale'));
      await tester.pumpAndSettle();
      expect(find.text('Voided'), findsOneWidget);
      expect(find.text('Sale voided, stock restored'), findsOneWidget);
    });

    testWidgets('empty sales history has a friendly message', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');
      await goTo(tester, 'Canteen');
      await tester.tap(find.textContaining("Today's sales"));
      await tester.pumpAndSettle();
      expect(find.text('No sales yet today'), findsOneWidget);
    });

    testWidgets('phone layout uses a cart bar with a bottom sheet', (tester) async {
      useScreen(tester, width: 390, height: 844);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'staff@pitch.test');
      await goTo(tester, 'Canteen');

      expect(find.textContaining('items'), findsNothing);
      await tester.tap(productTile('Water'));
      await tester.pumpAndSettle();
      expect(find.text('1 items'), findsOneWidget);

      await tester.tap(find.text('1 items'));
      await tester.pumpAndSettle();
      expect(find.text(r'Charge $2.00'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, r'Charge $2.00'));
      await tester.pumpAndSettle();
      expect(find.text(r'Sale of $2.00 completed'), findsOneWidget);
    });

    testWidgets('shows an empty state without products', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories(products: const []));
      await signInAs(tester, 'staff@pitch.test');
      await goTo(tester, 'Canteen');
      expect(find.text('No products yet'), findsOneWidget);
    });
  });

  group('administration', () {
    testWidgets('reports show revenue figures and a chart', (tester) async {
      useScreen(tester);
      await pumpApp(
        tester,
        testRepositories(
          reservations: [reservation('a', DateTime(2026, 10, 27, 18), hours: 2)],
          sales: [sale('s1', DateTime(2026, 10, 27, 9))],
        ),
      );
      await signInAs(tester, 'admin@pitch.test');
      await goTo(tester, 'Reports');

      expect(find.text('Total revenue'), findsOneWidget);
      expect(find.text(r'$84.00'), findsOneWidget);
      expect(find.text('1 bookings, 2 h'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('Water'), findsOneWidget, reason: 'top product');

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(find.text('Revenue by hour'), findsOneWidget);
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('reports show an empty state when nothing happened', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'admin@pitch.test');
      await goTo(tester, 'Reports');
      expect(find.text('No revenue in this period'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('changing the hourly rate affects new bookings', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'admin@pitch.test');
      await goTo(tester, 'Pricing');

      expect(find.text(r'$40.00'), findsOneWidget);
      await tester.tap(find.text('Change rate'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Price per hour'), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('The amount must be greater than 0'), findsOneWidget);

      await tester.enterText(field('Price per hour'), '55,5');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text(r'$55.50'), findsWidgets);
      expect(find.text(r'Hourly rate set to $55.50'), findsOneWidget);

      await goTo(tester, 'Reservations');
      await tester.tap(find.widgetWithText(FilledButton, 'New reservation'));
      await tester.pumpAndSettle();
      expect(find.text(r'$55.50'), findsWidgets);
    });

    testWidgets('edits, adds and deletes products', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'admin@pitch.test');
      await goTo(tester, 'Pricing');

      await tester.tap(find.byTooltip('Edit Water'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Price'), '2.75');
      await tester.enterText(field('Units in stock'), '25');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text(r'$2.75'), findsOneWidget);
      expect(find.text('25 in stock'), findsOneWidget);

      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a product name'), findsOneWidget);
      await tester.enterText(field('Name'), 'Orange juice');
      await tester.enterText(field('Price'), '3');
      await tester.enterText(field('Units in stock'), '12');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Orange juice'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete Orange juice'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Orange juice'), findsNothing);
    });

    testWidgets('lists, adds and removes users', (tester) async {
      useScreen(tester);
      await pumpApp(tester, testRepositories());
      await signInAs(tester, 'admin@pitch.test');
      await goTo(tester, 'Users');

      expect(find.text('Alice Admin'), findsOneWidget);
      expect(find.text('Sam Staff'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.byTooltip('Remove admin@pitch.test'), findsNothing,
          reason: 'cannot remove yourself');

      await tester.tap(find.widgetWithText(FilledButton, 'Add user'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an e-mail'), findsOneWidget);
      expect(find.text('Use at least 6 characters'), findsOneWidget);

      await tester.enterText(field('E-mail'), 'new.hire@pitch.test');
      await tester.enterText(field('Temporary password'), 'welcome1');
      await tester.enterText(field('Name (optional)'), 'New Hire');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      expect(find.text('New Hire'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove new.hire@pitch.test'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.text('New Hire'), findsNothing);
    });
  });

  testWidgets('theme can be switched to dark', (tester) async {
    useScreen(tester);
    await pumpApp(tester, testRepositories());
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.light);
    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
  });
}


