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
import 'welcome_page.dart';
import 'edit_profile_page.dart';

/* --------------- specialties ---------------- */
const List<String> trainerSpecialties = [
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
  'Other',
];

class TrainerProfileSetupPage extends StatefulWidget {
  const TrainerProfileSetupPage({super.key});

  @override
  State<TrainerProfileSetupPage> createState() =>
      _TrainerProfileSetupPageState();
}

class _TrainerProfileSetupPageState extends State<TrainerProfileSetupPage> {
  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _card = Color(0xFF111318);
  static const Color _raised = Color(0xFF20242C);
  static const Color _raisedSoft = Color(0xFF171B22);
  static const Color _border = Color(0xFF303540);
  static const Color _borderStrong = Color(0xFF343A46);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _goldDeep = Color(0xFFC98E2B);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);
  static const Color _textSoft = Color(0xFF7E8794);
  static const Color _success = Color(0xFF6DD58C);
  static const Color _error = Color(0xFFE57373);

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _rateController = TextEditingController();

  List<Map<String, dynamic>> _allSuburbs = [];
  Map<String, dynamic>? _chosenSuburb;

  final List<String> _allSpecialties = trainerSpecialties;
  List<String> _selectedSpecialties = [];
  final List<String> _selectedMethods = [];

  bool _isSaving = false;

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

  Future<void> _loadSuburbs() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/Suburbs.json');
      _allSuburbs = (json.decode(jsonStr) as List).cast<Map<String, dynamic>>();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load suburbs: $e');
    }
  }

  bool _hasBasicTrainerFields(Map<String, dynamic> data) {
    final desc = (data['description'] ?? '').toString().trim();
    final loc = (data['location'] ?? '').toString().trim();
    final specs = (data['specialties'] is List)
        ? (data['specialties'] as List)
        : const [];
    final rateNum = data['rate'];

    final hasRate = (rateNum is num && rateNum > 0) ||
        (rateNum is String && (double.tryParse(rateNum) ?? 0) > 0);

    return desc.isNotEmpty && loc.isNotEmpty && specs.isNotEmpty && hasRate;
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final userData = userDoc.data() ?? {};
      var role = (userData['role'] ?? '').toString().toLowerCase().trim();

      if (role == 'personal trainer' || role == 'personaltrainer') {
        role = 'trainer';
      }

      if (role != 'trainer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MarketplacePage()),
        );
        return;
      }

      final profileDoc = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final profileData = profileDoc.data() ?? {};

      if (profileDoc.exists && (profileData['completed'] == true)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const TrainerHomePage(
              showProfileCompleteMessage: false,
            ),
          ),
        );
        return;
      }

      if (profileDoc.exists && _hasBasicTrainerFields(profileData)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EditProfilePage()),
        );
      }
    } catch (e) {
      debugPrint('TrainerProfileSetup role check failed: $e');
    }
  }

  InputDecoration _inputDecoration(
    String label, {
    String? helperText,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      filled: true,
      fillColor: _raisedSoft,
      labelStyle: const TextStyle(
        color: _textMuted,
        fontWeight: FontWeight.w500,
      ),
      helperStyle: const TextStyle(
        color: _textSoft,
        fontWeight: FontWeight.w500,
      ),
      prefixStyle: const TextStyle(
        color: _textMain,
        fontWeight: FontWeight.w700,
      ),
      errorStyle: const TextStyle(
        color: _error,
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _gold, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _error, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  void _showSnack(
    String message, {
    Color backgroundColor = _raised,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _formatSuburb(Map<String, dynamic> suburb) {
    return '${suburb['Suburb']}, ${suburb['State']} (${suburb['Postcode']})';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnack(
          'Session expired. Please log in again.',
          backgroundColor: _error,
        );
        return;
      }

      if (_chosenSuburb == null) {
        _showSnack(
          'Please pick a suburb from the list.',
          backgroundColor: _error,
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String firstName = '';
      String lastName = '';
      String displayName = 'No Name';

      if (userDoc.exists) {
        final data = userDoc.data() ?? <String, dynamic>{};

        firstName = (data['firstName'] ?? '').toString().trim();
        lastName = (data['lastName'] ?? '').toString().trim();

        final combined = '$firstName $lastName'.trim();

        if (combined.isNotEmpty) {
          displayName = combined;
        } else if ((data['displayName'] ?? '').toString().trim().isNotEmpty) {
          displayName = data['displayName'].toString().trim();
        }
      }

      final trainerRef = FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid);

      final existingTrainerSnap = await trainerRef.get();
      final existingTrainerData =
          existingTrainerSnap.data() ?? <String, dynamic>{};

      final locString = _formatSuburb(_chosenSuburb!);

      final double lat =
          double.tryParse(_chosenSuburb!['Latitude'].toString()) ?? 0.0;
      final double lng =
          double.tryParse(_chosenSuburb!['Longitude'].toString()) ?? 0.0;

      final rateVal = double.tryParse(_rateController.text.trim()) ?? 0.0;

      final payload = <String, dynamic>{
        'firstName': firstName,
        'firstName_lowerCase': firstName.toLowerCase(),
        'lastName': lastName,
        'lastName_lowerCase': lastName.toLowerCase(),
        'displayName': displayName,
        'displayName_lowerCase': displayName.toLowerCase(),
        'name': displayName,

        'description': _descriptionController.text.trim(),
        'location': locString,
        'geoLocation': {'lat': lat, 'lng': lng},
        'rate': rateVal,
        'specialties': _selectedSpecialties,
        'trainingMethods': _selectedMethods,

        // Not marketplace-ready yet. Photo + full profile polish happens next.
        'completed': false,
        'setupBasicsCompleted': true,
        'setupBasicsCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!existingTrainerSnap.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      if (!existingTrainerData.containsKey('profileImageUrl')) {
        payload['profileImageUrl'] = '';
      }

      if (!existingTrainerData.containsKey('workImageUrls')) {
        payload['workImageUrls'] = <String>[];
      }

      await trainerRef.set(payload, SetOptions(merge: true));

      if (!mounted) return;

      setState(() => _isSaving = false);

      await _showSuccessDialog();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EditProfilePage()),
      );
    } catch (e) {
      debugPrint('Failed to save trainer profile setup: $e');

      if (!mounted) return;

      _showSnack(
        'Failed to save profile. Please try again.',
        backgroundColor: _error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: _card,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 62,
                  width: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _success.withValues(alpha: 0.13),
                    border: Border.all(
                      color: _success.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: _success,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Great start',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your basics are saved. Add a profile photo next so customers can trust your listing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 14.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your profile stays hidden until it is ready.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSoft,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_gold, _goldDeep],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFF121212),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Continue to add photo',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF121212),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _bgBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bgTop,
        appBar: AppBar(
          title: const Text(
            'Trainer Setup',
            style: TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          backgroundColor: _bgTop,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _textMain),
          surfaceTintColor: Colors.transparent,
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              const Positioned.fill(child: _SetupBackground()),
              Positioned.fill(
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildHeaderCard(),
                          const SizedBox(height: 16),
                          _buildFormCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _gold.withValues(alpha: 0.38),
              ),
            ),
            child: const Text(
              'Step 1 of 2 • Basics',
              style: TextStyle(
                color: _gold,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 78,
            width: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _raised,
              border: Border.all(
                color: _gold.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.15),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: _gold,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Set up your trainer profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMain,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Add a few basics first. You’ll add your photo and polish next.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 14.8,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('Short bio'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            minLines: 3,
            cursorColor: _gold,
            style: const TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              'Bio / qualifications',
              helperText: 'Keep it short. Customers can scan it later.',
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          _sectionLabel('Specialties'),
          const SizedBox(height: 8),
          _buildSpecialtiesField(),
          const SizedBox(height: 16),
          _sectionLabel('Location'),
          const SizedBox(height: 8),
          _buildLocationField(),
          const SizedBox(height: 16),
          _sectionLabel('Rate'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            cursorColor: _gold,
            style: const TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(
              'Hourly rate',
              prefixText: '\$ ',
            ),
            validator: (value) {
              final rate = double.tryParse((value ?? '').trim());

              if (rate == null || rate <= 0) {
                return 'Enter your hourly rate';
              }

              return null;
            },
          ),
          const SizedBox(height: 22),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textMain,
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildSpecialtiesField() {
    return MultiSelectDialogField<String>(
      items: _allSpecialties
          .map((specialty) => MultiSelectItem<String>(specialty, specialty))
          .toList(),
      title: const Text(
        'Specialties',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      buttonText: Text(
        _selectedSpecialties.isEmpty
            ? 'Select specialties'
            : '${_selectedSpecialties.length} selected',
        style: const TextStyle(
          color: _textMuted,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      decoration: BoxDecoration(
        color: _raisedSoft,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      selectedColor: _gold,
      checkColor: const Color(0xFF121212),
      confirmText: const Text(
        'Done',
        style: TextStyle(color: _gold, fontWeight: FontWeight.w800),
      ),
      cancelText: const Text(
        'Cancel',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      initialValue: _selectedSpecialties,
      onConfirm: (values) {
        setState(() => _selectedSpecialties = List<String>.from(values));
      },
      validator: (values) => (values == null || values.isEmpty)
          ? 'Please select at least one specialty'
          : null,
      chipDisplay: MultiSelectChipDisplay<String>(
        textStyle: const TextStyle(
          color: Color(0xFF121212),
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
        chipColor: _gold,
        onTap: (value) {
          setState(() => _selectedSpecialties.remove(value));
        },
      ),
    );
  }

  Widget _buildLocationField() {
    return FormField<Map<String, dynamic>>(
      validator: (_) =>
          _chosenSuburb == null ? 'Please pick a suburb from the list' : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TypeAheadField<Map<String, dynamic>>(
              controller: _locationController,
              suggestionsCallback: (pattern) {
                if (pattern.trim().isEmpty) return [];

                final lower = pattern.toLowerCase().trim();

                return _allSuburbs
                    .where((suburb) {
                      final suburbName =
                          suburb['Suburb'].toString().toLowerCase();
                      final postcode = suburb['Postcode'].toString();

                      return suburbName.contains(lower) ||
                          postcode.contains(pattern.trim());
                    })
                    .take(10)
                    .toList();
              },
              itemBuilder: (context, suburb) {
                return Container(
                  color: _card,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      '${suburb['Suburb']} (${suburb['Postcode']})',
                      style: const TextStyle(
                        color: _textMain,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      suburb['State'].toString(),
                      style: const TextStyle(
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
              onSelected: (suburb) {
                _chosenSuburb = suburb;
                _locationController.text = _formatSuburb(suburb);
                state.didChange(suburb);
              },
              emptyBuilder: (context) {
                return Container(
                  color: _card,
                  padding: const EdgeInsets.all(14),
                  child: const Text(
                    'No suburb found',
                    style: TextStyle(
                      color: _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
              builder: (context, textController, focusNode) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  cursorColor: _gold,
                  style: const TextStyle(
                    color: _textMain,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _inputDecoration('Suburb or postcode'),
                  onChanged: (value) {
                    if (_chosenSuburb != null &&
                        value.trim() != _formatSuburb(_chosenSuburb!)) {
                      _chosenSuburb = null;
                      state.didChange(null);
                    }
                  },
                );
              },
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: _error,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isSaving
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gold, _goldDeep],
                ),
          color: _isSaving ? _borderStrong : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (!_isSaving)
              BoxShadow(
                color: _gold.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF121212),
            disabledForegroundColor: _textMuted,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 21,
                  width: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    valueColor: AlwaysStoppedAnimation<Color>(_textMain),
                  ),
                )
              : const Text(
                  'Save and continue',
                  style: TextStyle(
                    color: Color(0xFF121212),
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SetupBackground extends StatelessWidget {
  const _SetupBackground();

  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _gold = Color(0xFFE7B95C);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -140,
          right: -120,
          child: Container(
            height: 290,
            width: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.11),
            ),
          ),
        ),
        Positioned(
          bottom: -170,
          left: -140,
          child: Container(
            height: 340,
            width: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.07),
            ),
          ),
        ),
      ],
    );
  }
}
