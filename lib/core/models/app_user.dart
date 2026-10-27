enum UserRole {
  admin,
  staff;

  String get label => this == UserRole.admin ? 'Admin' : 'Staff';

  static UserRole parse(Object? value) =>
      value == 'admin' ? UserRole.admin : UserRole.staff;
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
  });

  final String uid;
  final String email;
  final UserRole role;
  final String? displayName;

  bool get isAdmin => role == UserRole.admin;

  /// Name to show in the UI; falls back to the part of the e-mail before `@`.
  String get shownName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.role == role &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uid, email, role, displayName);
}
