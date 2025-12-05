// lib/role_redirect.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'email_verification_page.dart';
import 'trainer_profile_setup_page.dart';
import 'marketplace_page.dart';
import 'trainer_home_page.dart';
import 'secure_storage_service.dart';
import 'chat_page.dart'; // for resuming pending chat after auth

class RoleRedirect extends StatefulWidget {
  const RoleRedirect({super.key});

  @override
  State<RoleRedirect> createState() => _RoleRedirectState();
}

class _RoleRedirectState extends State<RoleRedirect> {
  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _markFirstLaunch().then((_) => _decideNextPage());
  }

  // ─────────────────────────────────────────────────────────────
  // First-launch helper
  // ─────────────────────────────────────────────────────────────
  Future<void> _markFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('hasRunBefore') ?? false)) {
      await prefs.setBool('hasRunBefore', true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Wait up to 5 s for auth
  // ─────────────────────────────────────────────────────────────
  Future<User?> _currentUserWithGrace() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) return user;

    try {
      user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    return user;
  }

  // ─────────────────────────────────────────────────────────────
  // Main decision tree
  // ─────────────────────────────────────────────────────────────
  Future<void> _decideNextPage() async {
    Widget nextPage = const MarketplacePage(); // default

    try {
      // ─── auth wait ────────────────────────────────
      final user = await _currentUserWithGrace();
      if (user == null) {
        _go(nextPage);
        return;
      }

      await user.reload(); // refresh auth fields

      // ─── email verification (password provider only) ──
      final usesPassword =
          user.providerData.any((p) => p.providerId == 'password');
      if (usesPassword && !user.emailVerified) {
        _go(const EmailVerificationPage());
        return;
      }

      // ─── read Firestore user doc ────────────────────
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();
      if (data == null || data['role'] == null) {
        _go(nextPage);
        return;
      }

      String role = data['role'].toString().toLowerCase().trim();
      // normalise legacy values
      if (role == 'personal trainer' || role == 'personaltrainer') {
        role = 'trainer';
      }

      (await SharedPreferences.getInstance()).setString('userRole', role);

      // ─── role routing ───────────────────────────────
      if (role == 'customer') {
        nextPage = const MarketplacePage();
      } else if (role == 'trainer') {
        nextPage = await _trainerLanding(user.uid);
      } else {
        nextPage = const LoginPage();
      }

      // ─────────────────────────────────────────────────────────
      // Resume pending Concierge / trainer chat after auth
      // Only auto-jump if they're a CUSTOMER.
      // ─────────────────────────────────────────────────────────
      try {
        final prefs = await SharedPreferences.getInstance();
        final pendingUid = prefs.getString('pendingChatPeerUid');
        // final pendingName = prefs.getString('pendingChatPeerName'); // optional

        if (pendingUid != null && role == 'customer') {
          await prefs.remove('pendingChatPeerUid');
          await prefs.remove('pendingChatPeerName');

          final me = FirebaseAuth.instance.currentUser;
          if (me != null) {
            final myUid = me.uid;
            final convoId = (myUid.compareTo(pendingUid) < 0)
                ? '${myUid}_$pendingUid'
                : '${pendingUid}_$myUid';

            _go(ChatPage(
              conversationId: convoId,
              otherUserId: pendingUid,
              // otherUserName: pendingName, // if ChatPage supports it
            ));
            return; // stop normal navigation
          }
        }
      } catch (_) {
        // ignore and fall through to normal navigation
      }
      // ─────────────────────────────────────────────────────────
    } catch (e) {
      debugPrint('RoleRedirect error: $e');
    }

    // record last run (optional analytics)
    await secureStorage.writeData(
      'last_role_redirect',
      DateTime.now().toIso8601String(),
    );

    _go(nextPage);
  }

  // ─────────────────────────────────────────────────────────────
  // Trainer landing helper
  // ─────────────────────────────────────────────────────────────
  Future<Widget> _trainerLanding(String uid) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection('trainer_profiles').doc(uid);

      var snap = await ref.get();

      // If no trainer profile yet, create a basic shell (safety net)
      if (!snap.exists || snap.data() == null) {
        await ref.set({
          'isActive': true, // free phase → visible by default
          'completed': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        snap = await ref.get();
      }

      final data = snap.data() ?? {};
      final completed = (data['completed'] ?? false) == true;

      if (!completed) {
        // Profile shell exists but not completed → push to profile setup
        return const TrainerProfileSetupPage();
      }

      // Pay-wall disabled → always land on dashboard once profile done
      return const TrainerHomePage();
    } catch (e) {
      debugPrint('trainerLanding error: $e');
      return const LoginPage();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Navigation helper
  // ─────────────────────────────────────────────────────────────
  void _go(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
