import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';          // <── NEW

/// Global key so a tap on the local notification can navigate
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/* ───────── helper ───────── */
Future<bool> _runningOnIosSimulator() async {
  if (!Platform.isIOS) return false;
  final info = await DeviceInfoPlugin().iosInfo;
  return !info.isPhysicalDevice;                                  // true == simulator
}

class PushNotificationService {
  /* ─── singleton objects ─── */
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _initialised = false;

  /* ───────────────────────────────────────────────
     Public entry point – called once from main.dart
  ─────────────────────────────────────────────── */
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

    /* 2. Local-notification plug-in */
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final convoId = resp.payload;
        if (convoId != null) {
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

    /* 4. Store current token   ──── NEW GUARD HERE ──── */
    if (!await _runningOnIosSimulator()) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final token = await FirebaseMessaging.instance.getToken();
        await _saveTokenToFirestore(uid, token);
      } catch (e) {
        debugPrint('❌ Failed to get / save FCM token: $e');
      }

      /* 5. Listen for token refresh */
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (t) => _saveTokenToFirestore(
            FirebaseAuth.instance.currentUser?.uid, t),
      );
    } else {
      debugPrint('📵  iOS simulator – skipping FCM/APNs token logic');
    }

    /* 6. Foreground message → local banner */
    FirebaseMessaging.onMessage.listen(showFlutterNotification);
  }

  /* ───────────────────────────────────────────────
     Save token in sub-collection  /users/{uid}/tokens/{tokenId}
  ─────────────────────────────────────────────── */
  static Future<void> _saveTokenToFirestore(String? uid, String? token) async {
    if (uid == null || token == null) return;

    // ensure parent doc exists
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(token)
        .set({
      'createdAt': FieldValue.serverTimestamp(),
      'platform': Platform.operatingSystem,
    });
  }

  /* ───────────────────────────────────────────────
     Show a local notification from a RemoteMessage
  ─────────────────────────────────────────────── */
  static Future<void> showFlutterNotification(RemoteMessage msg) async {
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
}