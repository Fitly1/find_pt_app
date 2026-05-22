// lib/role_redirect.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_page.dart';
import 'email_verification_page.dart';
import 'trainer_profile_setup_page.dart';
import 'marketplace_page.dart';
import 'trainer_home_page.dart';
import 'secure_storage_service.dart';
import 'chat_page.dart';
import 'edit_profile_page.dart';

class RoleRedirect extends StatefulWidget {
  const RoleRedirect({super.key});

  @override
  State<RoleRedirect> createState() => _RoleRedirectState();
}

class _RoleRedirectState extends State<RoleRedirect> {
  final SecureStorageService secureStorage = SecureStorageService();

  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);

  @override
  void initState() {
    super.initState();
    _markFirstLaunch().then((_) => _decideNextPage());
  }

  Future<void> _markFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('hasRunBefore') ?? false)) {
      await prefs.setBool('hasRunBefore', true);
    }
  }

  Future<User?> _currentUserWithGrace() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) return user;

    try {
      user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    return user;
  }

  Future<void> _decideNextPage() async {
    Widget nextPage = const MarketplacePage(); // default: show value first

    try {
      final user = await _currentUserWithGrace();

      if (user == null) {
        _go(nextPage);
        return;
      }

      await user.reload();

      final usesPassword =
          user.providerData.any((p) => p.providerId == 'password');

      if (usesPassword && !user.emailVerified) {
        _go(const EmailVerificationPage());
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();

      if (data == null || data['role'] == null) {
        _go(nextPage);
        return;
      }

      String role = data['role'].toString().toLowerCase().trim();

      if (role == 'personal trainer' || role == 'personaltrainer') {
        role = 'trainer';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', role);

      if (role == 'customer') {
        await _ensureCustomerProfile(
          user: user,
          userData: data,
        );

        nextPage = const MarketplacePage();
      } else if (role == 'trainer') {
        nextPage = await _trainerLanding(user.uid);
      } else {
        nextPage = const LoginPage();
      }

      // Resume pending chat ONLY for customers
      try {
        final pendingUid = prefs.getString('pendingChatPeerUid');

        if (pendingUid != null && role == 'customer') {
          await prefs.remove('pendingChatPeerUid');
          await prefs.remove('pendingChatPeerName');

          final me = FirebaseAuth.instance.currentUser;

          if (me != null) {
            final myUid = me.uid;
            final convoId = (myUid.compareTo(pendingUid) < 0)
                ? '${myUid}_$pendingUid'
                : '${pendingUid}_$myUid';

            _go(
              ChatPage(
                conversationId: convoId,
                otherUserId: pendingUid,
              ),
            );
            return;
          }
        }
      } catch (_) {
        // ignore pending chat errors
      }
    } catch (e) {
      debugPrint('RoleRedirect error: $e');
    }

    await secureStorage.writeData(
      'last_role_redirect',
      DateTime.now().toIso8601String(),
    );

    _go(nextPage);
  }

  // ----------------------------
  // Customer profile helper
  // ----------------------------

  Future<void> _ensureCustomerProfile({
    required User user,
    required Map<String, dynamic> userData,
  }) async {
    final uid = user.uid;
    final ref =
        FirebaseFirestore.instance.collection('customer_profiles').doc(uid);

    final snap = await ref.get();

    final first = (userData['firstName'] ?? '').toString().trim();
    final last = (userData['lastName'] ?? '').toString().trim();

    final userDocDisplay = (userData['displayName'] ?? '').toString().trim();
    final authDisplay = (user.displayName ?? '').trim();
    final fallbackDisplay = '$first $last'.trim();

    final displayName = userDocDisplay.isNotEmpty
        ? userDocDisplay
        : authDisplay.isNotEmpty
            ? authDisplay
            : fallbackDisplay;

    final emailFromUserDoc = (userData['email'] ?? '').toString().trim();
    final email =
        emailFromUserDoc.isNotEmpty ? emailFromUserDoc : user.email ?? '';

    final dob = (userData['dob'] ?? '').toString().trim();
    final phone = (userData['phone'] ?? '').toString().trim();

    if (!snap.exists) {
      await ref.set({
        'role': 'customer',
        'email': email,
        'firstName': first,
        'firstName_lowerCase': first.toLowerCase(),
        'lastName': last,
        'lastName_lowerCase': last.toLowerCase(),
        'displayName': displayName,
        'displayName_lowerCase': displayName.toLowerCase(),
        'dob': dob,
        'phone': phone,
        'photoURL': user.photoURL ?? '',
        'profileCompleted': false,
        'quizCompleted': false,
        'fitnessIdentity': '',
        'fitnessIdentityKey': '',
        'badgeAsset': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return;
    }

    final existing = snap.data() ?? <String, dynamic>{};

    final patch = <String, dynamic>{
      'role': 'customer',
      'lastSeenAt': FieldValue.serverTimestamp(),
    };

    if (!existing.containsKey('email') ||
        (existing['email'] ?? '').toString().trim().isEmpty) {
      patch['email'] = email;
    }

    if (!existing.containsKey('firstName')) {
      patch['firstName'] = first;
      patch['firstName_lowerCase'] = first.toLowerCase();
    }

    if (!existing.containsKey('lastName')) {
      patch['lastName'] = last;
      patch['lastName_lowerCase'] = last.toLowerCase();
    }

    if (!existing.containsKey('displayName') ||
        (existing['displayName'] ?? '').toString().trim().isEmpty) {
      patch['displayName'] = displayName;
      patch['displayName_lowerCase'] = displayName.toLowerCase();
    }

    if (!existing.containsKey('dob')) {
      patch['dob'] = dob;
    }

    if (!existing.containsKey('phone')) {
      patch['phone'] = phone;
    }

    if (!existing.containsKey('photoURL')) {
      patch['photoURL'] = user.photoURL ?? '';
    }

    if (!existing.containsKey('profileCompleted')) {
      patch['profileCompleted'] = false;
    }

    if (!existing.containsKey('quizCompleted')) {
      patch['quizCompleted'] = false;
    }

    if (!existing.containsKey('fitnessIdentity')) {
      patch['fitnessIdentity'] = '';
    }

    if (!existing.containsKey('fitnessIdentityKey')) {
      patch['fitnessIdentityKey'] = '';
    }

    if (!existing.containsKey('badgeAsset')) {
      patch['badgeAsset'] = '';
    }

    await ref.set(patch, SetOptions(merge: true));
  }

  // ----------------------------
  // Trainer landing helper
  // ----------------------------

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

  bool _hasProfilePhoto(Map<String, dynamic> data) {
    final url = (data['profileImageUrl'] ?? '').toString().trim();
    return url.isNotEmpty;
  }

  /// Marketplace-ready = safe to show publicly.
  bool _isMarketplaceReady(Map<String, dynamic> data) {
    final completed = (data['completed'] ?? false) == true;
    return completed && _hasBasicTrainerFields(data) && _hasProfilePhoto(data);
  }

  Future<Widget> _trainerLanding(String uid) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection('trainer_profiles').doc(uid);

      var snap = await ref.get();

      if (!snap.exists || snap.data() == null) {
        await ref.set({
          'completed': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        snap = await ref.get();
      }

      final data = snap.data() ?? {};

      if (!_hasBasicTrainerFields(data)) {
        return const TrainerProfileSetupPage();
      }

      if (!_isMarketplaceReady(data)) {
        return const EditProfilePage();
      }

      return const TrainerHomePage();
    } catch (e) {
      debugPrint('trainerLanding error: $e');
      return const LoginPage();
    }
  }

  void _go(Widget page) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _bgBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bgTop,
        body: SafeArea(
          child: Stack(
            children: [
              _RedirectBackground(),
              Center(
                child: _RedirectLoadingCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RedirectBackground extends StatelessWidget {
  const _RedirectBackground();

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

class _RedirectLoadingCard extends StatelessWidget {
  const _RedirectLoadingCard();

  static const Color _card = Color(0xFF111318);
  static const Color _border = Color(0xFF303540);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_gold),
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Loading Fitly',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMain,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Getting your account ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
