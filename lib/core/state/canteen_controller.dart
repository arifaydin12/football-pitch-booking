import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../repositories/repositories.dart';
import '../utils/date_utils.dart';

/// Point of sale: product list with stock, a cart, and today's sales.
class CanteenController extends ChangeNotifier {
  CanteenController({
    required CanteenRepository repository,
    DateTime Function()? clock,
  })  : _repo = repository,
        _clock = clock ?? DateTime.now {
    _subscribe();
  }

  final CanteenRepository _repo;
  final DateTime Function() _clock;
  StreamSubscription<List<Product>>? _productSub;
  StreamSubscription<List<Sale>>? _salesSub;

  List<Product> _products = const [];
  List<Sale> _todaySales = const [];
  final Map<String, int> _cart = {};
  bool _loadingProducts = true;
  bool _loadingSales = true;
  Object? _error;

  List<Product> get products => _products;
  List<Sale> get todaySales => _todaySales;
  bool get isLoading => _loadingProducts || _loadingSales;
  Object? get error => _error;

  void _subscribe() {
    _productSub?.cancel();
    _salesSub?.cancel();
    _loadingProducts = true;
    _loadingSales = true;
    _error = null;
    final today = dateOnly(_clock());
    _productSub = _repo.watchProducts().listen((items) {
      _products = items;
      _loadingProducts = false;
      // Drop cart lines whose product vanished or whose stock shrank.
      _reconcileCart();
      notifyListeners();
    }, onError: _onError);
    _salesSub = _repo.watchSales(today, addDays(today, 1)).listen((items) {
      _todaySales = items;
      _loadingSales = false;
      notifyListeners();
    }, onError: _onError);
  }

  void _onError(Object e) {
    _error = e;
    _loadingProducts = false;
    _loadingSales = false;
    notifyListeners();
  }

  void retry() {
    _subscribe();
    notifyListeners();
  }

  // --- derived data ----------------------------------------------------------

  Product? productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Today's sales that have not been voided.
  List<Sale> get validTodaySales => _todaySales.where((s) => !s.voided).toList();

  double get todayRevenue =>
      validTodaySales.fold(0.0, (sum, s) => sum + s.total);

  int get todayItemsSold =>
      validTodaySales.fold(0, (sum, s) => sum + s.itemCount);

  List<Product> get lowStockProducts =>
      _products.where((p) => p.isLowStock || p.isOutOfStock).toList();

  // --- cart ------------------------------------------------------------------

  Map<String, int> get cart => Map.unmodifiable(_cart);
  bool get cartIsEmpty => _cart.isEmpty;
  int get cartItemCount => _cart.values.fold(0, (a, b) => a + b);

  int quantityInCart(String productId) => _cart[productId] ?? 0;

  List<CartItem> get cartItems => [
        for (final entry in _cart.entries)
          if (productById(entry.key) != null)
            CartItem(product: productById(entry.key)!, quantity: entry.value),
      ];

  double get cartTotal =>
      cartItems.fold(0.0, (sum, i) => sum + i.product.price * i.quantity);

  /// Adds one unit if the stock allows it. Returns whether it was added.
  bool addToCart(Product product) {
    final current = productById(product.id);
    if (current == null) return false;
    final inCart = quantityInCart(product.id);
    if (inCart >= current.stock) return false;
    _cart[product.id] = inCart + 1;
    notifyListeners();
    return true;
  }

  void removeOneFromCart(String productId) {
    final inCart = quantityInCart(productId);
    if (inCart <= 1) {
      _cart.remove(productId);
    } else {
      _cart[productId] = inCart - 1;
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    if (_cart.isEmpty) return;
    _cart.clear();
    notifyListeners();
  }

  void _reconcileCart() {
    final keys = _cart.keys.toList();
    for (final id in keys) {
      final product = productById(id);
      if (product == null || product.stock <= 0) {
        _cart.remove(id);
      } else if (_cart[id]! > product.stock) {
        _cart[id] = product.stock;
      }
    }
  }

  // --- commands --------------------------------------------------------------

  /// Sells the cart contents. Throws [InsufficientStockException]. The cart is
  /// cleared only on success.
  Future<Sale> checkout({String? soldBy}) async {
    final items = cartItems;
    if (items.isEmpty) {
      throw ArgumentError('The cart is empty.');
    }
    final sale = await _repo.checkout(items, soldBy: soldBy);
    _cart.clear();
    notifyListeners();
    return sale;
  }

  Future<void> voidSale(Sale sale) => _repo.voidSale(sale);

  // --- product administration -----------------------------------------------

  Future<Product> addProduct({
    required String name,
    required double price,
    required int stock,
  }) =>
      _repo.addProduct(name: name.trim(), price: price, stock: stock);

  Future<void> updateProduct(Product product) => _repo.updateProduct(product);

  Future<void> deleteProduct(String id) async {
    _cart.remove(id);
    await _repo.deleteProduct(id);
  }

  @override
  void dispose() {
    _productSub?.cancel();
    _salesSub?.cancel();
    super.dispose();
  }
}
