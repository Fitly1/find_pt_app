import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'marketplace_page.dart';
import 'messages_page.dart';
import 'listings_page.dart';
import 'edit_listings_page.dart';
import 'customer_profile_page.dart';
import 'welcome_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_provider.dart'; // Ensure this file is correct

class BottomNavigationCustomers extends ConsumerWidget {
  final int currentIndex;

  const BottomNavigationCustomers({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return; // Prevent reloading the same page

    final user = FirebaseAuth.instance.currentUser;

    // Restrict certain tabs if user isn't logged in/verified.
    if ([1, 3, 4].contains(index) &&
        (user == null || user.isAnonymous || !user.emailVerified)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0)),
            title: const Text(
              "Sign Up Required",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              "Please create an account or sign in to access this feature.",
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
                    context,
                    MaterialPageRoute(
                      builder: (ctx2) => const WelcomePage(),
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

    Widget nextPage;
    switch (index) {
      case 0:
        nextPage = const MarketplacePage(); // Index 0
        break;
      case 1:
        nextPage = const MessagesPage(); // Index 1
        break;
      case 2:
        nextPage = const ListingsPage(); // Index 2
        break;
      case 3:
        nextPage = const EditListingsPage(); // Index 3 => Edit listings
        break;
      case 4:
        nextPage = const CustomerProfilePage(); // Index 4 => Customer profile
        break;
      default:
        nextPage = const MarketplacePage();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (ctx) => nextPage),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    debugPrint("Unread messages count: ${notifications.unreadMessages}");

    // A small red dot to show when there's an unread message.
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
