// lib/trainer_profile_setup_page.dart
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

import 'marketplace_page.dart';
import 'trainer_home_page.dart';

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
  /* ------------------------------------------------------------------ */
  /*                            CONTROLLERS                             */
  /* ------------------------------------------------------------------ */
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _rateController = TextEditingController();

  /* ------------------------------------------------------------------ */
  /*                              SUBURBS                               */
  /* ------------------------------------------------------------------ */
  List<Map<String, dynamic>> _allSuburbs = [];
  Map<String, dynamic>? _chosenSuburb;

  /* ------------------------------------------------------------------ */
  /*                             DATA/STATE                             */
  /* ------------------------------------------------------------------ */
  final List<String> _allSpecialties = specialtiesMap.keys.toList();
  List<String> _selectedSpecialties = [];
  final List<String> _selectedMethods = []; // (future use)

  bool _isSaving = false;
  final int _selectedIdx = 2; // bottom-nav

  /* ------------------------------------------------------------------ */
  /*                            LIFECYCLE                               */
  /* ------------------------------------------------------------------ */
  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadSuburbs();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  /* ------------------------------------------------------------------ */
  /*                          LOAD SUBURBS                              */
  /* ------------------------------------------------------------------ */
  Future<void> _loadSuburbs() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/Suburbs.json');
      _allSuburbs = (json.decode(jsonStr) as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load suburbs: $e');
    }
  }

  /* ------------------------------------------------------------------ */
  /*                       ROLE / REDIRECTION                           */
  /* ------------------------------------------------------------------ */
  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // users/{uid}
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;

    // If not a trainer → send to customer front door (Marketplace)
    if (userDoc.exists && userDoc['role'] != 'trainer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MarketplacePage()),
      );
      return;
    }

    // trainer_profiles/{uid}
    final profileDoc = await FirebaseFirestore.instance
        .collection('trainer_profiles')
        .doc(user.uid)
        .get();
    if (!mounted) return;

    // If profile already completed → go straight to TrainerHomePage
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
  }

  /* ------------------------------------------------------------------ */
  /*                        SAVE PROFILE                                */
  /* ------------------------------------------------------------------ */
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Capture these BEFORE any await (no context usage across async gaps)
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        return;
      }

      // --- pull name fields from users/{uid} ---------------------------
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String firstName = '';
      String lastName = '';
      String displayName = 'No Name';

      if (userDoc.exists) {
        final d = userDoc.data() as Map<String, dynamic>;
        firstName = (d['firstName'] ?? '').toString().trim();
        lastName = (d['lastName'] ?? '').toString().trim();

        final combined = '$firstName $lastName'.trim();
        if (combined.isNotEmpty) {
          displayName = combined;
        } else if (d['displayName'] != null &&
            d['displayName'].toString().trim().isNotEmpty) {
          displayName = d['displayName'].toString().trim();
        }
      }

      // Ensure suburb picked (guard against null even if validator passed)
      if (_chosenSuburb == null) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('❌ Please pick a suburb from the list.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // --- location string & geolocation ------------------------------
      final locString =
          '${_chosenSuburb!['Suburb']}, ${_chosenSuburb!['State']} (${_chosenSuburb!['Postcode']})';

      final double lat =
          double.tryParse(_chosenSuburb!['Latitude'].toString()) ?? 0.0;
      final double lng =
          double.tryParse(_chosenSuburb!['Longitude'].toString()) ?? 0.0;

      final rateVal = double.tryParse(_rateController.text.trim()) ?? 0.0;

      // --- Firestore write: trainer_profiles/{uid} --------------------
      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid)
          .set({
        // name fields (to match EditProfilePage + marketplace)
        'firstName': firstName,
        'firstName_lowerCase': firstName.toLowerCase(),
        'lastName': lastName,
        'lastName_lowerCase': lastName.toLowerCase(),
        'displayName': displayName,
        'displayName_lowerCase': displayName.toLowerCase(),
        // legacy 'name' field still used in some places
        'name': displayName,

        // core profile
        'description': _descriptionController.text.trim(),
        'location': locString,
        'geoLocation': {'lat': lat, 'lng': lng},
        'rate': rateVal,
        'specialties': _selectedSpecialties,
        'trainingMethods': _selectedMethods, // stays empty for now
        'profileImageUrl': '',
        'workImageUrls': <String>[],

        // Brand protection:
        // Keep hidden from marketplace until they complete the full profile
        // (e.g., add photo/experience later). You can flip this to true later.
        'completed': false,

        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _isSaving = false);

      // --- 60 % banner ----------------------------------------------
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: kPrimaryOrange,
                  child: Icon(Icons.check, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Great start!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                const Text(
                  'You’re 60% there.\n\n'
                  'Next step: add a profile photo so customers can trust your listing. '
                  'Until then, your profile stays hidden from the marketplace.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted) return;

      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const TrainerHomePage(
            showProfileCompleteMessage: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Failed to save profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /* ------------------------------------------------------------------ */
  /*                        BOTTOM NAVIGATION                           */
  /* ------------------------------------------------------------------ */
  void _onNavItemTapped(int idx) {
    switch (idx) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TrainerHomePage(
              showProfileCompleteMessage: false,
            ),
          ),
        );
        break;
      case 1:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messages feature coming soon!')),
        );
        break;
      default:
        break;
    }
  }

  /* ================================================================== */
  /*                                UI                                  */
  /* ================================================================== */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Trainer Profile Setup',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kPrimaryOrange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // ----------------- FORM CARD --------------------
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
                    'Complete Your Trainer Profile',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // ---- BIO ----
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText:
                          'Bio / Description (include your qualifications)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // ---- SPECIALTIES ----
                  MultiSelectDialogField(
                    items: _allSpecialties
                        .map((e) => MultiSelectItem<String>(e, e))
                        .toList(),
                    title: const Text('Specialties'),
                    buttonText: const Text('Select Specialties'),
                    initialValue: _selectedSpecialties,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onConfirm: (vals) => setState(
                      () => _selectedSpecialties = List<String>.from(vals),
                    ),
                    validator: (vals) => (vals == null || vals.isEmpty)
                        ? 'Please select at least one specialty'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ---- LOCATION (TypeAhead 5.x) ----
                  FormField<Map<String, dynamic>>(
                    validator: (_) => _chosenSuburb == null
                        ? 'Please pick a suburb from the list'
                        : null,
                    builder: (state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Material(
                            child: TypeAheadField<Map<String, dynamic>>(
                              controller: _locationController,
                              suggestionsCallback: (pattern) {
                                if (pattern.isEmpty) return [];
                                final lower = pattern.toLowerCase();
                                return _allSuburbs
                                    .where((s) {
                                      final sub =
                                          s['Suburb'].toString().toLowerCase();
                                      final pc = s['Postcode'].toString();
                                      return sub.contains(lower) ||
                                          pc.contains(pattern);
                                    })
                                    .take(10)
                                    .toList();
                              },
                              itemBuilder: (_, sug) => ListTile(
                                title: Text(
                                    '${sug['Suburb']} (${sug['Postcode']})'),
                              ),
                              onSelected: (sug) {
                                _chosenSuburb = sug;
                                _locationController.text =
                                    '${sug['Suburb']}, ${sug['State']} (${sug['Postcode']})';
                                state.didChange(sug); // mark as filled
                              },
                              emptyBuilder: (_) => const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('No suburb found'),
                              ),
                              builder: (_, textCtrl, focusNode) {
                                return TextField(
                                  controller: textCtrl,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Suburb or Postcode',
                                    border: OutlineInputBorder(),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                state.errorText!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ---- RATE ----
                  TextFormField(
                    controller: _rateController,
                    decoration: const InputDecoration(
                      labelText: 'Rate (\$/hr)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  // ---- SAVE BUTTON ----
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
                              'Save Profile',
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

      /* --------------- Bottom-nav -------------------- */
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIdx,
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
}
