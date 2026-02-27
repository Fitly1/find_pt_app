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
import 'chat_page.dart';

// ✅ Add this import (your EditProfilePage)
import 'edit_profile_page.dart';

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

  Future<void> _markFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('hasRunBefore') ?? false)) {
      await prefs.setBool('hasRunBefore', true);
    }
  }

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

  Future<void> _decideNextPage() async {
    Widget nextPage = const MarketplacePage(); // default

    try {
      final user = await _currentUserWithGrace();
      if (user == null) {
        _go(nextPage);
        return;
      }

      await user.reload();

      final usesPassword =
          user.providerData.any((p) => p.providerId == 'password');
      if (usesPassword && !user.emailVerified) {
        _go(const EmailVerificationPage());
        return;
      }

      // Read users/{uid}
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
      if (role == 'personal trainer' || role == 'personaltrainer') {
        role = 'trainer';
      }

      (await SharedPreferences.getInstance()).setString('userRole', role);

      if (role == 'customer') {
        nextPage = const MarketplacePage();
      } else if (role == 'trainer') {
        nextPage = await _trainerLanding(user.uid);
      } else {
        nextPage = const LoginPage();
      }

      // Resume pending chat ONLY for customers
      try {
        final prefs = await SharedPreferences.getInstance();
        final pendingUid = prefs.getString('pendingChatPeerUid');

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
            ));
            return;
          }
        }
      } catch (_) {
        // ignore
      }
    } catch (e) {
      debugPrint('RoleRedirect error: $e');
    }

    await secureStorage.writeData(
      'last_role_redirect',
      DateTime.now().toIso8601String(),
    );

    _go(nextPage);
  }

  // ----------------------------
  // Trainer landing helper
  // ----------------------------
  bool _hasBasicTrainerFields(Map<String, dynamic> data) {
    final desc = (data['description'] ?? '').toString().trim();
    final loc = (data['location'] ?? '').toString().trim();
    final specs = (data['specialties'] is List)
        ? (data['specialties'] as List)
        : const [];
    final rateNum = data['rate'];

    final hasRate = (rateNum is num && rateNum > 0) ||
        (rateNum is String && (double.tryParse(rateNum) ?? 0) > 0);

    return desc.isNotEmpty && loc.isNotEmpty && specs.isNotEmpty && hasRate;
  }

  bool _hasProfilePhoto(Map<String, dynamic> data) {
    final url = (data['profileImageUrl'] ?? '').toString().trim();
    return url.isNotEmpty;
  }

  /// Marketplace-ready = safe to show publicly.
  bool _isMarketplaceReady(Map<String, dynamic> data) {
    final completed = (data['completed'] ?? false) == true;
    return completed && _hasBasicTrainerFields(data) && _hasProfilePhoto(data);
  }

  Future<Widget> _trainerLanding(String uid) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection('trainer_profiles').doc(uid);

      var snap = await ref.get();

      // If no trainer profile yet, create a shell (keeps flow stable)
      if (!snap.exists || snap.data() == null) {
        await ref.set({
          'completed': false, // marketplace-ready flag (must stay false)
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        snap = await ref.get();
      }

      final data = snap.data() ?? {};

      // 1) If they don't even have basic setup fields -> setup page
      if (!_hasBasicTrainerFields(data)) {
        return const TrainerProfileSetupPage();
      }

      // 2) If basic fields exist but not marketplace-ready -> edit profile (force photo + polish)
      if (!_isMarketplaceReady(data)) {
        return const EditProfilePage();
      }

      // 3) Marketplace-ready -> dashboard
      return const TrainerHomePage();
    } catch (e) {
      debugPrint('trainerLanding error: $e');
      return const LoginPage();
    }
  }

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
