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

/* ───────────────── Brand colour & helpers ───────────────── */
const Color _brandColor = Color(0xFFFFA726);

/* Same mapping function you used on the login page */
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
  String userRole = 'customer'; // default
  final SecureStorageService secureStorage = SecureStorageService();

  /* ───────────── init ───────────── */
  @override
  void initState() {
    super.initState();
    _loadUserData();

    _loadUserRole().then((_) {
      if (userRole != 'customer' && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
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
    if (mounted) {
      setState(() {
        userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
      });
    } else {
      userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
    }
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
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
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(buttonText,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
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
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.45)),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: 16, color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
    ).then((v) => v ?? false);
  }

  /* ───────────── Auth helpers ───────────── */
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', 'guest');
    await secureStorage.deleteData('userToken');
    await secureStorage.deleteData('last_customer_profile_view');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    /* 1️⃣  final confirmation */
    final sure = await _showConfirmDialog(
      title: 'Delete your account?',
      message: 'This will permanently remove your account and data. ',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (!sure) return;

    /* 2️⃣  obtain fresh credential depending on provider */
    final AuthCredential? credential =
        await _obtainFreshCredentialFor(user.providerData.first.providerId);
    if (credential == null) return; // user aborted

    try {
      await user.reauthenticateWithCredential(credential);

      /* 3️⃣  delete in Firestore → FirebaseAuth */
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();

      // for Google: disconnect so account picker appears again
      if (credential.providerId == 'google.com') {
        await GoogleSignIn().disconnect();
      }

      /* 4️⃣  local cleanup & goodbye */
      await secureStorage.deleteData('userToken');
      await secureStorage.deleteData('last_customer_profile_view');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await _showInfoDialog(
        title: 'Account deleted',
        message: 'Your account has been removed successfully. '
            'We hope to see you again!',
        error: false,
        buttonText: 'Close',
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
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

  /* ───────────── obtain credential ───────────── */
  Future<AuthCredential?> _obtainFreshCredentialFor(String providerId) async {
    if (providerId == 'password') {
      final pass = await _askForPassword();
      if (pass == null) return null;
      final user = FirebaseAuth.instance.currentUser!;
      return EmailAuthProvider.credential(
        email: user.email!,
        password: pass,
      );
    } else if (providerId == 'google.com') {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      return GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
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
        message: 'We currently do not support deleting accounts '
            'signed in with this method.',
        error: true,
      );
      return null;
    }
  }

  /* Email users: ask for password in the same brand style */
  Future<String?> _askForPassword() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
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
              const Text('Confirm password',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final value = (ok == true) ? controller.text.trim() : null;
    controller.dispose();
    return (value == null || value.isEmpty) ? null : value;
  }

  /* ───────────── Bottom nav ───────────── */
  Widget _buildBottomNavigation() =>
      const BottomNavigationCustomers(currentIndex: 4);

  /* ───────────── UI ───────────── */
  @override
  Widget build(BuildContext context) {
    const double kHeaderNameSize = 22;
    const double kHeaderEmailSize = 17;
    const double kMenuFontSize = 20;
    const double kTileGap = 10;
    const EdgeInsets kTilePadding =
        EdgeInsets.symmetric(horizontal: 4, vertical: 6);

    final avatar = (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
        ? NetworkImage(_profileImageUrl!)
        : const AssetImage('assets/default_profile.png') as ImageProvider;

    final List<Widget> menuItems = [
      /* header */
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: const Color.fromRGBO(255, 167, 38, 0.25),
        child: Row(
          children: [
            const SizedBox(width: 16),
            CircleAvatar(radius: 40, backgroundImage: avatar),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName,
                    style: const TextStyle(
                        fontSize: kHeaderNameSize,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_email,
                    style: const TextStyle(fontSize: kHeaderEmailSize)),
              ],
            ),
          ],
        ),
      ),
      /* edit profile */
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _editProfileButton(),
      ),
      /* menu options */
      _menuTile(
        Icons.help,
        'FAQ / Help',
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const FAQPage())),
        fontSize: kMenuFontSize,
        padding: kTilePadding,
      ),
      _menuTile(
        Icons.support_agent,
        'Contact Us / Support',
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ContactUsPage())),
        fontSize: kMenuFontSize,
        padding: kTilePadding,
      ),
      _menuTile(
        Icons.description,
        'Terms & Conditions',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TermsConditionsPage())),
        subtitle: 'View Terms & Conditions',
        fontSize: kMenuFontSize,
        padding: kTilePadding,
      ),
      _menuTile(
        Icons.lock,
        'Privacy Policy',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
        fontSize: kMenuFontSize,
        padding: kTilePadding,
      ),
      _menuTile(
        Icons.library_books,
        'Legal Documents',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LegalDocumentsPage())),
        fontSize: kMenuFontSize,
        padding: kTilePadding,
      ),
      ListTile(
        contentPadding: kTilePadding,
        leading: const Icon(Icons.delete_forever, color: Colors.red, size: 26),
        horizontalTitleGap: 16,
        title: Text('Delete Account',
            style: TextStyle(
                color: Colors.red,
                fontSize: kMenuFontSize,
                fontWeight: FontWeight.w500)),
        onTap: _deleteAccount,
      ),
      ListTile(
        contentPadding: kTilePadding,
        leading: const Icon(Icons.logout, size: 26),
        horizontalTitleGap: 16,
        title: Text('Log Out',
            style: TextStyle(
                fontSize: kMenuFontSize, fontWeight: FontWeight.w500)),
        onTap: _logout,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MarketplacePage()),
          ),
        ),
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: _brandColor,
      ),
      backgroundColor: Colors.white,
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 20),
        itemCount: menuItems.length,
        itemBuilder: (_, i) => menuItems[i],
        separatorBuilder: (_, __) => const SizedBox(height: kTileGap),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  /* ───────────── widgets ───────────── */
  Widget _editProfileButton() {
    return ElevatedButton.icon(
      onPressed: () {
        if (userRole == 'customer') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfilePageCustomers()),
          ).then((_) => _loadUserData());
        } else {
          _showInfoDialog(
            title: 'Access denied',
            message: 'Only customers can edit their profile.',
            error: true,
          );
        }
      },
      icon: const Icon(Icons.edit, color: Colors.white, size: 20),
      label: const Text('Edit Profile',
          style: TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
    required double fontSize,
    required EdgeInsets padding,
  }) {
    return ListTile(
      contentPadding: padding,
      horizontalTitleGap: 16,
      leading: Icon(icon, size: 26),
      title: Text(title,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(subtitle,
                  style: TextStyle(
                      fontSize: fontSize - 3, color: Colors.grey[700])),
            )
          : null,
      onTap: onTap,
    );
  }
}
