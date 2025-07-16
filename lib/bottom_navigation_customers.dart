// lib/bottom_navigation_customers.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'marketplace_page.dart';
import 'messages_page.dart';
import 'listings_page.dart';
import 'edit_listings_page.dart';
import 'customer_profile_page.dart';
import 'welcome_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_provider.dart';

class BottomNavigationCustomers extends ConsumerWidget {
  final int currentIndex;
  const BottomNavigationCustomers({super.key, required this.currentIndex});

  /* ---------- helper that waits for auth & prefs ----------- */
  Future<bool> _needsSignIn(int tabIndex) async {
    // tabs that require auth / verification
    if (![1, 3, 4].contains(tabIndex)) return false;

    // wait (≤3 s) for FirebaseAuth
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

    // e-mail verified check (password users only)
    final isPassword =
        user.providerData.any((p) => p.providerId == 'password');
    if (isPassword && !user.emailVerified) return true;

    // good to go
    return false;
  }

  /* ---------- navigation ---------- */
  Future<void> _onItemTapped(BuildContext context, int index) async {
    if (index == currentIndex) return; // same tab

    if (await _needsSignIn(index)) {
      _showSignUpDialog(context);
      return;
    }

    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const MarketplacePage();
        break;
      case 1:
        nextPage = const MessagesPage();
        break;
      case 2:
        nextPage = const ListingsPage();
        break;
      case 3:
        nextPage = const EditListingsPage();
        break;
      case 4:
        nextPage = const CustomerProfilePage();
        break;
      default:
        nextPage = const MarketplacePage();
    }

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => nextPage));
  }

  /* ---------- dialog ---------- */
  void _showSignUpDialog(BuildContext ctx) {
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.pushReplacement(
                  ctx, MaterialPageRoute(builder: (_) => const WelcomePage()));
            },
            child: const Text('OK', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  /* ---------- build ---------- */
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);

    Widget buildRedDot() => Positioned(
          right: -4,
          top: -4,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
                color: Colors.red, shape: BoxShape.circle),
          ),
        );

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      onTap: (i) => _onItemTapped(context, i),
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.store), label: 'Marketplace'),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.message),
              if (notifications.unreadMessages > 0) buildRedDot(),
            ],
          ),
          label: 'Messages',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Listings'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.edit), label: 'Edit Listings'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}