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
import 'splashpage.dart';
import 'marketplace_page.dart';
import 'terms_conditions_page.dart';
import 'privacy_policy_page.dart';
import 'legal_documents_page.dart';
import 'secure_storage_service.dart';

/* ───────────────── Brand colour & helpers ───────────────── */
const Color _brandColor = Color(0xFFFFA726);

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
  String userRole = 'customer';
  final SecureStorageService secureStorage = SecureStorageService();

  /* ───────────── init ───────────── */
  @override
  void initState() {
    super.initState();
    _loadUserData();

    _loadUserRole().then((_) async {
      if (userRole != 'customer' && mounted) {
        final nav = Navigator.of(context);
        await Future<void>.delayed(Duration.zero);
        nav.pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashPage()));
      }
    });

    secureStorage
        .writeData(
            'last_customer_profile_view', DateTime.now().toIso8601String())
        .catchError((e) => debugPrint('Timestamp write failed: $e'));
  }

  /* ───────────── Firestore & prefs ───────────── */
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final firstName = data['firstName'] ?? '';
      final lastName = data['lastName'] ?? '';
      final combined = '$firstName $lastName'.trim();

      if (!mounted) return;
      setState(() {
        _displayName = combined.isNotEmpty ? combined : 'Customer Name';
        _email = data['email'] ?? 'customer@example.com';
        _profileImageUrl = data['profileImageUrl'];
      });
    } catch (e) {
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
              insets + const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: error ? Colors.red : _brandColor,
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
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, height: 1.45),
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
                            child: Text(buttonText,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white)),
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
    Color confirmColor = Colors.red,
  }) async {
    if (!mounted) return false;
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return AnimatedPadding(
          padding:
              insets + const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: confirmColor,
                          child: const Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 38),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, height: 1.45),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Colors.black),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: confirmColor,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(confirmText,
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.white)),
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
              insets + const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: _brandColor,
                          child: const Icon(Icons.lock_outline,
                              color: Colors.white, size: 38),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Confirm password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Please re-enter your password to continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: controller,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
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
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Continue',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)),
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
    final nav = Navigator.of(context); // capture before awaits
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
    await secureStorage.deleteData('userToken');
    await secureStorage.deleteData('last_customer_profile_view');

    if (!mounted) return;
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const SplashPage()));
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nav = Navigator.of(context); // capture before awaits

    /* 1️⃣ confirm */
    final sure = await _showConfirmDialog(
      title: 'Delete your account?',
      message: 'This will permanently remove your account and data.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (!sure) return;

    /* 2️⃣ obtain fresh credential */
    final String provider = (user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password');
    final AuthCredential? credential =
        await _obtainFreshCredentialFor(provider);
    if (credential == null) return; // aborted

    try {
      await user.reauthenticateWithCredential(credential);

      /* 3️⃣ Firestore → Auth */
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();

      if (credential.providerId == 'google.com') {
        // v7 API: singleton + disconnect to revoke
        await GoogleSignIn.instance.disconnect();
      }

      /* 4️⃣ local cleanup */
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
        MaterialPageRoute(builder: (_) => const SplashPage()),
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
      // v7+ flow: interactive authenticate() returns non-null account
      final googleUser = await GoogleSignIn.instance.authenticate();

      // New API: synchronous authentication object; accessToken is not provided.
      final googleAuth = googleUser.authentication;

      return GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        // accessToken no longer available/required for Google on Firebase
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MarketplacePage()),
            );
          },
        ),
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: _brandColor,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header card with gradient + avatar
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE0B2), _brandColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Flutter 3.35: prefer withValues
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    CircleAvatar(radius: 36, backgroundImage: avatar),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (userRole == 'customer') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const EditProfilePageCustomers(),
                                ),
                              ).then((_) => _loadUserData());
                            } else {
                              _showInfoDialog(
                                title: 'Access denied',
                                message:
                                    'Only customers can edit their profile.',
                                error: true,
                              );
                            }
                          },
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Quick actions / Menu cards
          _SectionCard(
            title: 'Support',
            children: [
              _menuTile(
                Icons.help_outline,
                'FAQ / Help',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FAQPage())),
              ),
              _menuTile(
                Icons.support_agent,
                'Contact Us / Support',
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ContactUsPage())),
              ),
            ],
          ),

          _SectionCard(
            title: 'Legal',
            children: [
              _menuTile(
                Icons.description_outlined,
                'Terms & Conditions',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TermsConditionsPage()),
                ),
                subtitle: 'View Terms & Conditions',
              ),
              _menuTile(
                Icons.lock_outline,
                'Privacy Policy',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                ),
              ),
              _menuTile(
                Icons.library_books_outlined,
                'Legal Documents',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalDocumentsPage()),
                ),
              ),
            ],
          ),

          _SectionCard(
            title: 'Account',
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete Account',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
                onTap: _deleteAccount,
                trailing: const Icon(Icons.chevron_right),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log Out',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: _logout,
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  /* ───────────── widgets ───────────── */

  Widget _menuTile(IconData icon, String title, VoidCallback onTap,
      {String? subtitle}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: (subtitle != null)
          ? Text(subtitle, style: const TextStyle(color: Colors.black54))
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/* Small section card wrapper for pretty grouping */
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54),
              ),
            ),
            const Divider(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}
