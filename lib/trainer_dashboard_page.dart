import 'package:flutter/material.dart';
import 'bottom_navigation.dart'; // 👈 Import your navigation bar

class TrainerDashboardPage extends StatelessWidget {
  const TrainerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trainer Dashboard")),
      body:
          const Center(child: Text("Your listings, messages & calendar here")),
      bottomNavigationBar:
          const BottomNavigation(currentIndex: 0), // 👈 Add this
    );
  }
}
