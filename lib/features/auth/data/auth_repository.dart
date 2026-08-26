import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collections.dart';
import '../domain/admin_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)),
);

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthRepository(this._auth, this._db);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  /// Resolve the role for a signed-in user.
  ///
  /// A missing profile is NOT treated as an implicit role: absence means "not
  /// an admin". This is deliberately fail-closed — the console must never open
  /// because a read returned nothing.
  Future<AdminUser?> resolveAdmin(User user) async {
    final snap = await _db.collection(Col.users).doc(user.uid).get();
    if (!snap.exists) return null;
    final data = snap.data() ?? const <String, dynamic>{};
    return AdminUser(
      uid: user.uid,
      email: user.email ?? (data['email'] as String? ?? ''),
      displayName:
          user.displayName ?? (data['displayName'] as String? ?? user.email ?? 'Administrator'),
      role: data['role'] as String? ?? '',
    );
  }
}

/// The live session: null when signed out, or when signed in WITHOUT the
/// super_admin role. Router guards read this one provider.
final adminSessionProvider = StreamProvider<AdminUser?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  await for (final user in repo.authStateChanges()) {
    if (user == null) {
      yield null;
      continue;
    }
    final admin = await repo.resolveAdmin(user);
    yield (admin != null && admin.isSuperAdmin) ? admin : null;
  }
});
