import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_manager/core/data/demo/demo_repositories.dart';
import 'package:pitch_manager/core/models/sale.dart';
import 'package:pitch_manager/core/repositories/repositories.dart';
import 'package:pitch_manager/core/state/canteen_controller.dart';

import 'helpers.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late DemoCanteenRepository repo;
  late CanteenController controller;

  Future<void> create({List<Sale> sales = const []}) async {
    repo = DemoCanteenRepository(products: testProducts, sales: sales, clock: testClock);
    controller = CanteenController(repository: repo, clock: testClock);
    await settle();
  }

  tearDown(() => controller.dispose());

  test('loads products and flags low stock', () async {
    await create();
    expect(controller.isLoading, isFalse);
    expect(controller.products.map((p) => p.name), ['Chips', 'Coffee', 'Water']);
    expect(controller.lowStockProducts.map((p) => p.name), ['Chips', 'Coffee']);
  });

  group('cart', () {
    test('adds units up to the available stock', () async {
      await create();
      final coffee = controller.productById('p2')!; // 3 in stock
      expect(controller.addToCart(coffee), isTrue);
      expect(controller.addToCart(coffee), isTrue);
      expect(controller.addToCart(coffee), isTrue);
      expect(controller.addToCart(coffee), isFalse);
      expect(controller.quantityInCart('p2'), 3);
      expect(controller.cartTotal, 9);
      expect(controller.cartItemCount, 3);
    });

    test('cannot add an out-of-stock product', () async {
      await create();
      expect(controller.addToCart(controller.productById('p3')!), isFalse);
      expect(controller.cartIsEmpty, isTrue);
    });

    test('removing units and clearing', () async {
      await create();
      final water = controller.productById('p1')!;
      controller
        ..addToCart(water)
        ..addToCart(water)
        ..addToCart(controller.productById('p2')!);
      expect(controller.cartTotal, 7);
      controller.removeOneFromCart('p1');
      expect(controller.quantityInCart('p1'), 1);
      controller.removeOneFromCart('p1');
      expect(controller.cart.containsKey('p1'), isFalse);
      controller.clearCart();
      expect(controller.cartIsEmpty, isTrue);
      expect(controller.cartTotal, 0);
    });

    test('cart lines shrink when stock drops elsewhere', () async {
      await create();
      final coffee = controller.productById('p2')!;
      controller
        ..addToCart(coffee)
        ..addToCart(coffee)
        ..addToCart(coffee);
      await repo.updateProduct(coffee.copyWith(stock: 1));
      await settle();
      expect(controller.quantityInCart('p2'), 1);
      await repo.deleteProduct('p2');
      await settle();
      expect(controller.cartIsEmpty, isTrue);
    });
  });

  group('checkout', () {
    test('records the sale, decrements stock and empties the cart', () async {
      await create();
      controller
        ..addToCart(controller.productById('p1')!)
        ..addToCart(controller.productById('p1')!)
        ..addToCart(controller.productById('p2')!);
      final sale = await controller.checkout(soldBy: 'Sam');
      await settle();

      expect(sale.total, 7);
      expect(sale.itemCount, 3);
      expect(controller.cartIsEmpty, isTrue);
      expect(controller.productById('p1')!.stock, 8);
      expect(controller.productById('p2')!.stock, 2);
      expect(controller.todaySales.single.id, sale.id);
      expect(controller.todayRevenue, 7);
      expect(controller.todayItemsSold, 3);
    });

    test('an empty cart cannot be checked out', () async {
      await create();
      expect(controller.checkout(), throwsArgumentError);
    });

    test('drops cart lines when another sale used up the stock', () async {
      await create();
      final coffee = controller.productById('p2')!;
      controller
        ..addToCart(coffee)
        ..addToCart(coffee);
      // Someone else sells all the coffee behind our back.
      await repo.checkout([CartItem(product: coffee, quantity: 3)]);
      // The cart was reconciled to the new stock (0), so nothing is left to sell.
      await settle();
      expect(controller.cartIsEmpty, isTrue);
    });

    test('voiding returns stock and removes the sale from revenue', () async {
      await create();
      controller.addToCart(controller.productById('p1')!);
      final sale = await controller.checkout();
      await settle();
      expect(controller.todayRevenue, 2);

      await controller.voidSale(sale);
      await settle();
      expect(controller.todayRevenue, 0);
      expect(controller.todaySales.single.voided, isTrue);
      expect(controller.validTodaySales, isEmpty);
      expect(controller.productById('p1')!.stock, 10);
    });

    test('only counts sales of the current day', () async {
      await create(sales: [
        sale('old', DateTime(2026, 10, 26, 12)),
        sale('today', DateTime(2026, 10, 27, 9)),
      ]);
      expect(controller.todaySales.map((s) => s.id), ['today']);
    });
  });

  test('product administration', () async {
    await create();
    final added = await controller.addProduct(name: '  Tea ', price: 2, stock: 5);
    await settle();
    expect(controller.productById(added.id)?.name, 'Tea');
    await controller.updateProduct(added.copyWith(price: 2.5));
    await settle();
    expect(controller.productById(added.id)?.price, 2.5);
    controller.addToCart(controller.productById(added.id)!);
    await controller.deleteProduct(added.id);
    await settle();
    expect(controller.productById(added.id), isNull);
    expect(controller.cartIsEmpty, isTrue);
  });
}
