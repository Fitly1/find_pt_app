// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'marketplace_page.dart';
import 'trainer_home_page.dart';

/// Predefined specialties with their corresponding colors.
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

  // Controllers for text fields.
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  // For specialties selection.
  List<String> _selectedSpecialties = [];
  final List<String> _allSpecialties = [
    'Strength Training',
    'Recovery',
    'Yoga',
    'Group Training',
    'Pilates',
    'Cardio',
    'HIIT',
    'Endurance',
    'Aerobics',
    'CrossFit',
    'Dance Fitness',
    'Martial Arts',
    'Weight Loss',
    'Pre/Post Pregnancy',
    'Other'
  ];

  // Training Methods selection: "Online" or "Face-to-Face".
  final List<String> _selectedMethods = [];

  bool _isSaving = false;
  final int _selectedIndex = 2; // Default to Profile tab

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Retrieve the user's full name from the "users" collection.
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String displayName = "No Name";
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        String firstName = data["firstName"] ?? "";
        String lastName = data["lastName"] ?? "";
        if (firstName.trim().isNotEmpty || lastName.trim().isNotEmpty) {
          displayName = "$firstName $lastName".trim();
        } else {
          displayName = data["displayName"] ?? "No Name";
        }
      }

      // For now, we leave the profile image URL empty.
      String imageUrl = "";

      // Save the trainer profile.
      await FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(user.uid)
          .set({
        "name": displayName, // Save the full name.
        "description": _descriptionController.text.trim(),
        "location": _locationController.text.trim(),
        "rate": double.tryParse(_rateController.text.trim()) ?? 0.0,
        "specialties": _selectedSpecialties,
        "profileImageUrl": imageUrl,
        "trainingMethods": _selectedMethods,
        "completed": true,
      }, SetOptions(merge: true));

      print("✅ Trainer profile saved successfully for UID: ${user.uid}");
      print("Saved specialties: $_selectedSpecialties");
      print("Saved training methods: $_selectedMethods");

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile saved successfully!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TrainerHomePage()),
      );
    } catch (e) {
      print("❌ Error saving profile: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save profile: ${e.toString()}")),
      );
      setState(() {
        _isSaving = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer Profile Setup"),
        backgroundColor: Colors.blueAccent,
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
