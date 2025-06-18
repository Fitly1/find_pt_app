// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

import 'marketplace_page.dart'; // still used for customers only
import 'trainer_home_page.dart'; // trainers land here

const kPrimaryOrange = Color(0xFFFFA726);
const kActionBlack = Colors.black;

/* --------------- specialties palette ---------------- */
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
  State<TrainerProfileSetupPage> createState() =>
      _TrainerProfileSetupPageState();
}

class _TrainerProfileSetupPageState extends State<TrainerProfileSetupPage> {
  /* ---------------- controllers ---------------- */
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _rateController = TextEditingController();

  /* ---------------- data ------------------------ */
  final List<String> _allSpecialties = specialtiesMap.keys.toList();
  List<String> _selectedSpecialties = [];
  final List<String> _selectedMethods = [];

  /* ---------------- ui state -------------------- */
  bool _isSaving = false;
  final int _selectedIndex = 2; // profile tab in bottom-nav

  /* =========================================================
     lifecycle
  ========================================================= */
  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  /* =========================================================
     helpers
  ========================================================= */
  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1️⃣  Determine the account role
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;

    if (userDoc.exists && userDoc['role'] != 'trainer') {
      // Customer → Marketplace
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MarketplacePage()),
      );
      return;
    }

    // 2️⃣  Trainer with an already-completed profile → TrainerHomePage
    final profileDoc = await FirebaseFirestore.instance
        .collection('trainer_profiles')
        .doc(user.uid)
        .get();
    if (!mounted) return;

    if (profileDoc.exists && (profileDoc.data()?['completed'] == true)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TrainerHomePage(
            showProfileCompleteMessage: false,
          ),
        ),
      );
    }
    // Otherwise stay on this page to finish the profile.
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      /* --- derive display name from users/{uid} ------------ */
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String displayName = "No Name";
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final first = data['firstName'] ?? "";
        final last = data['lastName'] ?? "";
        displayName = "$first $last".trim().isNotEmpty
            ? "$first $last".trim()
            : (data['displayName'] ?? "No Name");
      }

      /* --- write trainer profile --------------------------- */
      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid)
          .set({
        'name': displayName,
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'rate': double.tryParse(_rateController.text.trim()) ?? 0.0,
        'specialties': _selectedSpecialties,
        'trainingMethods': _selectedMethods,
        'profileImageUrl': '',
        'completed': true,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Profile saved successfully!"),
          backgroundColor: kPrimaryOrange,
        ),
      );

      // Finished → TrainerHomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TrainerHomePage(
            showProfileCompleteMessage: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Failed to save profile: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /* bottom-nav tap --------------------------------------- */
  void _onNavItemTapped(int index) {
    switch (index) {
      case 0: // Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TrainerHomePage(
              showProfileCompleteMessage: false,
            ),
          ),
        );
        break;
      case 1: // Messages (placeholder)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Messages feature coming soon!")),
        );
        break;
      case 2:
      default:
        // Already on profile-setup
        break;
    }
  }

  /* =========================================================
     UI
  ========================================================= */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Trainer Profile Setup",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kPrimaryOrange,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            tooltip: 'Report this trainer',
            onPressed: _showReportDialog,
          ),
        ],
        elevation: 0,
      ),

      /* ---------------- form body -------------------- */
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Complete Your Trainer Profile",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  /* --- Bio ---------------------------------- */
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText:
                          "Bio / Description (include your qualifications)",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (v) =>
                        v == null || v.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),

                  /* --- Specialties --------------------------- */
                  MultiSelectDialogField(
                    items: _allSpecialties
                        .map((e) => MultiSelectItem<String>(e, e))
                        .toList(),
                    title: const Text("Specialties"),
                    buttonText: const Text("Select Specialties"),
                    initialValue: _selectedSpecialties,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onConfirm: (vals) => setState(
                      () => _selectedSpecialties = List<String>.from(vals),
                    ),
                    validator: (vals) => (vals == null || vals.isEmpty)
                        ? "Please select at least one specialty"
                        : null,
                  ),
                  const SizedBox(height: 16),

                  /* --- Location ------------------------------ */
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: "Location",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),

                  /* --- Rate ---------------------------------- */
                  TextFormField(
                    controller: _rateController,
                    decoration: const InputDecoration(
                      labelText: "Rate (\$/hr)",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 24),

                  /* --- Save Button --------------------------- */
                  _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kActionBlack,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                            child: const Text(
                              "Save Profile",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),

      /* ---------------- bottom-nav ------------------- */
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: kPrimaryOrange,
        unselectedItemColor: Colors.grey,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  /* =========================================================
     Report dialog
  ========================================================= */
  Future<void> _showReportDialog() async {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Report Trainer"),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: "Why are you reporting this trainer?"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text("Submit"),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              Navigator.of(context).pop();

              final user = FirebaseAuth.instance.currentUser;
              final reporter = user?.uid ?? 'unknown';

              try {
                await FirebaseFirestore.instance.collection('reports').add({
                  'reportedBy': reporter,
                  'reportedItemId': reporter, // could be trainer UID
                  'reportedType': 'trainer',
                  'reason': reason,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Trainer reported."),
                      backgroundColor: kPrimaryOrange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error reporting: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
