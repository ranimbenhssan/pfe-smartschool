import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

// ─── Providers ───
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final userRoleProvider = FutureProvider<UserRole>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) return UserRole.unknown;

  final doc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authState.uid)
          .get();

  if (!doc.exists) return UserRole.unknown;
  return UserModel.fromFirestore(doc).role;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) return null;

  final doc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authState.uid)
          .get();

  if (!doc.exists) return null;
  return UserModel.fromFirestore(doc);
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

// ─── Auth Service ───
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user == null) {
        return AuthResult.error('Login failed. Please try again.');
      }
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred.');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred.');
    }
  }

  Future<UserRole> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return UserRole.unknown;
      return UserModel.fromFirestore(doc).role;
    } catch (e) {
      return UserRole.unknown;
    }
  }

  Future<AuthResult> createUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user == null) {
        return AuthResult.error('Failed to create user.');
      }
      final user = UserModel(
        id: credential.user!.uid,
        name: name,
        email: email.trim(),
        role: role,
        createdAt: DateTime.now(),
      );
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(user.toFirestore());
      return AuthResult.success(userId: credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred.');
    }
  }

  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseError(e.code));
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}

// ─── Auth Result ───
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? userId;

  const AuthResult._({required this.isSuccess, this.errorMessage, this.userId});

  factory AuthResult.success({String? userId}) =>
      AuthResult._(isSuccess: true, userId: userId);

  factory AuthResult.error(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}
