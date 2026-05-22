// lib/edit_profile_page_customers.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'secure_storage_service.dart';

class EditProfilePageCustomers extends StatefulWidget {
  const EditProfilePageCustomers({super.key});

  @override
  State<EditProfilePageCustomers> createState() =>
      _EditProfilePageCustomersState();
}

class _EditProfilePageCustomersState extends State<EditProfilePageCustomers> {
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
  static const Color _error = Color(0xFFE57373);
  static const Color _darkText = Color(0xFF121212);

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final SecureStorageService secureStorage = SecureStorageService();

  final String _placeholderAsset = 'assets/default_profile.png';

  String _profileImageUrl = '';
  File? _newImageFile;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    String label, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _raisedSoft,
      labelStyle: const TextStyle(
        color: _textMuted,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        color: _textSoft,
        fontWeight: FontWeight.w500,
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _borderStrong),
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

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      _emailController.text = user.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};

      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName = (data['lastName'] ?? '').toString().trim();
      final displayName = (data['displayName'] ?? '').toString().trim();

      final fullName =
          displayName.isNotEmpty ? displayName : '$firstName $lastName'.trim();

      if (!mounted) return;

      setState(() {
        _fullNameController.text = fullName;
        _emailController.text =
            (data['email'] ?? user.email ?? '').toString().trim();
        _phoneController.text = (data['phone'] ?? '').toString().trim();
        _profileImageUrl = (data['profileImageUrl'] ?? '').toString().trim();
        _loading = false;
      });
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'customer edit profile: load user data failed',
      );

      if (!mounted) return;

      setState(() => _loading = false);

      _showSnack(
        'Could not load profile details.',
        backgroundColor: _error,
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (pickedFile == null) return;

      setState(() {
        _newImageFile = File(pickedFile.path);
      });
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'customer edit profile: pick image failed',
      );

      _showSnack(
        'Could not select image. Please try again.',
        backgroundColor: _error,
      );
    }
  }

  Future<String> _uploadProfileImageIfNeeded(String uid) async {
    final file = _newImageFile;

    if (file == null) return _profileImageUrl;

    final storageRef =
        FirebaseStorage.instance.ref().child('profileImages').child('$uid.jpg');

    await storageRef.putFile(file);
    return storageRef.getDownloadURL();
  }

  List<String> _splitFullName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return ['', ''];

    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return [firstName, lastName];
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnack(
          'Session expired. Please log in again.',
          backgroundColor: _error,
        );
        return;
      }

      final fullName = _fullNameController.text.trim();
      final names = _splitFullName(fullName);
      final firstName = names[0];
      final lastName = names[1];

      final imageUrl = await _uploadProfileImageIfNeeded(user.uid);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'firstName': firstName,
          'firstName_lowerCase': firstName.toLowerCase(),
          'lastName': lastName,
          'lastName_lowerCase': lastName.toLowerCase(),
          'displayName': fullName,
          'displayName_lowerCase': fullName.toLowerCase(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'profileImageUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await secureStorage.writeData(
        'last_profile_update_customer',
        DateTime.now().toIso8601String(),
      );

      if (!mounted) return;

      setState(() {
        _profileImageUrl = imageUrl;
        _newImageFile = null;
      });

      _showSnack('Profile updated successfully.');

      Navigator.pop(context);
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'customer edit profile: save profile failed',
      );

      if (!mounted) return;

      _showSnack(
        'Could not update profile. Please try again.',
        backgroundColor: _error,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
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
          Text(
            title,
            style: const TextStyle(
              color: _textMain,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle,
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

  Widget _buildProfilePhotoCard() {
    return _sectionCard(
      title: 'Profile photo',
      subtitle: 'A clear photo helps trainers know who they are speaking to.',
      child: Column(
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  height: 124,
                  width: 124,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_gold, _goldDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.18),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildAvatarImage(),
                  ),
                ),
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: InkWell(
                    onTap: _saving ? null : _pickImage,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _gold,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _card,
                          width: 2.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: _darkText,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_newImageFile != null) ...[
            const SizedBox(height: 12),
            const Text(
              'New photo selected. Tap save to update.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _gold,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (_newImageFile != null) {
      return Image.file(
        _newImageFile!,
        width: 124,
        height: 124,
        fit: BoxFit.cover,
      );
    }

    if (_profileImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _profileImageUrl,
        width: 124,
        height: 124,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) {
          FirebaseCrashlytics.instance.recordError(
            error,
            StackTrace.current,
            reason: 'Customer profile image failed to load',
          );

          return Image.asset(
            _placeholderAsset,
            width: 124,
            height: 124,
            fit: BoxFit.cover,
          );
        },
      );
    }

    return Image.asset(
      _placeholderAsset,
      width: 124,
      height: 124,
      fit: BoxFit.cover,
    );
  }

  Widget _buildDetailsCard() {
    return _sectionCard(
      title: 'Your details',
      subtitle: 'Keep this simple so trainers can contact you clearly.',
      child: Column(
        children: [
          TextFormField(
            controller: _fullNameController,
            cursorColor: _gold,
            style: const TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w600,
            ),
            decoration: _fieldDecoration('Full name'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            readOnly: true,
            style: const TextStyle(
              color: _textMuted,
              fontWeight: FontWeight.w600,
            ),
            decoration: _fieldDecoration(
              'Email address',
              suffixIcon: const Icon(
                Icons.lock_rounded,
                color: _textSoft,
                size: 19,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            cursorColor: _gold,
            style: const TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w600,
            ),
            decoration: _fieldDecoration(
              'Phone number',
              hint: 'Optional',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _saving
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gold, _goldDeep],
                ),
          color: _saving ? _borderStrong : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (!_saving)
              BoxShadow(
                color: _gold.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: _darkText,
            disabledForegroundColor: _textMuted,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  height: 21,
                  width: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    valueColor: AlwaysStoppedAnimation<Color>(_textMain),
                  ),
                )
              : const Text(
                  'Save changes',
                  style: TextStyle(
                    color: _darkText,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: _gold),
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
            'Edit Profile',
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
        body: Stack(
          children: [
            const Positioned.fill(child: _CustomerEditProfileBackground()),
            Positioned.fill(
              child: SafeArea(
                top: false,
                child: _loading
                    ? _buildLoadingState()
                    : GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildProfilePhotoCard(),
                                _buildDetailsCard(),
                                const SizedBox(height: 8),
                                _buildSaveButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerEditProfileBackground extends StatelessWidget {
  const _CustomerEditProfileBackground();

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
