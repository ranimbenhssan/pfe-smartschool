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
  //  STEP 2 (Admin): Generate + apply new password
  //
  //  Uses Firebase Auth REST API two-step flow (no Admin SDK needed):
  //  Step A: sendOobCode  → gets an oobCode for the user's email
  //  Step B: resetPassword → applies the new password using that oobCode
  //
  //  Both endpoints only need the Web API key — no idToken or Admin SDK.
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> applyNewPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      // Get the user's email from Firestore
      final userDoc = await db.collection('users').doc(userId).get();
      final email = userDoc.data()?['email']?.toString() ?? '';
      if (email.isEmpty) return 'User email not found.';

      // ── Step A: Request OOB code for password reset ──────────────────────
      final oobResponse = await http.post(
        Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode'
          '?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestType': 'PASSWORD_RESET', 'email': email}),
      );

      final oobBody = jsonDecode(oobResponse.body) as Map<String, dynamic>;
      if (oobResponse.statusCode != 200) {
        final msg = oobBody['error']?['message']?.toString() ?? 'Unknown';
        return 'Could not generate reset code: $msg';
      }

      final oobCode = oobBody['oobCode']?.toString() ?? '';
      if (oobCode.isEmpty) return 'No OOB code returned.';

      // ── Step B: Apply new password using OOB code ────────────────────────
      final resetResponse = await http.post(
        Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:resetPassword'
          '?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'oobCode': oobCode, 'newPassword': newPassword}),
      );

      final resetBody = jsonDecode(resetResponse.body) as Map<String, dynamic>;
      if (resetResponse.statusCode != 200) {
        final msg = resetBody['error']?['message']?.toString() ?? 'Unknown';
        return 'Could not reset password: $msg';
      }

      // ── Mark request resolved + set first_login ──────────────────────────
      await db.collection('password_reset_requests').doc(userId).update({
        'status': 'resolved',
        'newPassword': newPassword,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      await db.collection('users').doc(userId).update({
        'first_login': true,
        'temp_password': FieldValue.delete(), // clean up any previous fallback
      });

      // ── Notify the user in-app ────────────────────────────────────────────
      await db.collection('notifications').add({
        'userId': userId,
        'senderId': 'admin',
        'senderName': 'Admin',
        'senderRole': 'admin',
        'title': 'Your New Password',
        'message':
            'Your password has been reset by the admin.\n\n'
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

      return null; // success
    } catch (e) {
      debugPrint('[PasswordReset] applyNewPassword error: $e');
      return 'Error: $e';
    }
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
