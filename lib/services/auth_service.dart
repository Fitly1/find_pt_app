// lib/services/auth_service.dart   (Dart 3 compatible, no fetchSignInMethods* calls)

import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService._(); // static-only

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static void _log(Object? m) {
    if (kDebugMode) print(m);
  }

  /* ───────── GOOGLE ───────── */
  // Add this helper anywhere inside AuthService (e.g., just above googleOneTap)
  static Future<UserCredential?> _finishGoogleSignIn(
    gsi.GoogleSignInAccount? account, {
    String? role,
  }) async {
    if (account == null) {
      _log('🤖 Google | user cancelled');
      return null;
    }

    // v7: synchronous authentication object
    final googleAuth = account.authentication;

    final cred = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken, // accessToken not needed by Firebase
    );

    final userCred = await _auth.signInWithCredential(cred);

    // ensure /users/{uid} exists
    final names = _splitName(userCred.user?.displayName);
    await _ensureUserDocument(
      user: userCred.user!,
      firstName: names[0],
      lastName: names[1],
      role: role,
    );

    _log('✅ Google | uid=${userCred.user?.uid}');
    return userCred;
  }

// Replace your existing googleOneTap with this:
  static Future<UserCredential?> googleOneTap({String? role}) async {
    try {
      // Try lightweight first, then fallback to full auth
      final account =
          await gsi.GoogleSignIn.instance.attemptLightweightAuthentication() ??
              await gsi.GoogleSignIn.instance.authenticate();

      // Delegate to helper that accepts a *nullable* account
      return _finishGoogleSignIn(account, role: role);
    } catch (e, s) {
      _log('❌ Google sign-in failed → $e\n$s');
      rethrow;
    }
  }

  /* ───────── APPLE ───────── */
  static String _genNonce([int len = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static Future<UserCredential?> appleOneTap({String? role}) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw FirebaseAuthException(
        code: 'apple-signin-unsupported',
        message: 'Sign-in with Apple is only available on iOS / macOS.',
      );
    }

    final rawNonce = _genNonce();
    final hashedNonce = _sha256(rawNonce);

    // 1) Ask Apple
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final oauthCred = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken!,
      rawNonce: rawNonce,
      accessToken: apple.authorizationCode,
    );

    try {
      // 2) Normal sign-in
      final userCred = await _auth.signInWithCredential(oauthCred);

      // 3) Once-off profile updates
      await _postAppleProfileUpdates(userCred, apple);

      // 4) Ensure Firestore user-doc exists
      await _ensureUserDocument(
        user: userCred.user!,
        firstName: apple.givenName,
        lastName: apple.familyName,
        role: role,
      );

      _log('✅ Apple | uid=${userCred.user?.uid}');
      return userCred;
    } on FirebaseAuthException catch (e) {
      // Duplicate-credential flow WITHOUT fetchSignInMethods*:
      if (e.code == 'account-exists-with-different-credential' ||
          e.code == 'credential-already-in-use') {
        // If already signed-in → just link
        if (_auth.currentUser != null) {
          final linkedCred =
              await _auth.currentUser!.linkWithCredential(oauthCred);
          await _postAppleProfileUpdates(linkedCred, apple);
          await _ensureUserDocument(
            user: linkedCred.user!,
            firstName: apple.givenName,
            lastName: apple.familyName,
            role: role,
          );
          return linkedCred;
        }

        // Try Google sign-in automatically (common case), then link
        try {
          final googleCred = await googleOneTap(role: role);
          if (googleCred != null && _auth.currentUser != null) {
            final linkedCred =
                await _auth.currentUser!.linkWithCredential(oauthCred);
            await _postAppleProfileUpdates(linkedCred, apple);
            await _ensureUserDocument(
              user: linkedCred.user!,
              firstName: apple.givenName,
              lastName: apple.familyName,
              role: role,
            );
            return linkedCred;
          }
        } catch (_) {
          // If Google attempt fails/cancelled, fall through to message below
        }

        // Clear, user-facing guidance without relying on fetchSignInMethods*
        throw FirebaseAuthException(
          code: 'sign-in-required',
          message:
              'This e-mail is already used by another sign-in method. Please sign in with your existing method (Google or e-mail & password) first, then link Apple from inside the app.',
        );
      }
      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  /* update e-mail / displayName once */
  static Future<void> _postAppleProfileUpdates(
    UserCredential cred,
    AuthorizationCredentialAppleID apple,
  ) async {
    final user = cred.user!;
    if (apple.email != null && (user.email?.isEmpty ?? true)) {
      await user.verifyBeforeUpdateEmail(apple.email!);
    }
    if (apple.givenName != null && apple.familyName != null) {
      await user.updateDisplayName('${apple.givenName} ${apple.familyName}');
    }
  }

  /* ensure Firestore user-doc exists */
  static Future<void> _ensureUserDocument({
    required User user,
    String? firstName,
    String? lastName,
    String? role, // optional
  }) async {
    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await doc.get();

    final display =
        '${firstName ?? ''}${lastName != null ? ' $lastName' : ''}'.trim();

    final data = <String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
      'email': user.email ?? '',
      'displayName': display,
      'displayName_lowerCase': display.toLowerCase(),
      'firstName': firstName ?? '',
      'firstName_lowerCase': (firstName ?? '').toLowerCase(),
      'lastName': lastName ?? '',
      'lastName_lowerCase': (lastName ?? '').toLowerCase(),
      'emailVerified': user.emailVerified,
      'hasAgreedToTnc': false,
    };

    if (role != null) {
      data['role'] = role; // override on demand
    } else if (!snap.exists) {
      data['role'] = 'customer'; // default first-login role
    }

    await doc.set(data, SetOptions(merge: true));
  }

  /* ───────── misc ───────── */
  static Future<void> signOut() async {
    await _auth.signOut();
    await gsi.GoogleSignIn.instance.signOut(); // v7 singleton
    final p = await SharedPreferences.getInstance();
    await p.remove('userRole');
  }

  static User? get currentUser => _auth.currentUser;

  static bool isSocialUser(User u) => u.providerData.any(
        (p) => p.providerId == 'apple.com' || p.providerId == 'google.com',
      );

  /* split name helper */
  static List<String?> _splitName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) return [null, null];
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.length == 1
        ? [parts.first, null]
        : [parts.first, parts.sublist(1).join(' ')];
  }
}
