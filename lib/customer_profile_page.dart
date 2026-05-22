// lib/customer_profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'edit_profile_page_customers.dart';
import 'faq_page.dart';
import 'contact_us_page.dart';
import 'bottom_navigation_customers.dart';
import 'welcome_page.dart';
import 'marketplace_page.dart';
import 'terms_conditions_page.dart';
import 'privacy_policy_page.dart';
import 'legal_documents_page.dart';
import 'secure_storage_service.dart';
import 'widgets/customer_fitness_identity_card.dart';
import 'concierge_inbox_page.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _brandColor = Color(0xFFFFA726);
const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _surfaceRaised = Color(0xFF20242C);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

String prettyAuthError(dynamic error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'Incorrect e-mail or password.';
      case 'user-not-found':
        return 'No account exists for that e-mail address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  /* ───────────── State ───────────── */
  String _displayName = 'Customer Name';
  String _email = 'customer@example.com';
  String? _profileImageUrl;
  bool _loadingProfile = true;
  bool _isAdmin = false;
  String userRole = 'customer';

  final SecureStorageService secureStorage = SecureStorageService();

  /* ───────────── init ───────────── */
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAdminStatus();

    _loadUserRole().then((_) async {
      if (userRole != 'customer' && mounted) {
        final nav = Navigator.of(context);
        await Future<void>.delayed(Duration.zero);
        nav.pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
      }
    });

    secureStorage
        .writeData(
          'last_customer_profile_view',
          DateTime.now().toIso8601String(),
        )
        .catchError((e) => debugPrint('Timestamp write failed: $e'));
  }

  /* ───────────── Firestore & prefs ───────────── */
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loadingProfile = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        if (mounted) setState(() => _loadingProfile = false);
        return;
      }

      final data = doc.data()!;
      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName = (data['lastName'] ?? '').toString().trim();
      final combined = '$firstName $lastName'.trim();

      if (!mounted) return;
      setState(() {
        _displayName = combined.isNotEmpty ? combined : 'Customer Name';
        _email = (data['email'] ?? user.email ?? 'customer@example.com')
            .toString()
            .trim();
        _profileImageUrl = data['profileImageUrl']?.toString();
        _loadingProfile = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingProfile = false);
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
    if (!mounted) {
      userRole = role;
      return;
    }
    setState(() => userRole = role);
  }

  Future<void> _loadAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() => _isAdmin = false);
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _isAdmin = doc.exists && data['active'] == true;
      });
    } catch (e) {
      debugPrint('Error checking admin status: $e');

      if (!mounted) return;

      setState(() => _isAdmin = false);
    }
  }

  Future<void> _refreshProfilePage() async {
    await Future.wait([
      _loadUserData(),
      _loadAdminStatus(),
    ]);
  }

  void _openConciergeInbox() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConciergeInboxPage()),
    );
  }

  /* ───────────── styled info / error / confirm dialogs ───────────── */
  Future<void> _showInfoDialog({
    required String title,
    required String message,
    bool error = false,
    String buttonText = 'OK',
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return AnimatedPadding(
          padding:
              insets + const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Dialog(
                  backgroundColor: _surface,
                  insetPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: _line),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: error ? _danger : _gold,
                          child: Icon(
                            error
                                ? Icons.error_outline_rounded
                                : Icons.info_outline_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: _textMuted,
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: _PrimaryButton(
                            label: buttonText,
                            icon: null,
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Delete',
    Color confirmColor = _danger,
  }) async {
    if (!mounted) return false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return AnimatedPadding(
          padding:
              insets + const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Dialog(
                  backgroundColor: _surface,
                  insetPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: _line),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: confirmColor,
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: _textMuted,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: _SecondaryButton(
                                label: 'Cancel',
                                icon: null,
                                onPressed: () => Navigator.of(ctx).pop(false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PrimaryButton(
                                label: confirmText,
                                icon: null,
                                backgroundColor: confirmColor,
                                textColor: Colors.white,
                                onPressed: () => Navigator.of(ctx).pop(true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((v) => v ?? false);
  }

  /* Email users: ask for password (keyboard-safe) */
  Future<String?> _askForPassword() async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return AnimatedPadding(
          padding:
              insets + const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Dialog(
                  backgroundColor: _surface,
                  insetPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: _line),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: _gold,
                          child: Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Confirm password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Please re-enter your password to continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: _textMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: controller,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: _textMuted),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: _gold,
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: _ink,
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: _PrimaryButton(
                            label: 'Continue',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () => Navigator.of(ctx).pop(true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    final value = (ok == true) ? controller.text.trim() : null;
    controller.dispose();
    return (value == null || value.isEmpty) ? null : value;
  }

  /* ───────────── Auth helpers ───────────── */
  Future<void> _logout() async {
    final nav = Navigator.of(context);

    await FirebaseAuth.instance.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
    await secureStorage.deleteData('userToken');
    await secureStorage.deleteData('last_customer_profile_view');

    if (!mounted) return;
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const WelcomePage()));
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nav = Navigator.of(context);

    final sure = await _showConfirmDialog(
      title: 'Delete your account?',
      message: 'This will permanently remove your account and data.',
      confirmText: 'Delete',
      confirmColor: _danger,
    );
    if (!sure) return;

    final String provider = (user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password');

    final AuthCredential? credential =
        await _obtainFreshCredentialFor(provider);

    if (credential == null) return;

    try {
      await user.reauthenticateWithCredential(credential);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();

      if (credential.providerId == 'google.com') {
        await GoogleSignIn.instance.disconnect();
      }

      await secureStorage.deleteData('userToken');
      await secureStorage.deleteData('last_customer_profile_view');

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await _showInfoDialog(
        title: 'Account deleted',
        message:
            'Your account has been removed successfully. We hope to see you again!',
        error: false,
        buttonText: 'Close',
      );

      if (!mounted) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (_) => false,
      );
    } catch (e) {
      await _showInfoDialog(
        title: 'Couldn\'t delete account',
        message: prettyAuthError(e),
        error: true,
      );
      debugPrint('Delete account error: $e');
    }
  }

  Future<AuthCredential?> _obtainFreshCredentialFor(String providerId) async {
    if (providerId == 'password') {
      final pass = await _askForPassword();
      if (pass == null) return null;

      final user = FirebaseAuth.instance.currentUser!;
      return EmailAuthProvider.credential(email: user.email!, password: pass);
    } else if (providerId == 'google.com') {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;

      return GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
    } else if (providerId == 'apple.com') {
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );

      return OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode,
      );
    } else {
      await _showInfoDialog(
        title: 'Unsupported sign-in method',
        message:
            'We currently do not support deleting accounts signed in with this method.',
        error: true,
      );
      return null;
    }
  }

  Future<void> _openEditProfile() async {
    if (userRole != 'customer') {
      await _showInfoDialog(
        title: 'Access denied',
        message: 'Only customers can edit their profile.',
        error: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePageCustomers()),
    );

    if (!mounted) return;
    await _loadUserData();
  }

  /* ───────────── Bottom nav ───────────── */
  Widget _buildBottomNavigation() =>
      const BottomNavigationCustomers(currentIndex: 4);

  /* ───────────── UI ───────────── */
  @override
  Widget build(BuildContext context) {
    final avatar = (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
        ? NetworkImage(_profileImageUrl!)
        : const AssetImage('assets/default_profile.png') as ImageProvider;

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _ink,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MarketplacePage()),
            );
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _gold,
        backgroundColor: _surface,
        onRefresh: _refreshProfilePage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _buildHeroCard(avatar),
            const SizedBox(height: 16),

            // This separate widget contains the profile-page quiz button/card
            // and opens CustomerQuizPage. Keep expanding the full quiz flow in
            // lib/customer_quiz_page.dart.
            const CustomerFitnessIdentityCard(),

            if (_isAdmin) ...[
              const SizedBox(height: 16),
              _PremiumSectionCard(
                title: 'Fitly Admin',
                children: [
                  _menuTile(
                    Icons.support_agent_rounded,
                    'Concierge Inbox',
                    _openConciergeInbox,
                    subtitle: 'View customer trainer requests',
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            _PremiumSectionCard(
              title: 'Support',
              children: [
                _menuTile(
                  Icons.help_outline_rounded,
                  'FAQ / Help',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FAQPage()),
                  ),
                  subtitle: 'Answers to common Fitly questions',
                ),
                _menuTile(
                  Icons.support_agent_rounded,
                  'Contact Support',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactUsPage()),
                  ),
                  subtitle: 'Get help from the Fitly team',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PremiumSectionCard(
              title: 'Legal',
              children: [
                _menuTile(
                  Icons.description_outlined,
                  'Terms & Conditions',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsConditionsPage(),
                    ),
                  ),
                  subtitle: 'Read the Fitly terms',
                ),
                _menuTile(
                  Icons.lock_outline_rounded,
                  'Privacy Policy',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage()),
                  ),
                  subtitle: 'How your information is handled',
                ),
                _menuTile(
                  Icons.library_books_outlined,
                  'Legal Documents',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LegalDocumentsPage()),
                  ),
                  subtitle: 'View all legal pages',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PremiumSectionCard(
              title: 'Account',
              children: [
                _menuTile(
                  Icons.delete_forever_rounded,
                  'Delete Account',
                  _deleteAccount,
                  subtitle: 'Permanently remove your account',
                  destructive: true,
                ),
                _menuTile(
                  Icons.logout_rounded,
                  'Log Out',
                  _logout,
                  subtitle: 'Sign out of Fitly',
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeroCard(ImageProvider avatar) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E222B),
            Color(0xFF111318),
            Color(0xFF07080A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -52,
            top: -52,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: 0.13),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -80,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _brandColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 16,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 66,
              color: Colors.white.withValues(alpha: 0.035),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    _PremiumAvatar(image: avatar),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _loadingProfile
                          ? const _ProfileLoadingText()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _PremiumLabel(text: 'CUSTOMER PROFILE'),
                                const SizedBox(height: 8),
                                Text(
                                  _displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: _SecondaryButton(
                    label: 'Edit Profile',
                    icon: Icons.edit_rounded,
                    onPressed: _openEditProfile,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
    bool destructive = false,
  }) {
    final color = destructive ? _danger : Colors.white;
    final iconColor = destructive ? _danger : _gold;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: iconColor.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: destructive
                  ? _danger.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── Small reusable premium widgets ───────────────── */

class _PremiumAvatar extends StatelessWidget {
  final ImageProvider image;

  const _PremiumAvatar({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_gold, Color(0xFF6F5422)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.2),
      child: CircleAvatar(
        backgroundColor: _surfaceRaised,
        backgroundImage: image,
      ),
    );
  }
}

class _ProfileLoadingText extends StatelessWidget {
  const _ProfileLoadingText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 118,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 172,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 210,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _PremiumLabel extends StatelessWidget {
  final String text;

  const _PremiumLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _gold.withValues(alpha: 0.92),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color textColor;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? _gold;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 18, color: textColor),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: textColor,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 18, color: Colors.white),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: _line),
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        backgroundColor: Colors.white.withValues(alpha: 0.045),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _PremiumSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PremiumSectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: _PremiumLabel(text: title.toUpperCase()),
          ),
          ...children,
        ],
      ),
    );
  }
}
