import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page_customers.dart';
import 'faq_page.dart';
import 'contact_us_page.dart';
import 'bottom_navigation_customers.dart'; // Importing customer bottom navigation
import 'welcome_page.dart';
import 'marketplace_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _displayName = 'Customer Name';
  String _email = 'customer@example.com';
  String? _profileImageUrl;
  String userRole = 'customer';

  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserRole();

    secureStorage
        .writeData(
            'last_customer_profile_view', DateTime.now().toIso8601String())
        .catchError((e) => debugPrint('Timestamp write failed: $e'));
  }

  // Load user data from Firestore
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final firstName = data?['firstName'] ?? '';
        final lastName = data?['lastName'] ?? '';
        final combined = '$firstName $lastName'.trim();

        setState(() {
          _displayName = combined.isNotEmpty ? combined : 'Customer Name';
          _email = data?['email'] ?? 'customer@example.com';
          _profileImageUrl = data?['profileImageUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // Load user role from SharedPreferences
  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
    });
  }

  // Logout function
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    await secureStorage.deleteData('userToken');
    await secureStorage.deleteData('last_customer_profile_view');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
    );
  }

  // Account deletion function
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
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

    if (confirmed != true) return;

    try {
      // Deleting user data from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();
      await secureStorage.deleteData('userToken');
      await secureStorage.deleteData('last_customer_profile_view');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  // Bottom navigation widget based on user role
  Widget _buildBottomNavigation() {
    return const BottomNavigationCustomers(currentIndex: 4);
  }

  @override
  Widget build(BuildContext context) {
    // typography sizes
    const double kHeaderNameSize = 22;
    const double kHeaderEmailSize = 17;
    const double kMenuFontSize = 20;
    const double kTileGap = 10; // space BETWEEN tiles
    const EdgeInsets kTilePadding =
        EdgeInsets.symmetric(horizontal: 4, vertical: 6); // inside each tile

    final avatar = (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
        ? NetworkImage(_profileImageUrl!)
        : const AssetImage('assets/default_profile.png') as ImageProvider;

    // Menu items for the profile page
    final List<Widget> menuItems = [
      // Header block
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
                    style: TextStyle(
                        fontSize: kHeaderNameSize,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_email, style: TextStyle(fontSize: kHeaderEmailSize)),
              ],
            ),
          ],
        ),
      ),
      // Edit Profile Button
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _editProfileButton(),
      ),
      _menuTile(
          Icons.help,
          'FAQ / Help',
          () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const FAQPage())),
          fontSize: kMenuFontSize,
          padding: kTilePadding),
      _menuTile(
          Icons.support_agent,
          'Contact Us / Support',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ContactUsPage())),
          fontSize: kMenuFontSize,
          padding: kTilePadding),
      _menuTile(
          Icons.description,
          'Terms & Conditions',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TermsConditionsPage())),
          subtitle: 'View Terms & Conditions',
          fontSize: kMenuFontSize,
          padding: kTilePadding),
      _menuTile(
          Icons.lock,
          'Privacy Policy',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
          fontSize: kMenuFontSize,
          padding: kTilePadding),
      _menuTile(
          Icons.library_books,
          'Legal Documents',
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LegalDocumentsPage())),
          fontSize: kMenuFontSize,
          padding: kTilePadding),
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

  // Edit Profile Button
  Widget _editProfileButton() {
    return ElevatedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EditProfilePageCustomers()),
      ).then((_) => _loadUserData()),
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

  // Menu Tile
  Widget _menuTile(IconData icon, String title, VoidCallback onTap,
      {String? subtitle,
      required double fontSize,
      required EdgeInsets padding}) {
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
                      fontSize: fontSize - 3, color: Colors.grey[700])))
          : null,
      onTap: onTap,
    );
  }
}
