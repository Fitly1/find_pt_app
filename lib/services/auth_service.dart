// lib/services/auth_service.dart
// Dart 3 compatible, google_sign_in v7 compatible

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

  // Web OAuth client ID from google-services.json:
  // "client_type": 3
  static const String _googleServerClientId =
      '794098237480-fbfahj4onnkc2lef3vltes35afne58j6.apps.googleusercontent.com';

  static bool _googleInitialized = false;

  static void _log(Object? message) {
    if (kDebugMode) print(message);
  }

  /* ───────── GOOGLE INIT ───────── */

  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    await gsi.GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );

    _googleInitialized = true;
    _log('✅ GoogleSignIn initialized');
  }

  /* ───────── GOOGLE ───────── */

  static Future<UserCredential?> _finishGoogleSignIn(
    gsi.GoogleSignInAccount? account, {
    String? role,
    bool createUserDocument = true,
  }) async {
    if (account == null) {
      _log('🤖 Google | user cancelled');
      return null;
    }

    final googleAuth = account.authentication;

    if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google sign-in did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'google-user-null',
        message: 'Google sign-in did not return a Firebase user.',
      );
    }

    if (createUserDocument) {
      final names = _splitName(user.displayName);

      await _ensureUserDocument(
        user: user,
        firstName: names[0],
        lastName: names[1],
        role: role,
      );
    } else {
      _log('ℹ️ Google | sign-in only, users/{uid} not created');
    }

    _log('✅ Google | uid=${user.uid}');
    return userCred;
  }

  static Future<UserCredential?> googleOneTap({
    String? role,
    bool createUserDocument = true,
  }) async {
    try {
      await _ensureGoogleInitialized();

      final account =
          await gsi.GoogleSignIn.instance.attemptLightweightAuthentication() ??
              await gsi.GoogleSignIn.instance.authenticate();

      return _finishGoogleSignIn(
        account,
        role: role,
        createUserDocument: createUserDocument,
      );
    } catch (e, stack) {
      _log('❌ Google sign-in failed → $e\n$stack');
      rethrow;
    }
  }

  /* ───────── APPLE ───────── */

  static String _genNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();

    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  static String _sha256(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  static Future<UserCredential?> appleOneTap({
    String? role,
    bool createUserDocument = true,
  }) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw FirebaseAuthException(
        code: 'apple-signin-unsupported',
        message: 'Sign-in with Apple is only available on iOS / macOS.',
      );
    }

    final rawNonce = _genNonce();
    final hashedNonce = _sha256(rawNonce);

    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    if (apple.identityToken == null || apple.identityToken!.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-apple-id-token',
        message: 'Apple Sign-In did not return an identity token.',
      );
    }

    final oauthCred = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken!,
      rawNonce: rawNonce,
      accessToken: apple.authorizationCode,
    );

    try {
      final userCred = await _auth.signInWithCredential(oauthCred);
      final user = userCred.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'apple-user-null',
          message: 'Apple Sign-In did not return a Firebase user.',
        );
      }

      await _postAppleProfileUpdates(userCred, apple);

      if (createUserDocument) {
        await _ensureUserDocument(
          user: user,
          firstName: apple.givenName,
          lastName: apple.familyName,
          role: role,
        );
      } else {
        _log('ℹ️ Apple | sign-in only, users/{uid} not created');
      }

      _log('✅ Apple | uid=${user.uid}');
      return userCred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' ||
          e.code == 'credential-already-in-use') {
        if (_auth.currentUser != null) {
          final linkedCred =
              await _auth.currentUser!.linkWithCredential(oauthCred);

          await _postAppleProfileUpdates(linkedCred, apple);

          if (createUserDocument) {
            await _ensureUserDocument(
              user: linkedCred.user!,
              firstName: apple.givenName,
              lastName: apple.familyName,
              role: role,
            );
          } else {
            _log('ℹ️ Apple link | users/{uid} not created');
          }

          return linkedCred;
        }

        try {
          final googleCred = await googleOneTap(
            role: role,
            createUserDocument: createUserDocument,
          );

          if (googleCred != null && _auth.currentUser != null) {
            final linkedCred =
                await _auth.currentUser!.linkWithCredential(oauthCred);

            await _postAppleProfileUpdates(linkedCred, apple);

            if (createUserDocument) {
              await _ensureUserDocument(
                user: linkedCred.user!,
                firstName: apple.givenName,
                lastName: apple.familyName,
                role: role,
              );
            } else {
              _log('ℹ️ Apple link after Google | users/{uid} not created');
            }

            return linkedCred;
          }
        } catch (_) {
          // If Google attempt fails/cancelled, fall through to clear message.
        }

        throw FirebaseAuthException(
          code: 'sign-in-required',
          message:
              'This e-mail is already used by another sign-in method. Please sign in with your existing method first, then link Apple from inside the app.',
        );
      }

      rethrow;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  /* ───────── APPLE PROFILE UPDATE ───────── */

  static Future<void> _postAppleProfileUpdates(
    UserCredential cred,
    AuthorizationCredentialAppleID apple,
  ) async {
    final user = cred.user;
    if (user == null) return;

    if (apple.email != null && (user.email?.isEmpty ?? true)) {
      await user.verifyBeforeUpdateEmail(apple.email!);
    }

    if (apple.givenName != null && apple.familyName != null) {
      await user.updateDisplayName('${apple.givenName} ${apple.familyName}');
    }
  }

  /* ───────── FIRESTORE USER DOC ───────── */

  static Future<void> _ensureUserDocument({
    required User user,
    String? firstName,
    String? lastName,
    String? role,
  }) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();

    final existing = snap.data() ?? <String, dynamic>{};

    final authDisplayName = (user.displayName ?? '').trim();

    final typedDisplay =
        '${firstName ?? ''}${lastName != null ? ' $lastName' : ''}'.trim();

    final display = typedDisplay.isNotEmpty ? typedDisplay : authDisplayName;

    final patch = <String, dynamic>{
      'email': user.email ?? '',
      'emailVerified': user.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      patch['createdAt'] = FieldValue.serverTimestamp();
      patch['hasAgreedToTnc'] = false;
      patch['hasAgreedToTnC'] = false;
    }

    if (display.isNotEmpty) {
      patch['displayName'] = display;
      patch['displayName_lowerCase'] = display.toLowerCase();
    } else if (!existing.containsKey('displayName')) {
      patch['displayName'] = '';
      patch['displayName_lowerCase'] = '';
    }

    if (firstName != null && firstName.trim().isNotEmpty) {
      patch['firstName'] = firstName.trim();
      patch['firstName_lowerCase'] = firstName.trim().toLowerCase();
    } else if (!existing.containsKey('firstName')) {
      patch['firstName'] = '';
      patch['firstName_lowerCase'] = '';
    }

    if (lastName != null && lastName.trim().isNotEmpty) {
      patch['lastName'] = lastName.trim();
      patch['lastName_lowerCase'] = lastName.trim().toLowerCase();
    } else if (!existing.containsKey('lastName')) {
      patch['lastName'] = '';
      patch['lastName_lowerCase'] = '';
    }

    if (role != null && role.trim().isNotEmpty) {
      patch['role'] = role.trim().toLowerCase();
    } else if (!snap.exists) {
      patch['role'] = 'customer';
    }

    await ref.set(patch, SetOptions(merge: true));
  }

  /* ───────── SIGN OUT ───────── */

  static Future<void> signOut() async {
    await _auth.signOut();

    try {
      await _ensureGoogleInitialized();
      await gsi.GoogleSignIn.instance.signOut();
    } catch (e) {
      _log('Google signOut skipped → $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
  }

  static User? get currentUser => _auth.currentUser;

  static bool isSocialUser(User user) {
    return user.providerData.any(
      (provider) =>
          provider.providerId == 'apple.com' ||
          provider.providerId == 'google.com',
    );
  }

  static List<String?> _splitName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return [null, null];
    }

    final parts = displayName.trim().split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return [parts.first, null];
    }

    return [
      parts.first,
      parts.sublist(1).join(' '),
    ];
  }
}
