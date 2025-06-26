import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import 'secure_storage_service.dart';
import 'edit_profile_page.dart';
import 'marketplace_page.dart';
import 'faq_page.dart';
import 'contact_us_page.dart';
import 'refund_policy_page.dart';
import 'bottom_navigation.dart';
import 'bottom_navigation_customers.dart';
import 'welcome_page.dart';
import 'terms_conditions_page.dart';
import 'privacy_policy_page.dart';
import 'legal_documents_page.dart';
import 'manage_subscription.dart';
import 'login_page.dart';
import 'trainer_dashboard_page.dart';

//─────────────────────────────────────────────────────────────────────────────
final Logger logger = Logger();
const Set<String> _kProductIds = <String>{'fitly.membership.1'}; // Apple SKU
//─────────────────────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  //───────────────── State ─────────────────
  String userRole = 'trainer';
  final SecureStorageService secureStorage = SecureStorageService();

  // Promo-code controller
  final TextEditingController _promoCodeController = TextEditingController();

  // IAP
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  ProductDetails? _membershipProduct;
  InAppPurchaseStoreKitPlatformAddition? _skAddition;

  //───────────────── init ──────────────────
  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _initIAP();
    // store last profile-view timestamp
    secureStorage
        .writeData('last_profile_view', DateTime.now().toIso8601String())
        .catchError((e) => logger.e("SecureStorage error: $e"));
  }

  //───────────────── Promo dialog ──────────
  void _showPromoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Promo Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promoCodeController,
              decoration: const InputDecoration(
                hintText: 'Promo code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Credit card used only for verification Cancel anytime',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _activateSubscription(); // uses controller text
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  //───────────────── IAP bootstrap ─────────
  Future<void> _initIAP() async {
    if (!Platform.isIOS) return;
    if (!await InAppPurchase.instance.isAvailable()) {
      logger.w('IAP not available');
      return;
    }
    final res = await InAppPurchase.instance.queryProductDetails(_kProductIds);
    if (res.error != null) {
      logger.e('IAP query error: ${res.error}');
      return;
    }
    if (res.productDetails.isEmpty) {
      logger.e('IAP: product not found');
      return;
    }
    _membershipProduct = res.productDetails.first;
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (e) => logger.e('Purchase stream error: $e'));
    await InAppPurchase.instance.restorePurchases();
    _skAddition = InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
  }

  //──────────────── handle transactions ────
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(p.error?.message ?? 'Purchase error')));
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // upload iOS receipt
          if (Platform.isIOS && _skAddition != null) {
            String? receipt;
            try {
              final dynamic addition = _skAddition;
              try {
                receipt = await addition.appStoreReceipt as String?;
              } catch (_) {
                receipt = await addition.getReceiptData() as String?;
              }
            } catch (e) {
              logger.w('Could not get receipt: $e');
            }
            if (receipt != null && receipt.isNotEmpty) {
              final callable =
                  FirebaseFunctions.instance.httpsCallable('verifyIosReceipt');
              await callable.call({'receiptData': receipt});
            }
          }
          if (p.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(p);
          }
          break;
        default:
          break;
      }
    }
  }

  //──────────────── iOS helpers ────────────
  Future<void> _openIOSManage() async {
    if (!Platform.isIOS) return;
    try {
      final dynamic addition = _skAddition;
      if (addition != null) {
        await addition.showManageSubscriptionsSheet();
        return;
      }
    } catch (_) {}
    const url = 'https://apps.apple.com/account/subscriptions';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _askRefund() async {
    if (!Platform.isIOS || _membershipProduct == null) return;
    try {
      final dynamic addition = _skAddition;
      if (addition != null) {
        final status =
            await addition.beginRefundRequest(_membershipProduct!.id);
        logger.i('Refund request status: $status');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Refund flow status: $status')));
        return;
      }
    } catch (_) {}
    const url = 'https://reportaproblem.apple.com/';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  //──────────────── load role ──────────────
  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userRole = prefs.getString("userRole")?.toLowerCase() ?? 'trainer';
    });
  }

  //──────────────── start subscription ────
  Future<void> _activateSubscription() async {
    // iOS → Apple IAP
    if (Platform.isIOS) {
      if (_membershipProduct == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product not ready. Try again.')));
        }
        return;
      }
      final param = PurchaseParam(
        productDetails: _membershipProduct!,
        applicationUserName: FirebaseAuth.instance.currentUser!.uid,
      );
      InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      return;
    }

    // Android → Stripe
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Loading…")));
      final callable = FirebaseFunctions.instance
          .httpsCallable('createSubscriptionCheckoutSession');
      final result =
          await callable.call({'promoCode': _promoCodeController.text.trim()});
      if (!mounted) return;
      final sessionUrl = result.data['sessionUrl'];
      if (sessionUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to get checkout URL.")));
        return;
      }
      await launchUrl(Uri.parse(sessionUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      logger.e('Stripe error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  //──────────────── account deletion helpers ────────────────────
  void _promptReauthAndDelete(String email) {
    final TextEditingController pwController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Account Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please re-enter your password to continue.'),
            const SizedBox(height: 10),
            TextField(
              controller: pwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reauthAndDelete(email, pwController.text);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _reauthAndDelete(String email, String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'no-user');

      final credential =
          EmailAuthProvider.credential(email: email, password: password);

      await user.reauthenticateWithCredential(credential);
      await user.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account deleted successfully.")));

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ Failed: ${e.message}")));
    }
  }

  //──────────────── dispose ───────────────
  @override
  void dispose() {
    _purchaseSub?.cancel();
    _promoCodeController.dispose();
    super.dispose();
  }

  //──────────────── helpers ───────────────
  Widget _buildBottomNavigation() {
    bool isTrainer = (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer');
    return isTrainer
        ? const BottomNavigation(currentIndex: 4)
        : const BottomNavigationCustomers(currentIndex: 4);
  }

  Widget _buildReviewBellIcon(String trainerUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(trainerUid)
          .collection("reviews")
          .where("notified", isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final hasNew = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none,
                  color: Color.fromRGBO(255, 255, 255, 1)),
              onPressed: _handleReviewBellTap,
            ),
            if (hasNew)
              const Positioned(
                right: 8,
                top: 8,
                child: Icon(Icons.brightness_1, color: Colors.red, size: 10),
              ),
          ],
        );
      },
    );
  }

  Future<void> _handleReviewBellTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final reviewsRef = FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(user.uid)
        .collection("reviews");
    try {
      final snap = await reviewsRef.where("notified", isEqualTo: false).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {"notified": true});
      }
      await batch.commit();
    } catch (e) {
      logger.e("Mark reviews notified error: $e");
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Review Received"),
        content: const Text("You have received a new review!"),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"))
        ],
      ),
    );
  }

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
              child: const Text("Cancel")),
          TextButton(
            child: const Text("Sign In / Sign Up"),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginPage()));
            },
          )
        ],
      ),
    );
  }

  //──────────────── UI ────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFFA726),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFFFFFF)),
          onPressed: () {
            final bool isTrainer = (userRole == 'trainer' ||
                userRole == 'personal trainer' ||
                userRole == 'personaltrainer');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => isTrainer
                    ? const TrainerDashboardPage()
                    : const MarketplacePage(),
              ),
            );
          },
        ),
        actions: [
          if (userRole == 'trainer' && user != null)
            _buildReviewBellIcon(user.uid)
        ],
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildBottomNavigation(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          //──────────────── PROFILE CARD ────────────────────────
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("trainer_profiles")
                    .doc(user?.uid)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                  final img = data['profileImageUrl'] ?? '';
                  final isActive = data['isActive'] ?? false;
                  final status = isActive ? "Active" : "Inactive";
                  String displayName = data['displayName'] ?? '';
                  if (displayName.isEmpty) {
                    displayName = user?.displayName ?? 'No Name';
                  }
                  return Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: img.isNotEmpty
                                ? NetworkImage(img)
                                : const AssetImage('assets/default_profile.png')
                                    as ImageProvider,
                          ),
                          IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Color.fromRGBO(255, 255, 255, 1)),
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const EditProfilePage())))
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Membership Status: $status",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isActive ? Colors.green : Colors.red)),
                      const SizedBox(height: 8),
                      Text(displayName,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          //──────────────── SUBSCRIPTION TILE ────────────────────
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection("trainer_profiles")
                .doc(user?.uid)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox();
              final d = snap.data!.data() as Map<String, dynamic>? ?? {};
              final active = d['isActive'] ?? false;
              final stripeId = d['stripeId'] ?? '';

              //──────── ACTIVE ─────────
              if (active) {
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const Icon(Icons.manage_accounts),
                    title: const Text('Manage Subscription'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      if (Platform.isIOS) {
                        await _openIOSManage();
                      } else {
                        if (stripeId.isNotEmpty) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ManageSubscriptionPage(
                                      trainerUid: user!.uid)));
                        } else if (d['iosOriginalTxId'] != null) {
                          const url =
                              'https://apps.apple.com/account/subscriptions';
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        } else {
                          _showSignUpPrompt();
                        }
                      }
                    },
                    onLongPress: () async {
                      if (Platform.isIOS) await _askRefund();
                    },
                  ),
                );
              }

              //──────── INACTIVE ───────
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                color: const Color(0xFFF6EFFC),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.payment),
                      title: Text('Activate Membership',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900)),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _activateSubscription,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 72.0, right: 16.0, bottom: 12.0),
                      child: GestureDetector(
                        onTap: _showPromoDialog,
                        child: const Text(
                          'Have a promo code?',
                          style: TextStyle(
                            color: Color.fromARGB(255, 33, 150, 243),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          //──────────────── OTHER TILES ──────────────────────────
          _simpleTile(
              icon: Icons.edit,
              label: 'Edit Profile',
              page: const EditProfilePage()),
          _simpleTile(
              icon: Icons.help_outline,
              label: 'FAQ / Help',
              page: const FAQPage()),
          _simpleTile(
              icon: Icons.contact_mail,
              label: 'Contact Us / Support',
              page: const ContactUsPage()),
          _simpleTile(
              icon: Icons.receipt_long,
              label: 'Refund Policy',
              page: const RefundPolicyPage()),
          _termsTile(),
          _simpleTile(
              icon: Icons.privacy_tip,
              label: 'Privacy Policy',
              page: const PrivacyPolicyPage()),
          _simpleTile(
              icon: Icons.library_books,
              label: 'Legal Documents',
              page: const LegalDocumentsPage()),
          _deleteTile(),
          const SizedBox(height: 16),
          //──────────────── LOG-OUT BUTTON ──────────────────────
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Log Out',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('userRole', 'guest');
              await secureStorage.deleteData('userToken');
              await secureStorage.deleteData('last_profile_view');
              if (!mounted) return;
              SchedulerBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  //──────────────── helper tile builders ────────────────────────
  Widget _simpleTile(
          {required IconData icon,
          required String label,
          required Widget page}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: Icon(icon, color: Colors.black),
            title: Text(label),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => page)),
          ),
        ),
      );

  Widget _deleteTile() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account',
                style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
            onTap: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && user.email != null) {
                _promptReauthAndDelete(user.email!);
              }
            },
          ),
        ),
      );

  Widget _termsTile() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Terms & Conditions',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text(
                    'By using this platform, you agree to our Terms & Conditions.'),
                TextButton(
                  child: const Text('View Terms & Conditions',
                      style: TextStyle(decoration: TextDecoration.underline)),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TermsConditionsPage())),
                )
              ],
            ),
          ),
        ),
      );
}
