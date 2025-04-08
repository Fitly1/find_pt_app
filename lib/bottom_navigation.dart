import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'marketplace_page.dart';
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

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return; // Prevent reloading the same page

    // For restricted pages: Messages (1), Trainer Home (3), Profile (4)
    if ([1, 3, 4].contains(index)) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous || !user.emailVerified) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0)),
              title: const Text(
                "Sign Up",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                "Please create an account or sign in to access features.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomePage(),
                      ),
                    );
                  },
                  child: const Text(
                    "OK",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            );
          },
        );
        return; // Prevent navigation.
      }
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
        nextPage = const TrainerHomePage(showProfileCompleteMessage: false);
        break;
      case 4:
        nextPage = profile.ProfilePage();
        break;
      default:
        nextPage = const MarketplacePage();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);

    // A small red dot widget, displayed when there's something unread/new.
    Widget buildRedDot() {
      return Positioned(
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
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      onTap: (index) => _onItemTapped(context, index),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.store),
          label: 'Marketplace',
        ),
        // MESSAGES
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
        // TRAINER HOME
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.home),
              if (notifications.newReviews > 0) buildRedDot(),
            ],
          ),
          label: 'Trainer Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
