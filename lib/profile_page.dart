import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart'; // Import logger

// Import your secure storage service
import 'secure_storage_service.dart';

import 'edit_profile_page.dart';
import 'marketplace_page.dart';
import 'faq_page.dart';
import 'contact_us_page.dart';
import 'refund_policy_page.dart';
import 'bottom_navigation.dart'; // Trainer bottom nav
import 'bottom_navigation_customers.dart'; // Customer bottom nav
import 'welcome_page.dart'; // For Log Out redirection
import 'terms_conditions_page.dart'; // Terms & Conditions page
import 'privacy_policy_page.dart'; // Privacy Policy page
import 'legal_documents_page.dart';
import 'manage_subscription.dart'; // Manage Subscription Page
import 'login_page.dart'; // For sign in/up prompt

// Initialize a logger instance.
final Logger logger = Logger();

/// Widget for starting a subscription
class ActivateSubscriptionButton extends StatefulWidget {
  const ActivateSubscriptionButton({super.key});

  @override
  State<ActivateSubscriptionButton> createState() =>
      _ActivateSubscriptionButtonState();
}

class _ActivateSubscriptionButtonState
    extends State<ActivateSubscriptionButton> {
  Future<void> _startSubscription() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Loading...")),
      );
      logger.i("ActivateSubscriptionButton pressed");

      final callable = FirebaseFunctions.instance
          .httpsCallable('createSubscriptionCheckoutSession');
      final result = await callable.call();
      if (!mounted) return;
      logger.i("Cloud Function returned: ${result.data}");

      final sessionUrl = result.data['sessionUrl'];
      if (sessionUrl == null) {
        logger.e("No sessionUrl returned from Cloud Function");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to get checkout URL.")),
        );
        return;
      }

      if (await canLaunchUrl(Uri.parse(sessionUrl))) {
        await launchUrl(Uri.parse(sessionUrl),
            mode: LaunchMode.externalApplication);
        logger.i("Launched Stripe Checkout URL");
      } else {
        throw 'Could not launch $sessionUrl';
      }
    } catch (e) {
      logger.e('Error starting subscription: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error Loading: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _startSubscription,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        elevation: 2,
      ),
      child:
          const Text('Pay to Activate', style: TextStyle(color: Colors.white)),
    );
  }
}

/// Widget for managing an existing subscription via Stripe Billing Portal
class ManageSubscriptionButton extends StatefulWidget {
  final String customerId;
  const ManageSubscriptionButton({super.key, required this.customerId});

  @override
  State<ManageSubscriptionButton> createState() =>
      _ManageSubscriptionButtonState();
}

