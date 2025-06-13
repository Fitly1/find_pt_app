import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart'; // For sign in/up prompt

class ManageSubscriptionPage extends StatefulWidget {
  final String trainerUid; // Passed in from your route definition

  const ManageSubscriptionPage({
    super.key,
    required this.trainerUid,
  });

  @override
  State<ManageSubscriptionPage> createState() => _ManageSubscriptionPageState();
}

class _ManageSubscriptionPageState extends State<ManageSubscriptionPage> {
  bool _isLoading = true; // Loading state for Firestore fetch
  bool _isActive = false; // Subscription status from Firestore

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  /// Loads the subscription status from Firestore (trainer_profiles/{trainerUid}).
  Future<void> _loadSubscriptionStatus() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(widget.trainerUid)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        // No profile doc means we treat subscription as inactive.
        setState(() {
          _isActive = false;
          _isLoading = false;
        });
        return;
      }

      final data = doc.data()!;
      final bool isActive = data['isActive'] ?? false;

      setState(() {
        _isActive = isActive;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // In case of error, treat subscription as inactive.
      setState(() {
        _isActive = false;
        _isLoading = false;
      });
    }
  }

  /// Opens the static Stripe Customer Portal URL.
  Future<void> _openStaticPortal() async {
    // Check the current user's auth state.
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('Current user: ${user?.uid}, isAnonymous: ${user?.isAnonymous}');

    // If user is null or anonymous, prompt sign in.
    if (user == null || user.isAnonymous) {
      _showSignUpPrompt();
      return;
    }

    // Use your static portal link from Stripe.
    const String staticPortalUrl =
        'https://billing.stripe.com/p/login/4gwaH7gOV9sT5G08ww';
    final uri = Uri.parse(staticPortalUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch the portal')),
      );
    }
  }

  /// Shows a dialog prompting the user to sign in or sign up.
  void _showSignUpPrompt() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sign In Required"),
        content: const Text(
            "Please sign in or sign up to manage your subscription."),
        actions: [
          TextButton(
            onPressed: () {
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (!mounted) return;
              Navigator.of(context).pop();
              // Navigate to your login/sign-up page.
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

  @override
  Widget build(BuildContext context) {
    final subscriptionText = _isActive ? 'Active' : 'Not Active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subscription'),
        backgroundColor: const Color(0xFFFFA726), // Orange brand color
      ),
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSubscriptionStatus,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  children: [
                    // Subscription Status Card
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              _isActive ? Icons.check_circle : Icons.cancel,
                              color: _isActive ? Colors.green : Colors.red,
                              size: 34,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Subscription Status',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    subscriptionText,
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      color:
                                          _isActive ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Manage Subscription Card (using static portal)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.settings,
                                    color: Colors.blue.shade600),
                                const SizedBox(width: 8),
                                const Text(
                                  'Manage Subscription',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, thickness: 1),
                            ListTile(
                              leading: const Icon(Icons.launch),
                              title: const Text('Open Stripe Customer Portal'),
                              subtitle: const Text(
                                  'View payment methods, invoices, and cancel subscription.'),
                              onTap: _openStaticPortal,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Support or Info Card (Optional)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blueGrey.shade600),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Need help or have questions about billing? Contact our support at account@fitly.com',
                                style: TextStyle(fontSize: 14.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
