// lib/auth_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService._(); // private ctor; purely static class
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─────────────────────────── GOOGLE ────────────────────────────
  static Future<UserCredential?> googleOneTap() async {
    final gsi.GoogleSignInAccount? googleUser =
        await gsi.GoogleSignIn().signIn(); // user aborts → null
    if (googleUser == null) return null;

    final gsi.GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  // ─────────────────────────── APPLE ─────────────────────────────
  /* Apple requires a SHA-256 hashed, random nonce so that the same
     value is supplied to both Apple and Firebase. */
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static Future<UserCredential?> appleOneTap() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw FirebaseAuthException(
        code: 'apple-signin-unsupported',
        message: 'Sign-in with Apple is only available on iOS / macOS devices.',
      );
    }

    // 1️⃣  Create nonce for Firebase ↔ Apple handshake
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    // 2️⃣  Show Apple’s native sheet
    final appleCred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    // 3️⃣  Build Firebase credential
    final oauthCred = OAuthProvider('apple.com').credential(
      idToken: appleCred.identityToken,
      rawNonce: rawNonce,
    );

    // 4️⃣  Sign-in / link
    final userCred = await _auth.signInWithCredential(oauthCred);

    // 5️⃣  First-time only: propagate the user’s name that Apple returns once
    if (appleCred.givenName != null && appleCred.familyName != null) {
      await userCred.user
          ?.updateDisplayName('${appleCred.givenName} ${appleCred.familyName}');
    }

    return userCred; // same shape as Google → fits your existing flow
  }

  // ─────────────────────────── misc helpers ──────────────────────
  static Future<void> signOut() async {
    await _auth.signOut();
    await gsi.GoogleSignIn().signOut(); // clear Google session too
  }

  static User? get currentUser => _auth.currentUser;
}
