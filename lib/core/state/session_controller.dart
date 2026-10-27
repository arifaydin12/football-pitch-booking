import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../repositories/repositories.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// Tracks the signed-in user and handles sign-in / sign-out.
class SessionController extends ChangeNotifier {
  SessionController(this._auth) {
    _subscription = _auth.authStateChanges().listen(
      (user) {
        _user = user;
        _status = user == null ? SessionStatus.signedOut : SessionStatus.signedIn;
        notifyListeners();
      },
      onError: (Object error) {
        _user = null;
        _status = SessionStatus.signedOut;
        _error = 'Could not check the sign-in state. $error';
        notifyListeners();
      },
    );
  }

  final AuthRepository _auth;
  StreamSubscription<AppUser?>? _subscription;

  SessionStatus _status = SessionStatus.loading;
  AppUser? _user;
  bool _busy = false;
  String? _error;

  SessionStatus get status => _status;
  AppUser? get user => _user;

  /// True while a sign-in request is running.
  bool get busy => _busy;

  /// Message of the last failed sign-in, if any.
  String? get error => _error;

  AuthRepository get auth => _auth;

  /// Returns `true` on success; otherwise [error] is set.
  Future<bool> signIn(String email, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _auth.signIn(email, password);
      return true;
    } on RepositoryException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _error = null;
    await _auth.signOut();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
