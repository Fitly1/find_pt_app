import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService._(); // static-only

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static void _log(Object? msg) {
    if (kDebugMode) print(msg);
  }

  // ───────────────────── GOOGLE ─────────────────────
  static Future<UserCredential?> googleOneTap() async {
    try {
      final gsi.GoogleSignInAccount? googleUser =
          await gsi.GoogleSignIn().signIn();
      if (googleUser == null) {
        _log('🤖 Google | user cancelled sheet');
        return null;
      }

      final gsi.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:    googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      _log('✅ Google | Firebase uid = ${userCred.user?.uid}');
      return userCred;
    } catch (e, s) {
      _log('❌ Google sign-in failed → $e\n$s');
      rethrow;
    }
  }

  // ───────────────────── APPLE ──────────────────────
  static const String _appleClientId = 'com.fitly.findptapp';

  static String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _sha256of(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static Future<UserCredential?> appleOneTap() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw FirebaseAuthException(
        code: 'apple-signin-unsupported',
        message: 'Sign-in with Apple is only available on iOS / macOS.',
      );
    }

    try {
      final rawNonce   = _generateNonce();
      final hashedNonce = _sha256of(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken:     appleCredential.identityToken!,
        rawNonce:    rawNonce,
        accessToken: appleCredential.authorizationCode!,
      );

      final userCred = await _auth.signInWithCredential(oauthCredential);
      final user     = userCred.user!;
      _log('✅ Apple  | Firebase uid = ${user.uid}');

      // ─── Persist Apple’s one-time email ───
      if (appleCredential.email != null &&
          (user.email == null || user.email!.isEmpty)) {
        try {
          await user.updateEmail(appleCredential.email!);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'email-already-in-use') rethrow;
        }
      }

      // ─── Optional: store displayName in FirebaseAuth profile ───
      if (appleCredential.givenName != null &&
          appleCredential.familyName != null) {
        await user.updateDisplayName(
            '${appleCredential.givenName} ${appleCredential.familyName}');
      }

      return userCred;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  // ───────────────── misc helpers ──────────────────
  static Future<void> signOut() async {
    await _auth.signOut();
    await gsi.GoogleSignIn().signOut();

    // Clear cached role so next login starts clean
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
  }

  static User? get currentUser => _auth.currentUser;

  static bool isSocialUser(User user) => user.providerData.any(
        (p) => p.providerId == 'apple.com' || p.providerId == 'google.com',
      );
}