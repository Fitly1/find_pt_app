// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

import 'marketplace_page.dart';
import 'trainer_home_page.dart';

const Map<String, Color> specialtiesMap = {
  'Strength Training': Colors.blue,
  'Recovery': Colors.green,
  'Yoga': Colors.purple,
  'Group Training': Colors.orange,
  'Pilates': Colors.pink,
  'Cardio': Colors.red,
  'HIIT': Colors.teal,
  'Endurance': Colors.amber,
  'Aerobics': Colors.cyan,
  'CrossFit': Colors.lime,
  'Dance Fitness': Colors.indigo,
  'Martial Arts': Colors.brown,
  'Weight Loss': Colors.lightGreen,
  'Pre/Post Pregnancy': Colors.deepPurple,
  'Other': Colors.grey,
};

class TrainerProfileSetupPage extends StatefulWidget {
  const TrainerProfileSetupPage({super.key});

  @override
  TrainerProfileSetupPageState createState() => TrainerProfileSetupPageState();
}

class TrainerProfileSetupPageState extends State<TrainerProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  List<String> _selectedSpecialties = [];
  final List<String> _allSpecialties = specialtiesMap.keys.toList();
  final List<String> _selectedMethods = [];

  bool _isSaving = false;
  final int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Ensure the widget is still mounted before using context
      if (!mounted) return;

      if (userDoc.exists && userDoc['role'] != 'trainer') {
        // Redirect to MarketplacePage if the user role is not trainer
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MarketplacePage()),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String displayName = "No Name";
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        String firstName = data["firstName"] ?? "";
        String lastName = data["lastName"] ?? "";
        displayName = "$firstName $lastName".trim().isNotEmpty
            ? "$firstName $lastName".trim()
            : (data["displayName"] ?? "No Name");
      }

      await FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(user.uid)
          .set({
        "name": displayName,
        "description": _descriptionController.text.trim(),
        "location": _locationController.text.trim(),
        "rate": double.tryParse(_rateController.text.trim()) ?? 0.0,
        "specialties": _selectedSpecialties,
        "profileImageUrl": "",
        "trainingMethods": _selectedMethods,
        "completed": true,
      }, SetOptions(merge: true));

      print("✅ Trainer profile saved for UID: ${user.uid}");

      if (!mounted) return; // Check if the widget is still mounted

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile saved successfully!")),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TrainerHomePage()),
        );
      }
    } catch (e) {
      print("❌ Error saving profile: $e");

      if (!mounted) return; // Check if the widget is still mounted

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save profile: ${e.toString()}")),
      );

      setState(() => _isSaving = false);
    }
  }

  void _onNavItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MarketplacePage()),
      );
    } else if (index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Messages feature coming soon!")),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const TrainerProfileSetupPage()),
      );
    }
  }

  Future<void> _showReportDialog() async {
    final TextEditingController reasonController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Report Trainer"),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Why are you reporting this trainer?",
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text("Submit"),
              onPressed: () async {
                final String reason = reasonController.text.trim();
                if (reason.isEmpty) return;

                Navigator.of(context).pop(); // Close the dialog

                final User? user = FirebaseAuth.instance.currentUser;
                final String? trainerId = user?.uid;

                try {
                  await FirebaseFirestore.instance.collection('reports').add({
                    'reportedBy': user?.uid ?? 'unknown',
                    'reportedItemId': trainerId,
                    'reportedType': 'trainer',
                    'reason': reason,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text("Trainer reported.")),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                          content: Text("Error reporting: ${e.toString()}")),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer Profile Setup"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            tooltip: 'Report this trainer',
            onPressed: _showReportDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Complete Your Trainer Profile",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Bio / Description (include your qualifications)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) =>
                    value == null || value.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              MultiSelectDialogField(
                items: _allSpecialties
                    .map((e) => MultiSelectItem<String>(e, e))
                    .toList(),
                title: const Text("Specialties"),
                buttonText: const Text("Select Specialties"),
                initialValue: _selectedSpecialties,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                onConfirm: (values) {
                  setState(() {
                    _selectedSpecialties = List<String>.from(values);
                  });
                },
                validator: (values) {
                  if (values == null || values.isEmpty) {
                    return "Please select at least one specialty";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: "Location",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rateController,
                decoration: const InputDecoration(
                  labelText: "Rate (\$/hr)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: const Text("Save Profile"),
                      ),
                    ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.store), label: 'Marketplace'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
