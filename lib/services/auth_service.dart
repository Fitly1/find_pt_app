import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService._();                       // static-only

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static void _log(Object? msg) {
    if (kDebugMode) print(msg);
  }

  // ───────── GOOGLE ─────────
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
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      _log('✅ Google | Firebase uid = ${userCred.user?.uid}');
      return userCred;
    } catch (e, s) {
      _log('❌ Google sign-in failed → $e\n$s');
      rethrow;
    }
  }

  // ───────── APPLE ─────────
  static const String _appleClientId = 'com.fitly.findptapp';

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(length, (_) => charset[r.nextInt(charset.length)])
        .join();
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

      // ─── SET EMAIL ONCE (keeps your guest-check happy) ───
      if (appleCredential.email != null &&
          (user.email == null || user.email!.isEmpty)) {
        await user.updateEmail(appleCredential.email!);      // runs only first time
      }

      // ─── Firestore users/{uid} creation / patch ───
      final usersRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(usersRef);

        final String? firstName = appleCredential.givenName;
        final String? lastName  = appleCredential.familyName;
        final displayName       = '${firstName ?? ''} ${lastName ?? ''}'.trim();

        if (!snap.exists) {
          tx.set(usersRef, {
            'createdAt'     : FieldValue.serverTimestamp(),
            'role'          : 'customer',
            'email'         : user.email ?? '',
            'firstName'     : firstName ?? '',
            'lastName'      : lastName  ?? '',
            'displayName'   : displayName,
            'emailVerified' : true,
            'hasAgreedToTnC': true,
          });
        } else {
          final updates = <String, dynamic>{};
          if ((snap['email'] as String).isEmpty && user.email != null) {
            updates['email'] = user.email!;
          }
          if ((snap['firstName'] as String).isEmpty && firstName != null) {
            updates['firstName'] = firstName;
          }
          if ((snap['lastName'] as String).isEmpty && lastName != null) {
            updates['lastName'] = lastName;
          }
          if (updates.isNotEmpty) tx.update(usersRef, updates);
        }
      });

      // optional: store displayName in FirebaseAuth profile
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

  // ───────── misc helpers ─────────
  static Future<void> signOut() async {
    await _auth.signOut();
    await gsi.GoogleSignIn().signOut();
  }

  static User? get currentUser => _auth.currentUser;

  static bool isSocialUser(User user) =>
      user.providerData.any((p) => p.providerId == 'apple.com' ||
                                   p.providerId == 'google.com');
}