import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  // ──────────────────────────
  // State
  // ──────────────────────────
  String _displayName = 'Customer Name';
  String _email = 'customer@example.com';
  String? _profileImageUrl;
  String userRole = 'customer'; // default
  final SecureStorageService secureStorage = SecureStorageService();

  // ──────────────────────────
  // init / dispose
  // ──────────────────────────
  @override
  void initState() {
    super.initState();
    _loadUserData();

    // 1️⃣ load role then bounce non-customers away
    _loadUserRole().then((_) {
      if (userRole != 'customer' && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
      }
    });

    // store last-view timestamp
    secureStorage
        .writeData(
            'last_customer_profile_view', DateTime.now().toIso8601String())
        .catchError((e) => debugPrint('Timestamp write failed: $e'));
  }

  // ──────────────────────────
  // Firestore & prefs helpers
  // ──────────────────────────
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

    // 2️⃣ always lower-case
    if (mounted) {
      setState(() {
        userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
      });
    } else {
      userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
    }
  }

  // ──────────────────────────
  // Auth helpers
  // ──────────────────────────
  Future<void> _logout() async {
    // cache navigator early
    final navigator = Navigator.of(context);

    await FirebaseAuth.instance.signOut();
    await secureStorage.deleteData('userToken');
    await secureStorage.deleteData('last_customer_profile_view');

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // cache navigator / messenger for later use
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // 1️⃣ Are you sure?
    final wantsToDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This will permanently remove your account and data. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (wantsToDelete != true) return;

    // 2️⃣ Prompt for password again  ─── (guard context before re-using)
    if (!mounted) return;
    final passController = TextEditingController();
    final reauthConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-enter Password'),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (reauthConfirmed != true) {
      passController.dispose();
      return;
    }

    try {
      // 3️⃣ Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: passController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      // 4️⃣ Delete Firestore record then Firebase account
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();

      // 5️⃣ Clean local storage / prefs
      await secureStorage.deleteData('userToken');
      await secureStorage.deleteData('last_customer_profile_view');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (_) => false,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    } finally {
      passController.dispose();
    }
  }

  // ──────────────────────────
  // Bottom nav
  // ──────────────────────────
  Widget _buildBottomNavigation() =>
      const BottomNavigationCustomers(currentIndex: 4);

  // ──────────────────────────
  // UI
  // ──────────────────────────
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

    // build all menu widgets
    final List<Widget> menuItems = [
      // header
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
      // edit profile
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _editProfileButton(),
      ),
      // menu options
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
        backgroundColor: const Color(0xFFFFA726),
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

  // ──────────────────────────
  // widgets / helpers
  // ──────────────────────────
  Widget _editProfileButton() {
    return ElevatedButton.icon(
      onPressed: () {
        // 3️⃣ guard access to Edit-Profile
        if (userRole == 'customer') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfilePageCustomers()),
          ).then((_) => _loadUserData());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Access restricted to customers only.')),
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
