import 'package:flutter/foundation.dart';

/// A signed-in identity together with the role read from `users/{uid}`.
///
/// The role is ALWAYS read from Firestore, never from a client-side claim or
/// local storage: the same `users/{uid}.role == 'super_admin'` document that
/// Security Rules read is the single source of truth, so the UI can never
/// disagree with what the backend will actually permit.
@immutable
class AdminUser {
  final String uid;
  final String email;
  final String displayName;
  final String role;

  const AdminUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
  });

  bool get isSuperAdmin => role == 'super_admin';

  static const roleSuperAdmin = 'super_admin';
}

/// Why the console refused a session. Kept distinct from a generic error so the
/// login screen can explain "you signed in fine, but you are not an admin".
enum AuthDenial { none, notSuperAdmin, profileMissing }
