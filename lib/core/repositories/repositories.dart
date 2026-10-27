import '../models/app_user.dart';
import '../models/product.dart';
import '../models/reservation.dart';
import '../models/sale.dart';

/// Base class for errors that carry a message that is safe to show to users.
class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sign-in or account management failed.
class AuthFailure extends RepositoryException {
  const AuthFailure(super.message);
}

/// The requested hours overlap an existing reservation.
class SlotUnavailableException extends RepositoryException {
  const SlotUnavailableException()
      : super('One or more of these hours are already booked.');
}

/// A checkout asked for more units than are in stock.
class InsufficientStockException extends RepositoryException {
  const InsufficientStockException(String productName)
      : super('Not enough stock for $productName.');
}

/// Authentication and user administration.
abstract class AuthRepository {
  /// Emits the signed-in user, or `null` when signed out. The first event is
  /// emitted once the initial authentication state is known.
  Stream<AppUser?> authStateChanges();

  /// Signs in and returns the user profile. Throws [AuthFailure].
  Future<AppUser> signIn(String email, String password);

  Future<void> signOut();

  Future<List<AppUser>> listUsers();

  /// Creates an account without changing the current session.
  Future<AppUser> createUser({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  });

  /// Removes the user's profile, which revokes access to the app.
  Future<void> deleteUser(String uid);
}

/// Pitch reservations.
abstract class ReservationRepository {
  /// Reservations (booked and cancelled) starting in `[from, to)`.
  Stream<List<Reservation>> watchRange(DateTime from, DateTime to);

  /// Creates a booking. Throws [SlotUnavailableException] on overlap.
  Future<Reservation> create({
    required DateTime start,
    required int hours,
    required String customerName,
    required String customerPhone,
    required double price,
    String? createdBy,
  });

  Future<void> cancel(Reservation reservation);

  /// Re-activates a cancelled booking. Throws [SlotUnavailableException] if
  /// the hours were booked by someone else in the meantime.
  Future<void> restore(Reservation reservation);
}

/// A requested quantity of a product in a checkout.
class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;
}

/// Canteen products and sales.
abstract class CanteenRepository {
  Stream<List<Product>> watchProducts();

  /// Sales (including voided ones) made in `[from, to)`.
  Stream<List<Sale>> watchSales(DateTime from, DateTime to);

  Future<Product> addProduct({
    required String name,
    required double price,
    required int stock,
  });

  Future<void> updateProduct(Product product);

  Future<void> deleteProduct(String id);

  /// Records a sale and decrements stock atomically.
  /// Throws [InsufficientStockException].
  Future<Sale> checkout(List<CartItem> items, {String? soldBy});

  /// Marks a sale as voided and returns its items to stock.
  Future<void> voidSale(Sale sale);
}

/// Pitch settings.
abstract class SettingsRepository {
  Stream<double> watchHourlyRate();

  Future<void> setHourlyRate(double rate);
}

/// The set of repositories the app depends on.
class AppRepositories {
  const AppRepositories({
    required this.auth,
    required this.reservations,
    required this.canteen,
    required this.settings,
    this.isDemo = false,
    this.clock = DateTime.now,
  });

  final AuthRepository auth;
  final ReservationRepository reservations;
  final CanteenRepository canteen;
  final SettingsRepository settings;
  final bool isDemo;

  /// Source of "now"; tests replace it with a fixed time.
  final DateTime Function() clock;
}
