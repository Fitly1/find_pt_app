// lib/bottom_navigation.dart   (trainer bar)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trainer_dashboard_page.dart';
import 'messages_page.dart';
import 'listings_page.dart';
import 'trainer_home_page.dart';
import 'profile_page.dart' as profile;
import 'welcome_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_provider.dart';

class BottomNavigation extends ConsumerWidget {
  final int currentIndex;
  const BottomNavigation({super.key, required this.currentIndex});

  /* ───────── helper that waits for FirebaseAuth ───────── */
  Future<bool> _needsSignIn(int tabIndex) async {
    // tabs that require auth / verification
    if (![1, 3, 4].contains(tabIndex)) return false;

    // wait (≤3 s) for FirebaseAuth to hand us the user
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    if (user == null || user.isAnonymous) return true;

    // password users must verify e-mail
    final isPassword = user.providerData.any((p) => p.providerId == 'password');
    if (isPassword && !user.emailVerified) return true;

    // optional: role check (trainer bar should only be for trainers)
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? '';
    if (!(role == 'trainer' || role == 'personal trainer')) return true;

    return false; // all good
  }

  /* ───────── navigation ───────── */
  Future<void> _onItemTapped(BuildContext context, int index) async {
    if (index == currentIndex) return; // already on that tab

    if (await _needsSignIn(index)) {
      if (!context.mounted) return;
      _showAuthDialog(context);
      return;
    }

    if (!context.mounted) return;

    late final Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const TrainerDashboardPage();
        break;
      case 1:
        nextPage = const MessagesPage();
        break;
      case 2:
        nextPage = const ListingsPage();
        break;
      case 3:
        nextPage = const TrainerHomePage(showProfileCompleteMessage: false);
        break;
      case 4:
        nextPage = const profile.ProfilePage();
        break;
      default:
        nextPage = const TrainerDashboardPage();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextPage),
    );
  }

  /* ───────── UI ───────── */
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notificationProvider);

    Widget redDot() => Positioned(
          right: -4,
          top: -4,
          child: Container(
            width: 10,
            height: 10,
            decoration:
                const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
        );

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      onTap: (i) => _onItemTapped(context, i),
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.message),
              if (notes.unreadMessages > 0) redDot(),
            ],
          ),
          label: 'Messages',
        ),
        const BottomNavigationBarItem(
            icon: Icon(Icons.list), label: 'Listings'),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.home),
              if (notes.newReviews > 0) redDot(),
            ],
          ),
          label: 'Trainer Home',
        ),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  /* ───────── dialog helper ───────── */
  void _showAuthDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Up Required',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: const Text(
          'Please create an account or sign in to access this feature.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                  ctx, MaterialPageRoute(builder: (_) => const WelcomePage()));
            },
            child: const Text('OK', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
