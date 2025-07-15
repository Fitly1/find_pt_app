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

  /* ───────── shared helpers ───────── */
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static void _log(Object? m) { if (kDebugMode) print(m); }

  /* ───────── GOOGLE ───────── */
  static Future<UserCredential?> googleOneTap() async {
    try {
      final gsi.GoogleSignInAccount? googleUser =
          await gsi.GoogleSignIn().signIn();
      if (googleUser == null) {
        _log('🤖 Google | user cancelled');
        return null;
      }
      final gsi.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final cred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(cred);
      _log('✅ Google | uid=${userCred.user?.uid}');
      return userCred;
    } catch (e, s) {
      _log('❌ Google sign-in failed → $e\n$s');
      rethrow;
    }
  }

  /* ───────── APPLE ───────── */
  static const String _appleClientId = 'com.fitly.findptapp';

  static String _genNonce([int len = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static Future<UserCredential?> appleOneTap() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw FirebaseAuthException(
        code: 'apple-signin-unsupported',
        message: 'Sign-in with Apple is only available on iOS / macOS.',
      );
    }

    final rawNonce    = _genNonce();
    final hashedNonce = _sha256(rawNonce);

    // 1. Ask Apple
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final oauthCred = OAuthProvider('apple.com').credential(
      idToken:     apple.identityToken!,
      rawNonce:    rawNonce,
      accessToken: apple.authorizationCode,
    );

    try {
      // 2. Normal sign-in
      final userCred = await _auth.signInWithCredential(oauthCred);
      await _postAppleProfileUpdates(userCred, apple);
      _log('✅ Apple | uid=${userCred.user?.uid}');
      return userCred;

    } on FirebaseAuthException catch (e) {
      // 3. Handle duplicate-credential situation
      if (e.code == 'account-exists-with-different-credential' ||
          e.code == 'credential-already-in-use') {
        final email   = e.email!;
        final methods = await _auth.fetchSignInMethodsForEmail(email);

        /* a) already signed-in (e.g. Google) → just link */
        if (_auth.currentUser != null) {
          final linkedCred =
              await _auth.currentUser!.linkWithCredential(oauthCred);
          await _postAppleProfileUpdates(linkedCred, apple);
          return linkedCred;                       // <- real UserCredential
        }

        /* b) sign-in with existing method first */
        if (methods.contains('google.com')) {
          final googleCred = await googleOneTap();
          if (googleCred == null) {
            throw FirebaseAuthException(
                code: 'sign-in-cancelled',
                message:
                    'Google sign-in cancelled while linking Apple account.');
          }
        } else if (methods.contains('password')) {
          throw FirebaseAuthException(
            code: 'password-required',
            message:
                'An account with this e-mail already exists. '
                'Please sign in with e-mail & password first, then '
                'choose “Sign in with Apple” again to link.',
          );
        } else {
          rethrow; // other providers not supported
        }

        // link after signing-in
        final linkedCred =
            await _auth.currentUser!.linkWithCredential(oauthCred);
        await _postAppleProfileUpdates(linkedCred, apple);
        return linkedCred;                         // <- real UserCredential
      }
      rethrow; // any other FirebaseAuthException
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  /* ───── update email/displayName once ───── */
  static Future<void> _postAppleProfileUpdates(
      UserCredential cred, AuthorizationCredentialAppleID apple) async {
    final user = cred.user!;
    if (apple.email != null &&
        (user.email == null || user.email!.isEmpty)) {
      try { await user.updateEmail(apple.email!); } catch (_) {}
    }
    if (apple.givenName != null && apple.familyName != null) {
      await user.updateDisplayName(
          '${apple.givenName} ${apple.familyName}');
    }
  }

  /* ───────── misc ───────── */
  static Future<void> signOut() async {
    await _auth.signOut();
    await gsi.GoogleSignIn().signOut();
    final p = await SharedPreferences.getInstance();
    await p.remove('userRole');
  }

  static User? get currentUser => _auth.currentUser;

  static bool isSocialUser(User u) =>
      u.providerData.any((p) => p.providerId == 'apple.com' ||
                                p.providerId == 'google.com');
}