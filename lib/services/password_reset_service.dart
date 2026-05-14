import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase_options.dart';

final passwordResetServiceProvider = Provider<PasswordResetService>(
  (ref) => PasswordResetService(),
);

class PasswordResetService {
  final _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  //  STEP 1 (User): Submit password reset request
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> submitRequest(String email) async {
    try {
      final snap =
          await _db
              .collection('users')
              .where('email', isEqualTo: email.trim().toLowerCase())
              .limit(1)
              .get();

      if (snap.docs.isEmpty) return 'No account found with this email.';

      final doc = snap.docs.first;
      final userId = doc.id;
      final userName = doc.data()['name']?.toString() ?? '';
      final role = doc.data()['role']?.toString() ?? 'student';

      await _db.collection('password_reset_requests').doc(userId).set({
        'userId': userId,
        'userName': userName,
        'email': email.trim().toLowerCase(),
        'role': role,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'newPassword': null,
      });

      // Notify the correct staff category based on the requesting user's role:
      // teacher → notify adminRH
      // student → notify adminScolarite
      // fallback → notify superAdmin
      final String targetAdminRole;
      if (role == 'teacher') {
        targetAdminRole = 'admin_rh';
      } else if (role == 'student') {
        targetAdminRole = 'admin_scolarite';
      } else {
        targetAdminRole = 'super_admin';
      }

      // Try the targeted role first, fall back to super_admin if not found
      var recipientSnap =
          await _db
              .collection('users')
              .where('role', isEqualTo: targetAdminRole)
              .limit(1)
              .get();

      if (recipientSnap.docs.isEmpty) {
        // Fallback to super_admin
        recipientSnap =
            await _db
                .collection('users')
                .where('role', isEqualTo: 'super_admin')
                .limit(1)
                .get();
      }

      // Also legacy fallback to old 'admin' role
      if (recipientSnap.docs.isEmpty) {
        recipientSnap =
            await _db
                .collection('users')
                .where('role', isEqualTo: 'admin')
                .limit(1)
                .get();
      }

      if (recipientSnap.docs.isNotEmpty) {
        final recipientId = recipientSnap.docs.first.id;
        final recipientLabel = role == 'teacher' ? 'HR Staff' : 'Registrar';
        await _db.collection('notifications').add({
          'userId': recipientId,
          'senderId': userId,
          'senderName': userName,
          'senderRole': role,
          'title': 'Password Reset Request',
          'message': '$userName ($email) has requested a password reset.',
          'messageType': 'password_reset',
          'isRead': false,
          'attachments': [],
          'recipientLabel': recipientLabel,
          'replyToId': '',
          'replyToTitle': '',
          'resetRequestId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return null;
    } catch (e) {
      return 'Error: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  STEP 2 (Admin): Apply new password
  //
  //  Uses secondary Firebase app to sign in as the user with their stored
  //  temp_password, then calls updatePassword() on the signed-in user.
  //  This is the only client-side way to change another user's password
  //  without the Admin SDK.
  //
  //  Requires: users/{uid}.temp_password exists in Firestore
  //  (stored by excel_import_service during user creation)
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> applyNewPassword({
    required String userId,
    required String newPassword,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final data = userDoc.data();
      if (data == null) return 'User not found.';

      final email = data['email']?.toString() ?? '';
      final currentPass = data['temp_password']?.toString() ?? '';

      if (email.isEmpty) return 'User email not found.';
      if (currentPass.isEmpty) {
        return 'Cannot reset: stored password not found.\n'
            'This user must be re-imported or contact admin directly.';
      }

      // Init secondary Firebase app (avoids signing out the admin)
      try {
        secondaryApp = Firebase.app('reset_secondary');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'reset_secondary',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Sign in as the user with their current password
      UserCredential cred;
      try {
        cred = await secondaryAuth.signInWithEmailAndPassword(
          email: email,
          password: currentPass,
        );
      } on FirebaseAuthException catch (e) {
        await secondaryAuth.signOut();
        return 'Authentication failed: ${e.message}\n'
            'The user may have already changed their password.';
      }

      // Update their Firebase Auth password
      await cred.user!.updatePassword(newPassword);
      await secondaryAuth.signOut();

      // Update Firestore
      await _db.collection('users').doc(userId).update({
        'temp_password':
            newPassword, // update stored password for future resets
        'first_login': true,
      });

      await _db.collection('password_reset_requests').doc(userId).update({
        'status': 'resolved',
        'newPassword': newPassword,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // Notify user in-app
      await _db.collection('notifications').add({
        'userId': userId,
        'senderId': 'admin',
        'senderName': 'Admin',
        'senderRole': 'admin',
        'title': 'Your New Password',
        'message':
            'Your password has been reset by the admin.\n\n'
            'Temporary password: $newPassword\n\n'
            'Log in with this password — you will be asked to change it immediately.',
        'messageType': 'password_reset',
        'isRead': false,
        'attachments': [],
        'recipientLabel': '',
        'replyToId': '',
        'replyToTitle': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      debugPrint('[PasswordReset] error: $e');
      return 'Error: $e';
    }
  }

  static String generatePassword({int length = 10}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }
}