class _ManageSubscriptionButtonState extends State<ManageSubscriptionButton> {
  Future<void> _openBillingPortal() async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('createBillingPortalSession');
      final result = await callable.call({'customerId': widget.customerId});
      if (!mounted) return;
      final portalUrl = result.data['url'];
      if (await canLaunchUrl(Uri.parse(portalUrl))) {
        await launchUrl(Uri.parse(portalUrl),
            mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $portalUrl';
      }
    } catch (e) {
      logger.e('Error opening billing portal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _openBillingPortal,
      child: const Text('Manage Subscription'),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userRole = 'trainer'; // Default role for trainer

  // Create an instance of SecureStorageService (singleton)
  final SecureStorageService secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadUserRole();

    // --- Security Integration: Save and log the profile view timestamp ---
    secureStorage
        .writeData(
      'last_profile_view',
      DateTime.now().toIso8601String(),
    )
        .then((_) {
      return secureStorage.readData('last_profile_view');
    }).then((timestamp) {
      logger.i("Last profile view timestamp stored: $timestamp");
    }).catchError((error) {
      logger.e("Error storing last profile view timestamp: $error");
    });
  }

  Future<void> _loadUserRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userRole = prefs.getString("userRole")?.toLowerCase() ?? 'trainer';
    });
    debugPrint("ProfilePage: Loaded user role: $userRole");
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
      if (!mounted) return;
    } catch (e) {
      logger.e("Error marking reviews as notified: $e");
    }

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

  /// Returns the appropriate bottom navigation based on the user's role.
  Widget _buildBottomNavigation() {
    bool isTrainer = (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer');
    return isTrainer
        ? const BottomNavigation(currentIndex: 4)
        : const BottomNavigationCustomers(currentIndex: 4);
  }

  /// Shows a confirmation dialog for account deletion.
  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Account Deletion"),
        content: const Text(
            "Are you sure you want to delete your account? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAccount();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Deletes user data from Firestore and then deletes the Firebase Auth account.
  Future<void> _deleteAccount() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(user.uid)
          .delete();
      await user.delete();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );
    } catch (e) {
      logger.e("Error deleting account: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting account: $e")),
      );
    }
  }

  /// Shows a dialog prompting the user to sign in or sign up.
  void _showSignUpPrompt() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sign In Required"),
        content: const Text(
            "Please sign in or sign up to manage your subscription."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text("Sign In / Sign Up"),
          ),
        ],
      ),
    );
  }

  /// Function to start the subscription process.
  Future<void> _activateSubscription() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Loading...")),
      );
      logger.i("Pay to Activate tapped");

      final callable = FirebaseFunctions.instance
          .httpsCallable('createSubscriptionCheckoutSession');
      final result = await callable.call();
      if (!mounted) return;
      logger.i("Cloud Function returned: ${result.data}");

      final sessionUrl = result.data['sessionUrl'];
      if (sessionUrl == null) {
        logger.e("No sessionUrl returned from Cloud Function");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to get checkout URL.")),
        );
        return;
      }

      if (await canLaunchUrl(Uri.parse(sessionUrl))) {
        await launchUrl(Uri.parse(sessionUrl),
            mode: LaunchMode.externalApplication);
        logger.i("Launched Stripe Checkout URL");
      } else {
        throw 'Could not launch $sessionUrl';
      }
    } catch (e) {
      logger.e('Error starting subscription: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error Loading: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFFA726),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MarketplacePage()),
            );
          },
        ),
        actions: [
          if (userRole == 'trainer' && user != null)
            _buildReviewBellIcon(user.uid),
        ],
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Card (membership status above name)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 4.0,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("trainer_profiles")
                    .doc(user?.uid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final data =
                      snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final String imageUrl = data["profileImageUrl"] ?? '';
                  final bool isActive = data['isActive'] ?? false;
                  String membershipStatus = isActive ? "Active" : "Inactive";
                  String displayName = data["displayName"] ?? "";
                  if (displayName.isEmpty) {
                    displayName = user?.displayName ?? "No Name";
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile picture
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: imageUrl.isNotEmpty
                                ? NetworkImage(imageUrl)
                                : const AssetImage('assets/default_profile.png')
                                    as ImageProvider,
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfilePage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      // Membership status
                      Text(
                        "Membership Status: $membershipStatus",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isActive ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      // Display name
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          // SUBSCRIPTION TILE: (Placed FIRST after Profile Card)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection("trainer_profiles")
                .doc(user?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                logger.i("Subscription StreamBuilder: No data yet");
                return const SizedBox();
              }
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final bool isActive = data['isActive'] ?? false;
              final String stripeId = data['stripeId'] ?? '';
              logger.i(
                  "Subscription data: isActive = $isActive, stripeId = $stripeId");

              if (isActive && stripeId.isNotEmpty) {
                // Manage Subscription tile (neutral styling)
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  color: Colors.white,
                  elevation: 2.0,
                  child: ListTile(
                    leading: const Icon(Icons.payment, color: Colors.black),
                    title: const Text('Manage Subscription'),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Colors.black),
                    onTap: () {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null || currentUser.isAnonymous) {
                        _showSignUpPrompt();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ManageSubscriptionPage(trainerUid: user!.uid),
                          ),
                        );
                      }
                    },
                  ),
                );
              } else {
                // Pay to Activate tile with accent styling to draw attention.
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  color: Colors.orange.shade200, // Lighter accent background
                  elevation: 2.0,
                  child: ListTile(
                    leading: const Icon(Icons.payment, color: Colors.black),
                    title: Text(
                      'Pay to Activate',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color:
                            Colors.orange.shade900, // Darker text for contrast
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Colors.black),
                    onTap: _activateSubscription,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16.0),
          // EDIT PROFILE TILE (Now appears after subscription tile)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            color: Colors.white,
            elevation: 2.0,
            child: ListTile(
              leading: const Icon(Icons.edit, color: Colors.black),
              title: const Text('Edit Profile'),
              trailing:
                  const Icon(Icons.arrow_forward_ios, color: Colors.black),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16.0),
          // FAQ / Help
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            color: Colors.white,
            elevation: 2.0,
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.black),
              title: const Text('FAQ / Help'),
              trailing:
                  const Icon(Icons.arrow_forward_ios, color: Colors.black),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FAQPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16.0),
          // Contact Us / Support
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            color: Colors.white,
            elevation: 2.0,
            child: ListTile(
              leading: const Icon(Icons.contact_mail, color: Colors.black),
              title: const Text('Contact Us / Support'),
              trailing:
                  const Icon(Icons.arrow_forward_ios, color: Colors.black),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactUsPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16.0),
          // Refund Policy
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            color: Colors.white,
            elevation: 2.0,
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.black),
              title: const Text('Refund Policy'),
              trailing:
                  const Icon(Icons.arrow_forward_ios, color: Colors.black),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RefundPolicyPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16.0),
          // Terms & Conditions
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            color: Colors.white,
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Terms & Conditions',
                    style:
                        TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  const Text(
                    'By using this platform, you agree to our Terms & Conditions. '
                    'Please review them carefully to understand your rights and responsibilities.',
                    style: TextStyle(fontSize: 14.0),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TermsConditionsPage()),
                      );
                    },
                    child: const Text(
                      'View Terms & Conditions',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          // Privacy Policy
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            color: Colors.white,
            elevation: 2.0,
            child: ListTile(
              title: const Text('Privacy Policy'),
              trailing:
                  const Icon(Icons.arrow_forward_ios, color: Colors.black),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16.0),
          // Legal Documents
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            color: Colors.white,
            elevation: 2.0,
            child: ListTile(
              leading: const Icon(Icons.library_books, color: Colors.black),
              title: const Text('Legal Documents'),
              trailing:
                  const Icon(Icons.arrow_forward_ios, color: Colors.black),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalDocumentsPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16.0),
          // Delete Account Feature
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            color: Colors.white,
            elevation: 2.0,
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account',
                  style: TextStyle(color: Colors.red)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
              onTap: _confirmDeleteAccount,
            ),
          ),
          const SizedBox(height: 16.0),
          // Log Out Button with Secure Storage Clearing
          ElevatedButton(
            onPressed: () async {
              final BuildContext currentContext = context;
              // Sign out from Firebase Authentication.
              await FirebaseAuth.instance.signOut();

              // Clear sensitive data stored locally.
              await secureStorage.deleteData('userToken');
              await secureStorage.deleteData('last_profile_view');
              // Add any additional keys you want to clear here.

              if (!mounted) return;
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.pushReplacement(
                  currentContext,
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                );
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}
