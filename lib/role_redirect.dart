// lib/role_redirect.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'welcome_page.dart';
import 'login_page.dart';
import 'email_verification_page.dart';
import 'profile_page.dart' as profile;
import 'trainer_profile_setup_page.dart';
import 'marketplace_page.dart';
import 'secure_storage_service.dart';
import 'trainer_home_page.dart';

class RoleRedirect extends StatefulWidget {
  const RoleRedirect({super.key});

  @override
  RoleRedirectState createState() => RoleRedirectState();
}

class RoleRedirectState extends State<RoleRedirect> {
  final SecureStorageService secureStorage = SecureStorageService();

  /* ───────── helpers ───────── */
  bool _isSocial(User u) => u.providerData.any(
        (p) => p.providerId == 'apple.com' || p.providerId == 'google.com',
      );

  @override
  void initState() {
    super.initState();
    debugPrint('🏁 RoleRedirect START');
    _markFirstLaunch().then((_) => _checkUserRole());
  }

  Future<void> _markFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('hasRunBefore') ?? false)) {
      debugPrint('🆕 First launch detected');
      await prefs.setBool('hasRunBefore', true);
    }
  }

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

  /* ───────── main decision tree ───────── */
  Future<void> _checkUserRole() async {
    debugPrint("🔍 Checking user authentication status…");
    Widget nextPage = const WelcomePage();               // default fallback

    try {
      final User? initial = await _getCurrentUserWithGracePeriod();
      if (initial == null) {
        debugPrint("❌ No user after grace period → WelcomePage");
        _navigateTo(nextPage);
        return;
      }

      await initial.reload();                                // refresh
      final User user = FirebaseAuth.instance.currentUser!;  // refreshed data
      debugPrint("✅ User is logged in: ${user.email}");

      /* ─── provider-aware e-mail verification ─── */
      final bool isPasswordUser =
          user.providerData.any((p) => p.providerId == 'password');

      if (isPasswordUser && !user.emailVerified) {
        debugPrint("⚠️ Password user & e-mail NOT verified → EmailVerificationPage");
        _navigateTo(const EmailVerificationPage());
        return;
      }
      /* ────────────────────────────────────────── */

      final snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!snap.exists || snap.data() == null) {
        debugPrint("❌ User doc missing → WelcomePage");
        _navigateTo(nextPage);
        return;
      }

      final String role =
          (snap.data()!['role'] ?? '').toString().trim().toLowerCase();

      if (role.isEmpty) {
        debugPrint("❌ role field empty → WelcomePage");
        _navigateTo(nextPage);
        return;
      }

      debugPrint("🚀 Role from Firestore: $role");
      await (await SharedPreferences.getInstance()).setString("userRole", role);

      if (role == 'customer') {
        nextPage = const MarketplacePage();
      } else if (role == 'trainer' ||
          role == 'personal trainer' ||
          role == 'personaltrainer') {
        nextPage = await _getTrainerLandingPage(user);
      } else {
        debugPrint("❌ Unknown role '$role' → LoginPage");
        nextPage = const LoginPage();
      }
    } catch (e) {
      debugPrint("❌ Error during role checking: $e");
      nextPage = const WelcomePage();
    }

    await secureStorage.writeData(
      'last_role_redirect',
      DateTime.now().toIso8601String(),
    );

    _navigateTo(nextPage);
  }

  /* ───────── trainer helper ───────── */
  Future<Widget> _getTrainerLandingPage(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final completed = (data["completed"] ?? false) == true;
        final paymentCompleted = (data["paymentCompleted"] ?? false) == true;

        if (!completed) return const TrainerProfileSetupPage();
        if (!paymentCompleted) return const profile.ProfilePage();
        return const TrainerHomePage();
      }
      return const TrainerProfileSetupPage();
    } catch (e) {
      debugPrint("❌ Error fetching trainer profile: $e");
      return const LoginPage();
    }
  }

  /* ───────── navigation helper ───────── */
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