import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../firebase_options.dart';

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
  try {
    final authState = await ref.watch(authStateProvider.future);
    debugPrint('🔐 AUTH STATE: ${authState?.uid}');
    if (authState == null) {
      debugPrint('❌ Auth state is null');
      return UserRole.unknown;
    }
    debugPrint('📡 Fetching Firestore for: ${authState.uid}');
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authState.uid)
            .get();
    debugPrint('📄 Document exists: ${doc.exists}');
    debugPrint('📄 Document data: ${doc.data()}');
    if (!doc.exists) {
      debugPrint('❌ Document does not exist');
      return UserRole.unknown;
    }
    final data = doc.data() as Map<String, dynamic>;
    final roleString = data['role'] as String?;
    debugPrint('🎭 Role string: $roleString');
    final role = UserModel.fromFirestore(doc).role;
    debugPrint('✅ Parsed role: ${role.name}');
    return role;
  } catch (e, stack) {
    debugPrint('💥 Error: $e');
    debugPrint('💥 Stack: $stack');
    return UserRole.unknown;
  }
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

// ─────────────────────────────────────────
//  AUTH SERVICE CLASS
// ─────────────────────────────────────────
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  // ─── Login ───
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

  // ─── Logout ───
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ─── Forgot Password ───
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

  // ─── Get User Role ───
  Future<UserRole> getUserRole(String uid) async {
    try {
      debugPrint('🔍 getUserRole called for: $uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      debugPrint('📄 getUserRole doc exists: ${doc.exists}');
      debugPrint('📄 getUserRole doc data: ${doc.data()}');
      if (!doc.exists) return UserRole.unknown;
      final role = UserModel.fromFirestore(doc).role;
      debugPrint('✅ getUserRole result: ${role.name}');
      return role;
    } catch (e) {
      debugPrint('💥 getUserRole error: $e');
      return UserRole.unknown;
    }
  }

  // ─── Create User (without logging out admin) ───
  Future<AuthResult> createUser({
  required String email,
  required String password,
  required String name,
  required UserRole role,
}) async {
  try {
    // ─── Create secondary Firebase app ───
    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('secondary');
    } catch (e) {
      secondaryApp = await Firebase.initializeApp(
        name: 'secondary',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // ─── Create user in secondary app ───
    final secondaryAuth =
        FirebaseAuth.instanceFor(app: secondaryApp);
    final credential =
        await secondaryAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user == null) {
      return AuthResult.error('Failed to create user.');
    }

    final newUserId = credential.user!.uid;

    // ─── Sign out from secondary app immediately ───
    await secondaryAuth.signOut();

    // ─── Save to Firestore using MAIN instance ───
    // (not secondary app — avoids App Check issues)
    final user = UserModel(
      id: newUserId,
      name: name,
      email: email.trim(),
      role: role,
      createdAt: DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(newUserId)
        .set(user.toFirestore());

    debugPrint('✅ User created: $newUserId role: ${role.name}');

    return AuthResult.success(userId: newUserId);
  } on FirebaseAuthException catch (e) {
    debugPrint('💥 FirebaseAuth error: ${e.code}');
    return AuthResult.error(_mapFirebaseError(e.code));
  } catch (e) {
    debugPrint('💥 createUser error: $e');
    return AuthResult.error('An unexpected error occurred: $e');
  }
}

  // ─── Update Password ───
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_mapFirebaseError(e.code));
    }
  }

  // ─── Map Firebase Error Codes ───
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

// ─────────────────────────────────────────
//  AUTH RESULT
// ─────────────────────────────────────────
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
