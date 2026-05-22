// lib/trainer_dashboard_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'widgets/trainer_dashboard/trainer_dashboard_hero_card.dart';
import 'bottom_navigation.dart';
import 'edit_profile_page.dart';
import 'feature_flags.dart';
import 'invoice_generator_page.dart';
import 'trainer_home_page.dart';

class TrainerDashboardPage extends StatefulWidget {
  const TrainerDashboardPage({super.key});

  @override
  State<TrainerDashboardPage> createState() => _TrainerDashboardPageState();
}

class _TrainerDashboardPageState extends State<TrainerDashboardPage> {
  /* ───────────────── Fitly premium colours ───────────────── */
  static const Color _bgTop = Color(0xFF07080A);
  static const Color _card = Color(0xFF111318);
  static const Color _raised = Color(0xFF20242C);
  static const Color _raisedSoft = Color(0xFF171B22);
  static const Color _border = Color(0xFF303540);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);
  static const Color _danger = Color(0xFFE05A5A);

  /* ───────────────── State ───────────────── */
  bool _loading = true;
  bool _savingSettings = false;
  bool _uploadingLogo = false;
  String? _error;
  String? _logoUrl;

  Map<String, dynamic> _trainerProfile = {};

  final _formKey = GlobalKey<FormState>();
  final _bizCtrl = TextEditingController();
  final _abnCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();

  final _noteTitleCtrl = TextEditingController();
  final _noteDescCtrl = TextEditingController();

  String _trainerId = '';

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _error = 'Not signed in.';
      _loading = false;
      return;
    }

    _trainerId = user.uid;
    _loadDashboardData();
  }

  @override
  void dispose() {
    _bizCtrl.dispose();
    _abnCtrl.dispose();
    _addrCtrl.dispose();
    _emailCtrl.dispose();
    _bankCtrl.dispose();
    _prefixCtrl.dispose();
    _noteTitleCtrl.dispose();
    _noteDescCtrl.dispose();
    super.dispose();
  }

  /* ───────────────── Firestore helpers ───────────────── */

  Future<void> _loadDashboardData() async {
    if (_trainerId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _error = 'Trainer account not found. Please sign in again.';
        _loading = false;
      });

      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(_trainerId)
          .get()
          .timeout(const Duration(seconds: 12));

      final profile = snap.data() ?? <String, dynamic>{};

      final inv = profile['invoiceSettings'] is Map
          ? Map<String, dynamic>.from(profile['invoiceSettings'])
          : <String, dynamic>{};

      _bizCtrl.text = (inv['businessName'] ?? '').toString();
      _abnCtrl.text = (inv['abn'] ?? '').toString();
      _addrCtrl.text = (inv['address'] ?? '').toString();
      _emailCtrl.text = (inv['email'] ?? '').toString();
      _bankCtrl.text = (inv['bankDetails'] ?? '').toString();
      _prefixCtrl.text = (inv['invoicePrefix'] ?? '').toString();

      final logo = (inv['logoUrl'] ?? '').toString().trim();

      if (!mounted) return;

      setState(() {
        _trainerProfile = profile;
        _logoUrl = logo.isEmpty ? null : logo;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Trainer dashboard load error: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Failed to load dashboard. Please pull down to refresh.';
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (_savingSettings) return;

    setState(() => _savingSettings = true);

    try {
      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(_trainerId)
          .set(
        {
          'invoiceSettings': {
            'businessName': _bizCtrl.text.trim(),
            'abn': _abnCtrl.text.trim(),
            'address': _addrCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'bankDetails': _bankCtrl.text.trim(),
            'invoicePrefix': _prefixCtrl.text.trim(),
            if (_logoUrl != null && _logoUrl!.isNotEmpty) 'logoUrl': _logoUrl,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _showSnack('Business details saved.');
    } catch (e) {
      _showSnack(
        'Could not save business details.',
        backgroundColor: _danger,
      );
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _saveNote({String? id}) async {
    final title = _noteTitleCtrl.text.trim();
    final desc = _noteDescCtrl.text.trim();

    if (title.isEmpty) {
      _showSnack(
        'Add a note title.',
        backgroundColor: _danger,
      );
      return;
    }

    final data = {
      'trainerId': _trainerId,
      'title': title,
      'description': desc,
      'timestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (id == null) {
      await FirebaseFirestore.instance.collection('trainer_notes').add(data);
    } else {
      await FirebaseFirestore.instance.collection('trainer_notes').doc(id).set(
        {
          'title': title,
          'description': desc,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<void> _deleteNote(String id) async {
    await FirebaseFirestore.instance
        .collection('trainer_notes')
        .doc(id)
        .delete();

    _showSnack('Note deleted.');
  }

  /* ───────────────── Image upload ───────────────── */

  Future<void> _pickAndUploadLogo() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.png,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Logo',
            toolbarColor: _bgTop,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: _gold,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Logo',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (cropped == null) return;

      setState(() => _uploadingLogo = true);

      final ref = FirebaseStorage.instance
          .ref()
          .child('trainer_logos')
          .child('$_trainerId.png');

      await ref.putFile(
        File(cropped.path),
        SettableMetadata(contentType: 'image/png'),
      );

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(_trainerId)
          .set(
        {
          'invoiceSettings': {'logoUrl': url},
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _logoUrl = url;
        _uploadingLogo = false;
      });

      _showSnack('Logo uploaded.');
    } catch (e) {
      if (!mounted) return;

      setState(() => _uploadingLogo = false);

      _showSnack(
        'Logo upload failed.',
        backgroundColor: _danger,
      );
    }
  }

  /* ───────────────── Utility ───────────────── */

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

  String _displayName() {
    final display = (_trainerProfile['displayName'] ?? '').toString().trim();

    if (display.isNotEmpty) return display;

    final first = (_trainerProfile['firstName'] ?? '').toString().trim();
    final last = (_trainerProfile['lastName'] ?? '').toString().trim();
    final combined = '$first $last'.trim();

    return combined.isNotEmpty ? combined : 'Trainer';
  }

  bool _profileIsVisibleWhenPaywallOff(Map<String, dynamic> data) {
    if (data['profileHidden'] == true ||
        data['isHidden'] == true ||
        data['hidden'] == true) {
      return false;
    }

    if (data['profileVisible'] == false ||
        data['isVisible'] == false ||
        data['visible'] == false) {
      return false;
    }

    return true;
  }

  bool _profileIsActive() {
    if (isTrainerPaymentsEnabled) {
      return (_trainerProfile['isActive'] ?? false) == true;
    }

    return _profileIsVisibleWhenPaywallOff(_trainerProfile);
  }

  bool _hasAnyTextField(List<String> keys, {int minLen = 1}) {
    for (final key in keys) {
      final value = (_trainerProfile[key] ?? '').toString().trim();
      if (value.length >= minLen) return true;
    }

    return false;
  }

  bool _hasAnyListField(List<String> keys) {
    for (final key in keys) {
      final value = _trainerProfile[key];

      if (value is List &&
          value.where((item) => item.toString().trim().isNotEmpty).isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  bool _hasRate() {
    final raw = _trainerProfile['rate'] ??
        _trainerProfile['hourlyRate'] ??
        _trainerProfile['pricePerHour'] ??
        _trainerProfile['sessionRate'];

    if (raw is num) return raw > 0;

    final parsed = double.tryParse(raw?.toString() ?? '');
    return parsed != null && parsed > 0;
  }

  int _profileCompletionPercent() {
    final checks = <bool>[
      _hasAnyTextField([
        'profileImageUrl',
        'photoURL',
        'photoUrl',
        'profilePhotoUrl',
      ]),
      _hasAnyTextField([
        'description',
        'bio',
        'about',
      ], minLen: 80),
      _hasAnyTextField([
        'location',
        'suburb',
        'city',
      ]),
      _hasAnyListField([
        'specialties',
        'services',
        'focusAreas',
      ]),
      _hasRate(),
      _hasAnyTextField([
        'phone',
        'phoneNumber',
        'mobile',
        'contactNumber',
        'contactPhone',
      ], minLen: 6),
      _hasAnyListField([
        'workImageUrls',
        'workImages',
        'portfolioImages',
        'galleryImages',
        'transformationImageUrls',
      ]),
      _trainerProfile['trainerFitnessIdentityV1'] is Map,
    ];

    final complete = checks.where((value) => value).length;
    return ((complete / checks.length) * 100).round();
  }

  TrainerDashboardIdentity? _trainerIdentity() {
    final raw = _trainerProfile['trainerFitnessIdentityV1'];

    if (raw is! Map) return null;

    final data = Map<String, dynamic>.from(raw);
    final key = (data['archetypeId'] ?? '').toString().trim();

    if (key.isEmpty) return null;

    return TrainerDashboardIdentity(
      key: key,
      title: (data['archetypeName'] ?? _titleFromTrainerKey(key)).toString(),
      tagline: (data['tagline'] ?? 'Your coaching identity.').toString(),
      assetPath:
          (data['badgeAsset'] ?? 'assets/badges/trainers/$key.png').toString(),
      accent: _accentForTrainerKey(key),
      fallbackIcon: _fallbackIconForTrainerKey(key),
    );
  }

  String _titleFromTrainerKey(String key) {
    switch (key) {
      case 'the_guide':
        return 'The Guide';
      case 'the_builder':
        return 'The Builder';
      case 'the_sculptor':
        return 'The Sculptor';
      case 'the_challenger':
        return 'The Challenger';
      case 'the_anchor':
        return 'The Anchor';
      default:
        return 'Coaching Identity';
    }
  }

  Color _accentForTrainerKey(String key) {
    switch (key) {
      case 'the_guide':
        return const Color(0xFFC89A54);
      case 'the_builder':
        return const Color(0xFF536FA8);
      case 'the_sculptor':
        return const Color(0xFFC8B7A0);
      case 'the_challenger':
        return const Color(0xFFB64A42);
      case 'the_anchor':
        return const Color(0xFF4FAFA3);
      default:
        return _gold;
    }
  }

  IconData _fallbackIconForTrainerKey(String key) {
    switch (key) {
      case 'the_guide':
        return Icons.explore_rounded;
      case 'the_builder':
        return Icons.account_tree_rounded;
      case 'the_sculptor':
        return Icons.auto_awesome_rounded;
      case 'the_challenger':
        return Icons.local_fire_department_rounded;
      case 'the_anchor':
        return Icons.anchor_rounded;
      default:
        return Icons.workspace_premium_rounded;
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _raisedSoft,
      labelStyle: const TextStyle(
        color: _textMuted,
        fontWeight: FontWeight.w500,
      ),
      errorStyle: const TextStyle(
        color: _danger,
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
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _danger, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  /* ───────────────── Navigation ───────────────── */

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    ).then((_) => _loadDashboardData());
  }

  void _openPublicProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrainerHomePage()),
    ).then((_) => _loadDashboardData());
  }

  void _openInvoiceGenerator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceGeneratorPage(trainerId: _trainerId),
      ),
    );
  }

  /* ───────────────── Dialogs ───────────────── */

  void _openNoteDialog({DocumentSnapshot<Map<String, dynamic>>? note}) {
    _noteTitleCtrl.text = note?.data()?['title'] ?? '';
    _noteDescCtrl.text = note?.data()?['description'] ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _card,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note == null ? 'Add note' : 'Edit note',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteTitleCtrl,
                  cursorColor: _gold,
                  style: const TextStyle(
                    color: _textMain,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration('Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteDescCtrl,
                  maxLines: 4,
                  cursorColor: _gold,
                  style: const TextStyle(
                    color: _textMain,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _fieldDecoration('Description'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textMain,
                          side: const BorderSide(color: _border),
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GoldButton(
                        label: 'Save',
                        onPressed: () async {
                          await _saveNote(id: note?.id);

                          if (!mounted) return;

                          Navigator.pop(dialogContext);
                          _noteTitleCtrl.clear();
                          _noteDescCtrl.clear();

                          _showSnack(
                            note == null ? 'Note added.' : 'Note saved.',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /* ───────────────── Build ───────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        title: const Text(
          'Trainer Dashboard',
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
      bottomNavigationBar: const BottomNavigation(currentIndex: 0),
      body: Stack(
        children: [
          const Positioned.fill(child: _DashboardBackground()),
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _gold),
      );
    }

    if (_error != null) {
      return RefreshIndicator(
        color: _gold,
        backgroundColor: _card,
        onRefresh: _loadDashboardData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: _gold,
                    size: 38,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Dashboard could not load',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GoldButton(
                    label: 'Try again',
                    onPressed: _loadDashboardData,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _gold,
      backgroundColor: _card,
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        child: Column(
          children: [
            _buildHeroCard(),
            const SizedBox(height: 14),
            _buildQuickActionsCard(),
            const SizedBox(height: 14),
            _buildInvoiceSettingsCard(),
            const SizedBox(height: 14),
            _buildNotesCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final identity = _trainerIdentity();
    final active = _profileIsActive();
    final completion = _profileCompletionPercent();
    final imageUrl = (_trainerProfile['profileImageUrl'] ?? '').toString();

    return TrainerDashboardHeroCard(
      displayName: _displayName(),
      imageUrl: imageUrl,
      active: active,
      paymentsEnabled: isTrainerPaymentsEnabled,
      profileReadyPercent: completion,
      identity: identity,
      onOpenEditProfile: _openEditProfile,
    );
  }

  Widget _buildQuickActionsCard() {
    return _DashboardCard(
      title: 'Trainer tools',
      subtitle: 'Quick shortcuts to manage your profile and business.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.visibility_rounded,
                  title: 'View profile',
                  subtitle: 'Customer view',
                  accent: const Color(0xFF4FAFA3),
                  onTap: _openPublicProfile,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.edit_rounded,
                  title: 'Edit profile',
                  subtitle: 'Photos, bio, rate',
                  accent: const Color(0xFFE7B95C),
                  onTap: _openEditProfile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WideActionTile(
            icon: Icons.receipt_long_rounded,
            title: 'Invoice tool',
            subtitle: 'Create a client invoice using saved details.',
            accent: const Color(0xFF7C8FDB),
            onTap: _openInvoiceGenerator,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSettingsCard() {
    return _DashboardCard(
      title: 'Business details',
      subtitle: 'Saved once, reused when generating invoices.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _LogoUploader(
              logoUrl: _logoUrl,
              uploading: _uploadingLogo,
              onTap: _uploadingLogo ? null : _pickAndUploadLogo,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bizCtrl,
              cursorColor: _gold,
              style: const TextStyle(
                color: _textMain,
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecoration('Business name *'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _abnCtrl,
              cursorColor: _gold,
              style: const TextStyle(
                color: _textMain,
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecoration('ABN'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addrCtrl,
              cursorColor: _gold,
              style: const TextStyle(
                color: _textMain,
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecoration('Address'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              cursorColor: _gold,
              style: const TextStyle(
                color: _textMain,
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecoration('Contact email / phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankCtrl,
              maxLines: 3,
              minLines: 2,
              cursorColor: _gold,
              style: const TextStyle(
                color: _textMain,
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecoration('Payment instructions'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prefixCtrl,
              cursorColor: _gold,
              style: const TextStyle(
                color: _textMain,
                fontWeight: FontWeight.w600,
              ),
              decoration: _fieldDecoration('Invoice prefix'),
            ),
            const SizedBox(height: 16),
            _GoldButton(
              label: _savingSettings ? 'Saving...' : 'Save business details',
              onPressed: _savingSettings ? null : _saveSettings,
              loading: _savingSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return _DashboardCard(
      title: 'Trainer notes',
      subtitle: 'Keep simple client or session notes here.',
      trailing: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: _gold,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text(
          'Add',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        onPressed: () => _openNoteDialog(),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _trainerId.isEmpty
            ? null
            : FirebaseFirestore.instance
                .collection('trainer_notes')
                .where('trainerId', isEqualTo: _trainerId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Text(
              'Could not load notes.',
              style: TextStyle(
                color: _danger.withValues(alpha: 0.95),
                fontWeight: FontWeight.w700,
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _gold,
                    strokeWidth: 2.2,
                  ),
                ),
              ),
            );
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'No notes yet.',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          return Column(
            children: List.generate(docs.length, (index) {
              final doc = docs[index];
              final data = doc.data();

              return Column(
                children: [
                  _NoteRow(
                    title: (data['title'] ?? '').toString(),
                    description: (data['description'] ?? '').toString(),
                    onEdit: () => _openNoteDialog(note: doc),
                    onDelete: () => _deleteNote(doc.id),
                  ),
                  if (index != docs.length - 1)
                    Divider(
                      height: 20,
                      thickness: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                ],
              );
            }),
          );
        },
      ),
    );
  }
}

/* ───────────────── Reusable widgets ───────────────── */

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

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
              color: _gold.withValues(alpha: 0.10),
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
              color: _gold.withValues(alpha: 0.06),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const _DashboardCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  static const Color _card = Color(0xFF111318);
  static const Color _border = Color(0xFF303540);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 13.2,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  static const Color _raisedSoft = Color(0xFF171B22);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 128,
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
          decoration: BoxDecoration(
            color: _raisedSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 21,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 14.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 12.2,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _WideActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  static const Color _raisedSoft = Color(0xFF171B22);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
          decoration: BoxDecoration(
            color: _raisedSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textMain,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: accent.withValues(alpha: 0.78),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoUploader extends StatelessWidget {
  final String? logoUrl;
  final bool uploading;
  final VoidCallback? onTap;

  const _LogoUploader({
    required this.logoUrl,
    required this.uploading,
    required this.onTap,
  });

  static const Color _raisedSoft = Color(0xFF171B22);
  static const Color _border = Color(0xFF303540);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
        decoration: BoxDecoration(
          color: _raisedSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              clipBehavior: Clip.antiAlias,
              child: uploading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: _gold,
                          strokeWidth: 2.2,
                        ),
                      ),
                    )
                  : hasLogo
                      ? Image.network(
                          logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.business_rounded,
                              color: _gold,
                            );
                          },
                        )
                      : const Icon(
                          Icons.business_rounded,
                          color: _gold,
                          size: 28,
                        ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLogo ? 'Business logo added' : 'Add business logo',
                    style: const TextStyle(
                      color: _textMain,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    uploading
                        ? 'Uploading...'
                        : hasLogo
                            ? 'Tap to change your invoice logo.'
                            : 'Optional. Used on generated invoices.',
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.upload_rounded,
              color: _gold,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteRow({
    required this.title,
    required this.description,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);
  static const Color _danger = Color(0xFFE05A5A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sticky_note_2_rounded,
            color: _gold,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Untitled note' : title,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.edit_rounded,
              color: _textMuted,
              size: 19,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: _danger,
              size: 19,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _GoldButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  static const Color _gold = Color(0xFFE7B95C);
  static const Color _goldDeep = Color(0xFFC98E2B);
  static const Color _borderStrong = Color(0xFF343A46);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _darkText = Color(0xFF121212);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gold, _goldDeep],
                ),
          color: onPressed == null ? _borderStrong : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (onPressed != null)
              BoxShadow(
                color: _gold.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: _darkText,
            disabledForegroundColor: _textMain,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: _textMain,
                    strokeWidth: 2.2,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: onPressed == null ? _textMain : _darkText,
                    fontSize: 15.3,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
        ),
      ),
    );
  }
}
