import 'dart:async';

import '../../config/app_config.dart';
import '../../models/app_user.dart';
import '../../models/product.dart';
import '../../models/reservation.dart';
import '../../models/sale.dart';
import '../../repositories/repositories.dart';
import 'demo_seed.dart';

/// Demo credentials shown on the login screen in demo mode.
class DemoAccounts {
  const DemoAccounts._();

  static const String password = 'demo1234';
  static const AppUser admin = AppUser(
    uid: 'demo-admin',
    email: 'admin@pitch.test',
    role: UserRole.admin,
    displayName: 'Alice Admin',
  );
  static const AppUser staff = AppUser(
    uid: 'demo-staff',
    email: 'staff@pitch.test',
    role: UserRole.staff,
    displayName: 'Sam Staff',
  );
}

/// Small helper that turns "something changed" into re-emitted snapshots.
class _Changes {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  void notify() => _controller.add(null);

  Stream<T> watch<T>(T Function() snapshot) {
    return Stream<T>.multi((controller) {
      controller.add(snapshot());
      final sub = _controller.stream.listen((_) => controller.add(snapshot()));
      controller.onCancel = sub.cancel;
    });
  }
}

/// Builds a complete in-memory backend seeded relative to [now].
AppRepositories createDemoRepositories({DateTime Function()? clock, bool seeded = true}) {
  final now = clock ?? DateTime.now;
  final seed = seeded ? DemoSeed.generate(now()) : null;
  return AppRepositories(
    auth: DemoAuthRepository(),
    reservations: DemoReservationRepository(initial: seed?.reservations ?? const []),
    canteen: DemoCanteenRepository(
      products: seed?.products ?? const [],
      sales: seed?.sales ?? const [],
      clock: now,
    ),
    settings: DemoSettingsRepository(),
    isDemo: true,
    clock: now,
  );
}

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({List<AppUser>? users})
      : _users = List.of(users ?? [DemoAccounts.admin, DemoAccounts.staff]) {
    for (final user in _users) {
      _passwords[user.uid] = DemoAccounts.password;
    }
  }

  final List<AppUser> _users;
  final Map<String, String> _passwords = {};
  final _Changes _changes = _Changes();
  AppUser? _current;
  int _counter = 0;

  @override
  Stream<AppUser?> authStateChanges() => _changes.watch(() => _current);

  @override
  Future<AppUser> signIn(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    final matches = _users.where((u) => u.email.toLowerCase() == normalized);
    if (matches.isEmpty || _passwords[matches.first.uid] != password) {
      throw const AuthFailure('Incorrect e-mail or password.');
    }
    _current = matches.first;
    _changes.notify();
    return _current!;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _changes.notify();
  }

  @override
  Future<List<AppUser>> listUsers() async => List.unmodifiable(_users);

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (_users.any((u) => u.email.toLowerCase() == normalized)) {
      throw const AuthFailure('This e-mail is already in use.');
    }
    if (password.length < 6) {
      throw const AuthFailure('The password must be at least 6 characters.');
    }
    final user = AppUser(
      uid: 'demo-user-${++_counter}',
      email: normalized,
      role: role,
      displayName: displayName,
    );
    _users.add(user);
    _passwords[user.uid] = password;
    return user;
  }

  @override
  Future<void> deleteUser(String uid) async {
    if (uid == _current?.uid) {
      throw const AuthFailure('You cannot delete your own account.');
    }
    _users.removeWhere((u) => u.uid == uid);
    _passwords.remove(uid);
  }
}

class DemoReservationRepository implements ReservationRepository {
  DemoReservationRepository({List<Reservation> initial = const []})
      : _items = List.of(initial);

  final List<Reservation> _items;
  final _Changes _changes = _Changes();
  int _counter = 0;

  bool _conflicts(DateTime start, DateTime end, {String? ignoreId}) => _items.any(
      (r) => r.isActive && r.id != ignoreId && r.overlaps(start, end));

  @override
  Stream<List<Reservation>> watchRange(DateTime from, DateTime to) {
    return _changes.watch(() {
      final list = _items
          .where((r) => !r.start.isBefore(from) && r.start.isBefore(to))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      return List.unmodifiable(list);
    });
  }

