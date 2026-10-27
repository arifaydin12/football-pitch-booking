import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/app_user.dart';
import '../../repositories/repositories.dart';

/// Firebase Authentication for sign-in plus a `users/{uid}` profile document
/// in Cloud Firestore that stores the role.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  static const String _secondaryAppName = 'account-creation';

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  AppUser _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      email: (data['email'] as String?) ?? '',
      role: UserRole.parse(data['role']),
      displayName: data['displayName'] as String?,
    );
  }

  Future<AppUser?> _profile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? _fromDoc(doc) : null;
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      final profile = await _profile(user.uid);
      if (profile == null) {
        // Authenticated but without a profile: access has been revoked.
        await _auth.signOut();
      }
      return profile;
    });
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final profile = await _profile(credential.user!.uid);
      if (profile == null) {
        await _auth.signOut();
        throw const AuthFailure(
            'This account has no access. Ask an administrator to create a profile for it.');
      }
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    } on FirebaseException catch (e) {
      await _auth.signOut();
      throw AuthFailure('Could not load your profile (${e.code}).');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<List<AppUser>> listUsers() async {
    final snapshot = await _users.get();
    final users = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => a.email.compareTo(b.email));
    return users;
  }

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required UserRole role,
    String? displayName,
  }) async {
    // A secondary app instance keeps the administrator signed in: creating
    // an account on the default instance would switch the session to it.
    final secondary = await _secondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
    final String uid;
    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      uid = credential.user!.uid;
      await secondaryAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
    final user = AppUser(
      uid: uid,
      email: email.trim(),
      role: role,
      displayName: displayName,
    );
    try {
      await _users.doc(uid).set({
        'email': user.email,
        'role': role.name,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthFailure('The account was created but its profile could not be saved (${e.code}).');
    }
    return user;
  }

  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app(_secondaryAppName);
    } on FirebaseException {
      return Firebase.initializeApp(
        name: _secondaryAppName,
        options: Firebase.app().options,
      );
    }
  }

  @override
  Future<void> deleteUser(String uid) async {
    if (uid == _auth.currentUser?.uid) {
      throw const AuthFailure('You cannot delete your own account.');
    }
    // Deleting the profile revokes access (the app and the security rules
    // require it). Removing the Auth record itself needs the Admin SDK.
    await _users.doc(uid).delete();
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect e-mail or password.';
      case 'invalid-email':
        return 'Enter a valid e-mail address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'weak-password':
        return 'The password must be at least 6 characters.';
      case 'email-already-in-use':
        return 'This e-mail is already in use.';
      default:
        return 'Authentication failed (${e.code}).';
    }
  }
}
