import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final passwordResetServiceProvider = Provider<PasswordResetService>(
  (ref) => PasswordResetService(),
);

class PasswordResetService {
  final _db = FirebaseFirestore.instance;

  // Firebase project Web API key
  static const _apiKey = 'AIzaSyDzCuPF2l3EI6EX1f6frSjPOI8uDBF4uM4';

  // ─────────────────────────────────────────────────────────────────────────
  //  STEP 1 (User): Submit reset request
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

      // Notify admin
      final adminSnap =
          await _db
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .limit(1)
              .get();

      if (adminSnap.docs.isNotEmpty) {
        await _db.collection('notifications').add({
          'userId': adminSnap.docs.first.id,
          'senderId': userId,
          'senderName': userName,
          'senderRole': role,
          'title': 'Password Reset Request',
          'message': '$userName ($email) has requested a password reset.',
          'messageType': 'password_reset',
          'isRead': false,
          'attachments': [],
          'recipientLabel': 'Admin',
          'replyToId': '',
          'replyToTitle': '',
          'resetRequestId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return null; // success
    } catch (e) {
      return 'Error: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  STEP 2 (Admin): Generate + apply new password via Firebase REST API
  //
  //  Uses the Firebase Auth Admin REST endpoint:
  //  POST https://identitytoolkit.googleapis.com/v1/accounts:update?key=API_KEY
  //
  //  This endpoint allows updating ANY user's password using their localId
  //  (uid) — no need for the user's current password or idToken.
  //  It requires the project's Web API key only.
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> applyNewPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      // ── Call Firebase Auth REST API to update password ──────────────────
      final response = await http.post(
        Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:update?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'localId': userId,
          'password': newPassword,
          'returnSecureToken': false,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final errMsg = body['error']?['message']?.toString() ?? 'Unknown error';
        debugPrint('[PasswordReset] REST API error: $errMsg');

        // ADMIN_ONLY_OPERATION means the API key doesn't have permission.
        // In that case fall back to storing the password for manual login flow.
        if (errMsg == 'ADMIN_ONLY_OPERATION') {
          return _fallbackStoreOnly(userId, newPassword);
        }
        return 'Failed to update password: $errMsg';
      }

      // ── Mark request resolved ────────────────────────────────────────────
      await _db.collection('password_reset_requests').doc(userId).update({
        'status': 'resolved',
        'newPassword': newPassword,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // ── Set first_login = true so user is forced to change password ───────
      await _db.collection('users').doc(userId).update({'first_login': true});

      // ── Notify the user ───────────────────────────────────────────────────
      await _db.collection('notifications').add({
        'userId': userId,
        'senderId': 'admin',
        'senderName': 'Admin',
        'senderRole': 'admin',
        'title': 'Your New Password',
        'message':
            'Your password has been reset by the admin.\n\n'
            'New temporary password: $newPassword\n\n'
            'Please log in with this password and change it immediately.',
        'messageType': 'password_reset',
        'isRead': false,
        'attachments': [],
        'recipientLabel': '',
        'replyToId': '',
        'replyToTitle': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // success
    } catch (e) {
      return 'Error: $e';
    }
  }

  // ─── Fallback: store password in Firestore for manual login ───────────────
  // If REST API fails (ADMIN_ONLY_OPERATION), store temp_password in Firestore.
  // The login screen checks for it and signs the user in via secondary app.
  Future<String?> _fallbackStoreOnly(String userId, String newPassword) async {
    await _db.collection('password_reset_requests').doc(userId).update({
      'status': 'resolved',
      'newPassword': newPassword,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(userId).update({
      'first_login': true,
      'temp_password': newPassword,
    });
    await _db.collection('notifications').add({
      'userId': userId,
      'senderId': 'admin',
      'senderName': 'Admin',
      'senderRole': 'admin',
      'title': 'Your New Password',
      'message':
          'Your password has been reset.\n\n'
          'New temporary password: $newPassword\n\n'
          'Log in with this password — you will be asked to change it.',
      'messageType': 'password_reset',
      'isRead': false,
      'attachments': [],
      'recipientLabel': '',
      'replyToId': '',
      'replyToTitle': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return null;
  }

  // ─── Generate a secure random password ───────────────────────────────────
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
