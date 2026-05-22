import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:find_pt_app/navigation.dart';

/* ───────── helper ───────── */
Future<bool> _runningOnIosSimulator() async {
  if (!Platform.isIOS) return false;
  final info = await DeviceInfoPlugin().iosInfo;
  return !info.isPhysicalDevice;
}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;

  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;

  // Call this once from main.dart.
  static Future<void> initializeLocalNotifications() => initialize();

  static Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;

    /* 1. Permission */
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    /* 2. Local-notification plugin */
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final convoId = resp.payload;

        if (convoId != null && convoId.trim().isNotEmpty) {
          navigatorKey.currentState?.pushNamed(
            '/chat',
            arguments: {'conversationId': convoId},
          );
        }
      },
    );

    /* 3. Android channel */
    const channel = AndroidNotificationChannel(
      'default_channel',
      'Default Channel',
      description: 'General notifications for Fitly',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /* 4. Keep FCM token synced after auth is ready */
    if (!await _runningOnIosSimulator()) {
      _authSub?.cancel();
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user == null || user.isAnonymous) {
          debugPrint('📵 Push token sync skipped — no signed-in user.');
          return;
        }

        await _saveCurrentUserToken(user);
      });

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) async {
          final user = FirebaseAuth.instance.currentUser;

          if (user == null || user.isAnonymous) {
            debugPrint('📵 Token refreshed, but no signed-in user.');
            return;
          }

          await _saveTokenToFirestore(user: user, token: token);
        },
        onError: (e) {
          debugPrint('❌ FCM token refresh listener error: $e');
        },
      );

      // Also attempt an immediate sync in case auth is already ready.
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && !currentUser.isAnonymous) {
        await _saveCurrentUserToken(currentUser);
      }
    } else {
      debugPrint('📵 iOS simulator – skipping FCM/APNs token logic');
    }

    /* 5. Foreground message → local banner */
    _foregroundSub?.cancel();
    _foregroundSub =
        FirebaseMessaging.onMessage.listen(showFlutterNotification);
  }

  /// Optional: call this after successful login/signup if you want an extra
  /// guaranteed token sync once FirebaseAuth has completed.
  static Future<void> syncCurrentUserToken() async {
    if (await _runningOnIosSimulator()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      debugPrint('📵 Manual push token sync skipped — no signed-in user.');
      return;
    }

    await _saveCurrentUserToken(user);
  }

  static Future<void> _saveCurrentUserToken(User user) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await _saveTokenToFirestore(user: user, token: token);
    } catch (e) {
      debugPrint('❌ Failed to get/save FCM token: $e');
    }
  }

  /* Save token in /users/{uid}/tokens/{tokenId} */
  static Future<void> _saveTokenToFirestore({
    required User user,
    required String? token,
  }) async {
    if (token == null || token.trim().isEmpty) {
      debugPrint('📵 Push token is empty. Nothing saved.');
      return;
    }

    final uid = user.uid;
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(uid);

    await _ensureUserDocument(userRef: userRef, user: user);

    await userRef.collection('tokens').doc(token).set({
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': Platform.operatingSystem,
    }, SetOptions(merge: true));

    await userRef.set({
      'lastTokenSyncAt': FieldValue.serverTimestamp(),
      'lastTokenPlatform': Platform.operatingSystem,
    }, SetOptions(merge: true));

    debugPrint('✅ FCM token saved for user: $uid');
  }

  /// Ensures every authenticated account has /users/{uid}.
  ///
  /// This is important because Cloud Functions send push notifications by
  /// reading /users/{recipientId}/tokens.
  static Future<void> _ensureUserDocument({
    required DocumentReference<Map<String, dynamic>> userRef,
    required User user,
  }) async {
    final snap = await userRef.get();
    final existing = snap.data() ?? <String, dynamic>{};

    final existingRole = (existing['role'] ?? '').toString().trim();
    final detectedRole = existingRole.isNotEmpty
        ? existingRole
        : await _detectRoleFromProfiles(user.uid);

    final displayName = _bestDisplayName(user, existing);
    final email = (user.email ?? existing['email'] ?? '').toString().trim();

    final patch = <String, dynamic>{
      'uid': user.uid,
      'email': email,
      'displayName': displayName,
      'role': detectedRole,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      patch['createdAt'] = FieldValue.serverTimestamp();
      patch['createdFromTokenSync'] = true;
    } else {
      patch['createdFromTokenSync'] = existing['createdFromTokenSync'] ?? false;
    }

    final firstName = (existing['firstName'] ?? '').toString().trim();
    final lastName = (existing['lastName'] ?? '').toString().trim();

    if (firstName.isEmpty && displayName.isNotEmpty) {
      final parts = displayName.split(RegExp(r'\s+'));
      patch['firstName'] = parts.first;
      if (lastName.isEmpty && parts.length > 1) {
        patch['lastName'] = parts.sublist(1).join(' ');
      }
    }

    await userRef.set(patch, SetOptions(merge: true));

    debugPrint(
      '✅ users/${user.uid} ensured. role=$detectedRole email=$email',
    );
  }

  static String _bestDisplayName(User user, Map<String, dynamic> existing) {
    final existingDisplayName =
        (existing['displayName'] ?? '').toString().trim();

    if (existingDisplayName.isNotEmpty) return existingDisplayName;

    final firebaseName = (user.displayName ?? '').trim();
    if (firebaseName.isNotEmpty) return firebaseName;

    final firstName = (existing['firstName'] ?? '').toString().trim();
    final lastName = (existing['lastName'] ?? '').toString().trim();
    final combined = '$firstName $lastName'.trim();

    if (combined.isNotEmpty) return combined;

    final email = (user.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;

    return 'Fitly User';
  }

  static Future<String> _detectRoleFromProfiles(String uid) async {
    final db = FirebaseFirestore.instance;

    try {
      final trainerDoc = await db.collection('trainer_profiles').doc(uid).get();
      if (trainerDoc.exists) return 'trainer';

      final customerDoc =
          await db.collection('customer_profiles').doc(uid).get();
      if (customerDoc.exists) return 'customer';
    } catch (e) {
      debugPrint('⚠️ Could not detect role from profile docs: $e');
    }

    return 'customer';
  }

  /* Show a local notification from a RemoteMessage */
  static Future<void> showFlutterNotification(RemoteMessage msg) async {
    // SELF-FILTER: don’t show notifications I just sent from this device.
    final me = FirebaseAuth.instance.currentUser?.uid;
    final sender = msg.data['senderUid'];

    if (me != null && sender != null && sender == me) {
      return;
    }

    if (msg.notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      icon: 'ic_stat_fitly2',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    await _local.show(
      msg.hashCode,
      msg.notification!.title,
      msg.notification!.body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: msg.data['conversationId'],
    );
  }

  /// Optional cleanup. You usually do not need to call this unless you build
  /// a custom teardown/reset flow.
  static Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();

    _authSub = null;
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _initialised = false;
  }
}
