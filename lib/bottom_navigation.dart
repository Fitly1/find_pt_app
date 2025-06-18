import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'trainer_dashboard_page.dart'; // dashboard (index 0)
import 'messages_page.dart'; // index 1
import 'listings_page.dart'; // index 2
import 'trainer_home_page.dart'; // index 3
import 'profile_page.dart' as profile; // index 4
import 'welcome_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_provider.dart';

class BottomNavigation extends ConsumerWidget {
  final int currentIndex;
  const BottomNavigation({super.key, required this.currentIndex});

  /* ─────────────────────────  NAVIGATION  ───────────────────────── */

  void _onItemTapped(BuildContext context, int index) {
    // already on that tab
    if (index == currentIndex) return;

    // restricted tabs -> Messages(1), Trainer Home(3), Profile(4)
    if ([1, 3, 4].contains(index)) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous || !user.emailVerified) {
        _showAuthDialog(context);
        return;
      }
    }

    // Choose which page to push
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

  /* ───────────────────────────  UI  ────────────────────────────── */

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);

    // Little red unread dot
    Widget redDot() => Positioned(
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
      onTap: (index) => _onItemTapped(context, index),
      items: [
        // DASHBOARD --------------------------------------------------
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        // MESSAGES ---------------------------------------------------
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.message),
              if (notifications.unreadMessages > 0) redDot(),
            ],
          ),
          label: 'Messages',
        ),
        // LISTINGS ---------------------------------------------------
        const BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'Listings',
        ),
        // TRAINER HOME ----------------------------------------------
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.home),
              if (notifications.newReviews > 0) redDot(),
            ],
          ),
          label: 'Trainer Home',
        ),
        // PROFILE ----------------------------------------------------
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  /* ───────────────────────  HELPERS  ──────────────────────────── */

  void _showAuthDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Up',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Please create an account or sign in to access features.',
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
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomePage()),
              );
            },
            child: const Text('OK', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
