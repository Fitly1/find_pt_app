// lib/role_redirect.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pages
import 'login_page.dart';
import 'email_verification_page.dart';
import 'profile_page.dart' as profile;
import 'trainer_profile_setup_page.dart';
import 'marketplace_page.dart'; // ← NEW import

import 'secure_storage_service.dart';

class RoleRedirect extends StatefulWidget {
  const RoleRedirect({super.key});

  @override
  RoleRedirectState createState() => RoleRedirectState();
}

class RoleRedirectState extends State<RoleRedirect> {
  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    debugPrint('🏁 RoleRedirect START');
    _handleFirstLaunch().then((_) => _checkUserRole());
  }

  /* ───────────────── first-launch sign-out */
  Future<void> _handleFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRunBefore = prefs.getBool('hasRunBefore') ?? false;

    if (!hasRunBefore) {
      debugPrint('🆕 First launch detected → forcing sign-out');
      await FirebaseAuth.instance.signOut();
      await prefs.setBool('hasRunBefore', true);
    }
  }

  /* ───────────────── wait for token restore */
  Future<User?> _getCurrentUserWithGracePeriod() async {
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

  /* ───────────────── main checker */
  Future<void> _checkUserRole() async {
    debugPrint("🔍 Checking user authentication status…");
    Widget nextPage = const LoginPage();

    try {
      final User? user = await _getCurrentUserWithGracePeriod();
      if (user == null) {
        debugPrint("❌ No user after grace period → LoginPage");
        _navigateTo(nextPage);
        return;
      }
      debugPrint("✅ User is logged in: ${user.email}");

      await user.reload();
      if (!user.emailVerified) {
        debugPrint("⚠️ Email NOT verified → EmailVerificationPage");
        nextPage = const EmailVerificationPage();
        _navigateTo(nextPage);
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!snap.exists) {
        debugPrint("❌ User doc not found → LoginPage");
        _navigateTo(nextPage);
        return;
      }

      final String role = snap['role'].toString().trim().toLowerCase();
      debugPrint("🚀 Role fetched from Firestore: $role");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("userRole", role);

      /* ───────── redirect logic */
      if (role == 'customer') {
        debugPrint("🚀 CUSTOMER → MarketplacePage (with customer nav)");
        nextPage = const MarketplacePage();
      } else if (role == 'trainer' ||
          role == 'personal trainer' ||
          role == 'personaltrainer') {
        debugPrint("🔍 TRAINER. Checking trainer profile…");

        try {
          final profileDoc = await FirebaseFirestore.instance
              .collection("trainer_profiles")
              .doc(user.uid)
              .get();

          if (profileDoc.exists) {
            final data = profileDoc.data() as Map<String, dynamic>;
            final bool completed = data["completed"] ?? false;
            final bool paymentCompleted = data["paymentCompleted"] ?? false;

            if (!completed) {
              debugPrint("⚠️ Profile incomplete → TrainerProfileSetupPage");
              nextPage = const TrainerProfileSetupPage();
            } else if (!paymentCompleted) {
              debugPrint("⚠️ Payment incomplete → ProfilePage");
              nextPage = const profile.ProfilePage();
            } else {
              debugPrint("✅ All good → MarketplacePage (trainer nav)");
              nextPage = const MarketplacePage();
            }
          } else {
            debugPrint("⚠️ No trainer profile doc → TrainerProfileSetupPage");
            nextPage = const TrainerProfileSetupPage();
          }
        } catch (e) {
          debugPrint("❌ Error fetching trainer profile: $e");
          nextPage = const LoginPage();
        }
      } else {
        debugPrint("❌ Unknown role '$role' → LoginPage");
        nextPage = const LoginPage();
      }
    } catch (e) {
      debugPrint("❌ Error during role checking: $e");
      nextPage = const LoginPage();
    }

    await secureStorage.writeData(
      'last_role_redirect',
      DateTime.now().toIso8601String(),
    );

    _navigateTo(nextPage);
  }

  /* ───────────────── helper nav */
  void _navigateTo(Widget page) {
    if (!mounted) return;
    debugPrint("🔥 NAVIGATING to $page");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
