import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page_customers.dart';
import 'faq_page.dart';
import 'contact_us_page.dart';
// Removed refund_policy_page.dart import as it's not used.
import 'bottom_navigation_customers.dart';
import 'bottom_navigation.dart';
import 'welcome_page.dart';
import 'marketplace_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'terms_conditions_page.dart';
import 'privacy_policy_page.dart'; // Import Privacy Policy page
import 'legal_documents_page.dart'; // <-- Import your actual LegalDocumentsPage here

// Import your secure storage service
import 'secure_storage_service.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  String _displayName = "Customer Name";
  String _email = "customer@example.com";
  String? _profileImageUrl;
  String userRole = 'customer'; // default role

  // Create an instance of SecureStorageService (singleton)
  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserRole();

    // --- Security Integration: Save and log the customer profile view timestamp ---
    secureStorage
        .writeData(
            'last_customer_profile_view', DateTime.now().toIso8601String())
        .then((_) async {
      String? timestamp =
          await secureStorage.readData('last_customer_profile_view');
      debugPrint(
          "CustomerProfilePage: Last profile view timestamp: $timestamp");
    }).catchError((error) {
      debugPrint("Error saving customer profile view timestamp: $error");
    });
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          final String firstName = data?['firstName'] ?? '';
          final String lastName = data?['lastName'] ?? '';
          final String combinedName = '$firstName $lastName'.trim();

          setState(() {
            _displayName =
                combinedName.isNotEmpty ? combinedName : "Customer Name";
            _email = data?['email'] ?? "customer@example.com";
            _profileImageUrl = data?['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    }
  }

  Future<void> _loadUserRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString("userRole")?.toLowerCase() ?? 'customer';
    });
    debugPrint("CustomerProfilePage: Loaded user role: $userRole");
  }

  /// Updated logout method to clear secure storage data.
  void _logout() async {
    // Sign out from Firebase.
    await FirebaseAuth.instance.signOut();

    // Clear sensitive data stored locally.
    await secureStorage.deleteData('userToken');
    await secureStorage.deleteData('last_customer_profile_view');
    // Add any additional keys you want to clear here.

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
    );
  }

  /// Returns the appropriate bottom navigation based on the user role.
  Widget _buildBottomNavigation() {
    bool isCustomer = (userRole == 'customer');
    return isCustomer
        ? const BottomNavigationCustomers(currentIndex: 4)
        : const BottomNavigation(currentIndex: 4);
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider avatarImage =
        (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
            ? NetworkImage(_profileImageUrl!)
            : const AssetImage('assets/default_profile.png') as ImageProvider;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // For customers, pressing back takes them to the MarketplacePage.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MarketplacePage()),
            );
          },
        ),
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFFA726), // Brand orange
        actions: [
          // Show the bell icon only for trainers.
          if (userRole == 'trainer' &&
              FirebaseAuth.instance.currentUser != null)
            _buildReviewBellIcon(FirebaseAuth.instance.currentUser!.uid),
        ],
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Header Section
          Container(
            padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
            color: const Color(0xFFFFA726).withAlpha((0.25 * 255).round()),
            child: Row(
              children: [
                const SizedBox(width: 16), // small left margin
                CircleAvatar(
                  radius: 40,
                  backgroundImage: avatarImage,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Edit Profile Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfilePageCustomers(),
                  ),
                ).then((_) {
                  _loadUserData();
                });
              },
              icon: const Icon(Icons.edit),
              label: const Text("Edit Profile"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // FAQ / Help
          ListTile(
            leading: const Icon(Icons.help, color: Colors.black),
            title: const Text("FAQ / Help"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FAQPage()),
              );
            },
          ),
          // Contact Us / Support
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.black),
            title: const Text("Contact Us / Support"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactUsPage()),
              );
            },
          ),
          // Terms & Conditions
          ListTile(
            leading: const Icon(Icons.description, color: Colors.black),
            title: const Text("Terms & Conditions"),
            subtitle: const Text("View Terms & Conditions"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsConditionsPage(),
                ),
              );
            },
          ),
          // Privacy Policy
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.black),
            title: const Text("Privacy Policy"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyPage(),
                ),
              );
            },
          ),
          // Legal Documents
          ListTile(
            leading: const Icon(Icons.library_books, color: Colors.black),
            title: const Text("Legal Documents"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LegalDocumentsPage(),
                ),
              );
            },
          ),
          // Log Out with Secure Storage Clearing
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.black),
            title: const Text("Log Out"),
            onTap: _logout,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  /// Returns a bell icon with a red dot if there are new (unnotified) reviews.
  Widget _buildReviewBellIcon(String trainerUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(trainerUid)
          .collection("reviews")
          .where("notified", isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final newReviewsCount =
            snapshot.hasData ? snapshot.data!.docs.length : 0;
        final hasNewReviews = newReviewsCount > 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.white),
              onPressed: _handleReviewBellTap,
            ),
            if (hasNewReviews)
              const Positioned(
                right: 8,
                top: 8,
                child: Icon(
                  Icons.brightness_1,
                  color: Colors.red,
                  size: 10,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Handles the tap on the review bell by marking reviews as notified and showing a dialog.
  Future<void> _handleReviewBellTap() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reviewsRef = FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(user.uid)
        .collection("reviews");

    try {
      final snapshot =
          await reviewsRef.where("notified", isEqualTo: false).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {"notified": true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking reviews as notified: $e");
    }
    if (!mounted) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("New Review Received"),
          content: const Text("You have received a new review!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
    });
  }
}
