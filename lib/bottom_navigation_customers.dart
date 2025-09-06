// lib/bottom_navigation_customers.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'signup_page.dart';
import 'login_page.dart';
import 'marketplace_page.dart';
import 'messages_page.dart';
import 'listings_page.dart';
import 'edit_listings_page.dart';
import 'customer_profile_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_provider.dart';

class BottomNavigationCustomers extends ConsumerWidget {
  final int currentIndex;
  const BottomNavigationCustomers({super.key, required this.currentIndex});

  // ---------- Auth gate (fast) ----------
  Future<bool> _needsSignIn(int tabIndex) async {
    // Tabs that require auth: Messages(1), Edit Listings(3), Profile(4)
    if (![1, 3, 4].contains(tabIndex)) return false;

    final auth = FirebaseAuth.instance;
    final u = auth.currentUser;

    // If we already have a user, decide immediately
    if (u != null) {
      final isPassword = u.providerData.any((p) => p.providerId == 'password');
      if (u.isAnonymous) return true;
      if (isPassword && !u.emailVerified) return true;
      return false;
    }

    // Firebase might still be initializing; wait briefly
    try {
      final next = await auth
          .authStateChanges()
          .first
          .timeout(const Duration(milliseconds: 250));
      if (next == null || next.isAnonymous) return true;
      final isPassword =
          next.providerData.any((p) => p.providerId == 'password');
      if (isPassword && !next.emailVerified) return true;
      return false;
    } catch (_) {
      // On timeout or error, treat as guest so we show the prompt immediately
      return true;
    }
  }

  // ---------- Bottom sheet: clear role choice & deep links ----------
  Future<void> _showSignUpSheet(BuildContext ctx) async {
    if (!ctx.mounted) return;

    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.message_outlined, size: 36),
                const SizedBox(height: 8),
                const Text(
                  'Sign up or log in to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create an account to use Messages, Edit Listings, and Profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),

                // Primary: Customer signup (most common for this entry point)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_outline),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx); // close sheet
                      if (!ctx.mounted) return;
                      Navigator.pushReplacement(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SignupPage(preselectedRole: 'customer'),
                        ),
                      );
                    },
                    label: const Text(
                      'Sign up as Customer',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Secondary: Trainer signup
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.fitness_center),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Colors.black12),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      if (!ctx.mounted) return;
                      Navigator.pushReplacement(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SignupPage(preselectedRole: 'trainer'),
                        ),
                      );
                    },
                    label: const Text(
                      'Sign up as Trainer',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Existing account
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    if (!ctx.mounted) return;
                    Navigator.pushReplacement(
                      ctx,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text('I already have an account'),
                ),

                // Dismiss
                TextButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Navigation ----------
  Future<void> _onItemTapped(BuildContext context, int index) async {
    if (index == currentIndex) return; // same tab

    // Gate tabs that need auth
    if (await _needsSignIn(index)) {
      if (!context.mounted) return;
      await _showSignUpSheet(context);
      return;
    }

    if (!context.mounted) return;

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
      context,
      MaterialPageRoute(builder: (_) => nextPage),
    );
  }

  // ---------- Build ----------
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
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        );

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      onTap: (i) => _onItemTapped(context, i),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.store),
          label: 'Marketplace',
        ),
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
        const BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'Listings',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.edit),
          label: 'Edit Listings',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
