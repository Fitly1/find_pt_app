import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pages for different routes
import 'login_page.dart';
import 'email_verification_page.dart';
// Instead, import profile_page.dart as profile so we can navigate there.
import 'profile_page.dart' as profile;
import 'trainer_profile_setup_page.dart';
import 'bottom_navigation_customers.dart'; // Customer Nav
import 'bottom_navigation.dart'; // Trainer Nav

import 'secure_storage_service.dart'; // Import your secure storage service

class RoleRedirect extends StatefulWidget {
  const RoleRedirect({super.key});

  @override
  RoleRedirectState createState() => RoleRedirectState();
}

class RoleRedirectState extends State<RoleRedirect> {
  // Create an instance of SecureStorageService (singleton)
  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    debugPrint("🔍 Checking user authentication status...");

    Widget nextPage = const LoginPage();

    try {
      // 1. Grab current user and SharedPreferences.
      final User? user = FirebaseAuth.instance.currentUser;
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // 2. If user is NOT null, proceed.
      if (user != null) {
        debugPrint("✅ User is logged in: ${user.email}");

        // Re-check user’s email verification status.
        await user.reload();
        if (!user.emailVerified) {
          debugPrint(
              "⚠️ User email is NOT verified. Going to EmailVerificationPage...");
          nextPage = const EmailVerificationPage();
        } else {
          debugPrint("✅ Email verified. Checking role...");

          // 3. Check local SharedPrefs first.
          String? role = prefs.getString("userRole");

          if (role == null) {
            // If not in prefs, fetch from Firestore.
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .get();

              if (userDoc.exists) {
                role = (userDoc["role"] as String).toLowerCase();
                // Save to SharedPrefs.
                await prefs.setString("userRole", role);
                debugPrint("🚀 Role fetched from Firestore: $role");
              } else {
                debugPrint(
                    "❌ User document not found in Firestore. Going to LoginPage...");
                nextPage = const LoginPage();
                _navigateTo(nextPage);
                return;
              }
            } catch (e) {
              debugPrint("❌ Error fetching role from Firestore: $e");
              nextPage = const LoginPage();
              _navigateTo(nextPage);
              return;
            }
          } else {
            role = role.toLowerCase();
            debugPrint("✅ Role from SharedPrefs: $role");
          }

          // 4. Redirect based on role.
          if (role == 'customer') {
            debugPrint(
                "🚀 This user is a CUSTOMER. Going to BottomNavigationCustomers...");
            nextPage = const BottomNavigationCustomers(currentIndex: 0);
          } else if (role == 'personal trainer' ||
              role == 'trainer' ||
              role == 'personaltrainer') {
            debugPrint(
                "🔍 This user is a TRAINER. Checking Trainer Profile...");
            try {
              final profileDoc = await FirebaseFirestore.instance
                  .collection("trainer_profiles")
                  .doc(user.uid)
                  .get();

              if (profileDoc.exists) {
                final profileData = profileDoc.data() as Map<String, dynamic>;
                final bool completed = profileData["completed"] ?? false;
                final bool paymentCompleted =
                    profileData["paymentCompleted"] ?? false;

                if (!completed) {
                  debugPrint(
                      "⚠️ Trainer profile incomplete → TrainerProfileSetupPage");
                  nextPage = const TrainerProfileSetupPage();
                } else if (!paymentCompleted) {
                  debugPrint(
                      "⚠️ Payment incomplete → Redirecting to ProfilePage for payment");
                  // Instead of PaymentPage, redirect to ProfilePage which contains the Pay Now button.
                  nextPage = const profile.ProfilePage();
                } else {
                  debugPrint(
                      "✅ Trainer profile & payment done → BottomNavigationTrainers");
                  nextPage = const BottomNavigation(currentIndex: 0);
                }
              } else {
                debugPrint(
                    "⚠️ No Trainer Profile Doc found → TrainerProfileSetupPage");
                nextPage = const TrainerProfileSetupPage();
              }
            } catch (e) {
              debugPrint("❌ Error fetching trainer profile: $e");
              nextPage = const LoginPage();
            }
          } else {
            debugPrint("❌ Unknown role '$role' → Going to LoginPage...");
            nextPage = const LoginPage();
          }
        }
      } else {
        debugPrint("❌ No user found. Going to LoginPage...");
      }
    } catch (e) {
      debugPrint("❌ Error during role checking: $e");
      nextPage = const LoginPage();
    }

    // --- Security Integration: Save last role redirection timestamp securely ---
    await secureStorage.writeData(
      'last_role_redirect',
      DateTime.now().toIso8601String(),
    );
    if (mounted) {
      String? redirectTimestamp =
          await secureStorage.readData('last_role_redirect');
      debugPrint("Last role redirect timestamp: $redirectTimestamp");
    }

    _navigateTo(nextPage);
  }

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