  @override
  Future<Reservation> create({
    required DateTime start,
    required int hours,
    required String customerName,
    required String customerPhone,
    required double price,
    String? createdBy,
  }) async {
    final end = start.add(Duration(hours: hours));
    if (_conflicts(start, end)) throw const SlotUnavailableException();
    final reservation = Reservation(
      id: 'demo-r-${++_counter}',
      start: start,
      hours: hours,
      customerName: customerName,
      customerPhone: customerPhone,
      price: price,
      createdBy: createdBy,
    );
    _items.add(reservation);
    _changes.notify();
    return reservation;
  }

  void _replace(Reservation updated) {
    final index = _items.indexWhere((r) => r.id == updated.id);
    if (index >= 0) _items[index] = updated;
    _changes.notify();
  }

  @override
  Future<void> cancel(Reservation reservation) async {
    _replace(reservation.copyWith(status: ReservationStatus.cancelled));
  }

  @override
  Future<void> restore(Reservation reservation) async {
    if (_conflicts(reservation.start, reservation.end, ignoreId: reservation.id)) {
      throw const SlotUnavailableException();
    }
    _replace(reservation.copyWith(status: ReservationStatus.booked));
  }
}

class DemoCanteenRepository implements CanteenRepository {
  DemoCanteenRepository({
    List<Product> products = const [],
    List<Sale> sales = const [],
    DateTime Function()? clock,
  })  : _products = List.of(products),
        _sales = List.of(sales),
        _clock = clock ?? DateTime.now;

  final List<Product> _products;
  final List<Sale> _sales;
  final DateTime Function() _clock;
  final _Changes _productChanges = _Changes();
  final _Changes _saleChanges = _Changes();
  int _counter = 0;

  @override
  Stream<List<Product>> watchProducts() => _productChanges.watch(() {
        final list = List.of(_products)..sort((a, b) => a.name.compareTo(b.name));
        return List.unmodifiable(list);
      });

  @override
  Stream<List<Sale>> watchSales(DateTime from, DateTime to) =>
      _saleChanges.watch(() {
        final list = _sales
            .where((s) => !s.soldAt.isBefore(from) && s.soldAt.isBefore(to))
            .toList()
          ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
        return List.unmodifiable(list);
      });

  @override
  Future<Product> addProduct({
    required String name,
    required double price,
    required int stock,
  }) async {
    final product = Product(
      id: 'demo-p-${++_counter}',
      name: name,
      price: price,
      stock: stock,
    );
    _products.add(product);
    _productChanges.notify();
    return product;
  }

  @override
  Future<void> updateProduct(Product product) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index >= 0) _products[index] = product;
    _productChanges.notify();
  }

  @override
  Future<void> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    _productChanges.notify();
  }

  @override
  Future<Sale> checkout(List<CartItem> items, {String? soldBy}) async {
    // Validate everything first so a failed checkout changes nothing.
    for (final item in items) {
      final current = _products.where((p) => p.id == item.product.id);
      if (current.isEmpty || current.first.stock < item.quantity) {
        throw InsufficientStockException(item.product.name);
      }
    }
    for (final item in items) {
      final index = _products.indexWhere((p) => p.id == item.product.id);
      _products[index] =
          _products[index].copyWith(stock: _products[index].stock - item.quantity);
    }
    final sale = Sale(
      id: 'demo-s-${++_counter}',
      soldAt: _clock(),
      soldBy: soldBy,
      lines: [
        for (final item in items)
          SaleLine(
            productId: item.product.id,
            productName: item.product.name,
            unitPrice: item.product.price,
            quantity: item.quantity,
          ),
      ],
    );
    _sales.add(sale);
    _productChanges.notify();
    _saleChanges.notify();
    return sale;
  }

  @override
  Future<void> voidSale(Sale sale) async {
    final index = _sales.indexWhere((s) => s.id == sale.id);
    if (index < 0 || _sales[index].voided) return;
    _sales[index] = _sales[index].copyWith(voided: true);
    for (final line in sale.lines) {
      final p = _products.indexWhere((p) => p.id == line.productId);
      if (p >= 0) {
        _products[p] = _products[p].copyWith(stock: _products[p].stock + line.quantity);
      }
    }
    _productChanges.notify();
    _saleChanges.notify();
  }
}

class DemoSettingsRepository implements SettingsRepository {
  DemoSettingsRepository({double hourlyRate = AppConfig.defaultHourlyRate})
      : _rate = hourlyRate;

  double _rate;
  final _Changes _changes = _Changes();

  @override
  Stream<double> watchHourlyRate() => _changes.watch(() => _rate);

  @override
  Future<void> setHourlyRate(double rate) async {
    _rate = rate;
    _changes.notify();
  }
}
