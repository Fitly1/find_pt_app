// lib/profile_page.dart
// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'iap_compat_stub.dart';

import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bottom_navigation.dart';
import 'bottom_navigation_customers.dart';
import 'contact_us_page.dart';
import 'edit_profile_page.dart';
import 'faq_page.dart';
import 'feature_flags.dart';
import 'legal_documents_page.dart';
import 'login_page.dart';
import 'manage_subscription.dart';
import 'marketplace_page.dart';
import 'privacy_policy_page.dart';
import 'refund_policy_page.dart';
import 'secure_storage_service.dart';
import 'welcome_page.dart';
import 'terms_conditions_page.dart';
import 'trainer_dashboard_page.dart';

final Logger logger = Logger();
const Set<String> _kProductIds = <String>{'fitly.membership.1'};
const Color _brandColor = Color(0xFFFFA726);

/* ───────────────── Friendly auth error text ───────────────── */
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

/* ───────────────── Re-usable info dialog ───────────────── */
Future<void> showInfoDialog(
  BuildContext ctx, {
  required String title,
  required String message,
  bool error = false,
  String buttonText = 'OK',
}) {
  return showDialog<void>(
    context: ctx,
    barrierDismissible: true,
    builder: (_) => Dialog(
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
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.45)),
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
                    style: const TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/* ───────────────── Subscription disclosure sheet ───────────────── */
class _SubscriptionSheet extends StatelessWidget {
  final ProductDetails? product;
  final VoidCallback onStart;
  const _SubscriptionSheet({required this.product, required this.onStart});

  String _priceString() => product == null ? '—' : '${product!.price} / month';

  @override
  Widget build(BuildContext context) {
    const features = [
      'Get listed on Trainer Marketplace',
      'Unlimited invoice generator tool',
      'Trainer notes dashboard',
      'Contact customers directly',
      'Contact customer with listing',
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Fitly PRO Membership',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const Text('Length: Auto-renewing monthly subscription',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text('Price: ${_priceString()} after a 3-month free trial',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 18),

            // feature bullets
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 18, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  child: const Text('Privacy Policy'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage()),
                  ),
                ),
                TextButton(
                  child: const Text('Terms of Use'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TermsConditionsPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Start Free Trial',
                    style: TextStyle(fontSize: 16, color: Colors.white)),
                onPressed: () {
                  Navigator.pop(context);
                  onStart();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── Profile Page ───────────────── */
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userRole = 'trainer';
  final SecureStorageService secureStorage = SecureStorageService();

  // Promo-code controller
  final TextEditingController _promoCodeController = TextEditingController();

  // In-app-purchase
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  ProductDetails? _membershipProduct;
  InAppPurchaseStoreKitPlatformAddition? _skAddition;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _initIAP();
    _syncIosReceiptOnce();
    secureStorage
        .writeData('last_profile_view', DateTime.now().toIso8601String())
        .catchError((e) => logger.e("SecureStorage error: $e"));
  }

  /* ───────── iOS receipt sync (one-shot) ───────── */
  Future<void> _syncIosReceiptOnce() async {
    if (!Platform.isIOS) return;

    final dynamic addition = _skAddition ??
        InAppPurchase.instance
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    if (addition == null) return;

    String? receipt;
    try {
      receipt = await addition.appStoreReceipt as String?;
    } catch (_) {
      try {
        receipt = await addition.getReceiptData() as String?;
      } catch (_) {}
    }
    if (receipt == null || receipt.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('trainer_profiles')
        .doc(uid)
        .get();
    if (doc.exists &&
        (doc.data()?['latestIosReceiptData'] ?? '').toString().isNotEmpty) {
      return;
    }

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyIosReceipt');
      await callable.call({'receiptData': receipt});
      logger.i('Uploaded iOS receipt once at launch');
    } catch (e) {
      logger.w('syncIosReceiptOnce error: $e');
    }
  }

  /* ───────── Promo-code dialog (no overflow) ───────── */
  void _showPromoDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _brandColor,
                child: const Icon(Icons.local_offer_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 22),
              const Text('Enter Promo Code',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              TextField(
                controller: _promoCodeController,
                decoration: const InputDecoration(
                  hintText: 'Promo code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your card is used only for verification. Cancel any time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply',
                          style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(context);
                        _activateSubscription();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ───────── IAP bootstrap ───────── */
  Future<void> _initIAP() async {
    if (!Platform.isIOS) return;
    if (!await InAppPurchase.instance.isAvailable()) {
      logger.w('IAP not available');
      return;
    }
    final res = await InAppPurchase.instance.queryProductDetails(_kProductIds);

// In stub: `error` is a bool, and we also expose `notFoundIDs`.
    if (res.error || res.notFoundIDs.isNotEmpty) {
      logger.e('IAP query error');
      return;
    }

    if (res.productDetails.isEmpty) {
      logger.e('IAP: product not found');
      return;
    }
    _membershipProduct = res.productDetails.first;
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => logger.e('Purchase stream error: $e'),
    );
    await InAppPurchase.instance.restorePurchases();
    _skAddition = InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          if (mounted) {
            await showInfoDialog(
              context,
              title: 'Purchase Failed',
              message: p.error?.message ?? 'Purchase cancelled or failed.',
              error: true,
            );
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
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

  /* ───────── iOS helpers ───────── */
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
        if (!mounted) return;
        await showInfoDialog(
          context,
          title: 'Refund',
          message: 'Refund flow status: $status',
        );
        return;
      }
    } catch (_) {}
    const url = 'https://reportaproblem.apple.com/';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userRole = prefs.getString("userRole")?.toLowerCase() ?? 'trainer';
    });
  }

  /* ───────── Start subscription (no context-after-await) ───────── */
  Future<void> _activateSubscription() async {
    final messenger = ScaffoldMessenger.of(context);
    if (Platform.isIOS) {
      if (_membershipProduct == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Product not ready. Try again.'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      final param = PurchaseParam(
        productDetails: _membershipProduct!,
        applicationUserName: FirebaseAuth.instance.currentUser?.uid,
      );
      InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      return;
    }

    try {
      messenger.showSnackBar(const SnackBar(content: Text('Loading…')));
      final callable = FirebaseFunctions.instance
          .httpsCallable('createSubscriptionCheckoutSession');
      final result =
          await callable.call({'promoCode': _promoCodeController.text.trim()});
      final sessionUrl = result.data['sessionUrl'];
      if (sessionUrl == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Failed to get checkout URL.'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      await launchUrl(Uri.parse(sessionUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      logger.e('Stripe error: $e');
      if (!mounted) return;
      await showInfoDialog(
        context,
        title: 'Payment Error',
        message:
            'Could not start checkout. Check your connection and try again.',
        error: true,
      );
    }
  }

  void _openSubscriptionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SubscriptionSheet(
        product: _membershipProduct,
        onStart: _activateSubscription,
      ),
    );
  }

  /* ───────── Account deletion (captures nav BEFORE awaits) ───────── */
  Future<bool> _confirmDeletion() async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Colors.red,
                child: Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 22),
              const Text('Delete Account?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              const Text(
                'This action is permanent and will remove all your data.\nAre you sure you want to continue?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.white)),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
    return res ?? false;
  }

  Future<String?> _askForPassword() async {
    final TextEditingController pwController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _brandColor,
                child: const Icon(Icons.lock_outline_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 22),
              const Text('Confirm with Password',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              TextField(
                controller: pwController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Continue',
                          style: TextStyle(color: Colors.white)),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
    final value = (ok == true) ? pwController.text.trim() : null;
    pwController.dispose();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> _reauthGoogle() async {
    // Try silent, then interactive authenticate() (v7 API)
    var account =
        await gsi.GoogleSignIn.instance.attemptLightweightAuthentication();
    account ??= await gsi.GoogleSignIn.instance.authenticate();
    final googleAuth = account.authentication; // synchronous in v7
    final cred = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
    await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(cred);
  }

  Future<void> _reauthApple() async {
    final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email]);
    final cred = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        accessToken: appleCred.authorizationCode);
    await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(cred);
  }

  Future<void> _reauthEmail(String email) async {
    final pw = await _askForPassword();
    if (pw == null) throw FirebaseAuthException(code: 'cancelled');
    final cred = EmailAuthProvider.credential(email: email, password: pw);
    await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(cred);
  }

  Future<void> _handleDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nav = Navigator.of(context); // capture BEFORE awaits

    if (!await _confirmDeletion()) return;

    try {
      // re-authenticate
      final providers = user.providerData.map((e) => e.providerId).toList();
      if (providers.contains('google.com')) {
        await _reauthGoogle();
      } else if (providers.contains('apple.com')) {
        await _reauthApple();
      } else {
        await _reauthEmail(user.email ?? '');
      }

      // delete firestore docs then auth user
      final batch = FirebaseFirestore.instance.batch();
      batch
          .delete(FirebaseFirestore.instance.collection('users').doc(user.uid));
      batch.delete(FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid));
      await batch.commit();

      await user.delete();
      if (providers.contains('google.com')) {
        // v7 API: singleton + disconnect to revoke consent
        await gsi.GoogleSignIn.instance.disconnect();
      }

      // local cleanup
      await secureStorage.deleteData('userToken');
      await secureStorage.deleteData('last_profile_view');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        await showInfoDialog(context,
            title: 'Account Deleted',
            message: 'Your account has been deleted successfully.');
      }

      // use captured navigator (no context after awaits)
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'cancelled') return;
      if (mounted) {
        await showInfoDialog(context,
            title: 'Error', message: prettyAuthError(e), error: true);
      }
    } catch (e) {
      logger.e('Delete account error: $e');
      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Error',
          message: 'Something went wrong. Please try again.',
          error: true,
        );
      }
    }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _promoCodeController.dispose();
    super.dispose();
  }

  /* ───────── Bottom nav ───────── */
  Widget _buildBottomNavigation() {
    final isTrainer =
        ['trainer', 'personal trainer', 'personaltrainer'].contains(userRole);
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
              icon: const Icon(Icons.notifications_none, color: Colors.white),
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
    final ref = FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(user.uid)
        .collection("reviews");
    try {
      final snap = await ref.where("notified", isEqualTo: false).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {"notified": true});
      }
      await batch.commit();
    } catch (e) {
      logger.e("Mark reviews notified error: $e");
    }
    if (!mounted) return;
    await showInfoDialog(context,
        title: 'New Review',
        message: 'You have received a new review!',
        buttonText: 'OK');
  }

  void _showSignUpPrompt() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
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
                child: const Icon(Icons.login_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 22),
              const Text('Sign-In Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              const Text(
                'Please sign in or sign up to manage your subscription.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Sign In / Sign Up',
                          style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()));
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  /* ───────── UI ───────── */
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nav = Navigator.of(context); // used later in logout

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: _brandColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            final isTrainer = ['trainer', 'personal trainer', 'personaltrainer']
                .contains(userRole);
            nav.pushReplacement(
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
          // ───────── HEADER (overflow-proof) ─────────
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection("trainer_profiles")
                .doc(user?.uid)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snap.data!.data() as Map<String, dynamic>? ?? {};
              final img = (data['profileImageUrl'] ?? '').toString();
              bool isActive = data['isActive'] ?? false;
              if (!isTrainerPaymentsEnabled) isActive = true;

              String displayName = (data['displayName'] ?? '').toString();
              if (displayName.isEmpty) {
                displayName = user?.displayName ?? 'No Name';
              }

              return Column(
                children: [
                  // banner with avatar, name, chips
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: img.isNotEmpty
                            ? Image.network(img, fit: BoxFit.cover)
                            : Image.asset('assets/default_profile.png',
                                fit: BoxFit.cover),
                      ),
                      // gradient for legibility
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.fromRGBO(0, 0, 0, 0.00),
                                Color.fromRGBO(0, 0, 0, 0.45),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: -44,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(64),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.25),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundImage: img.isNotEmpty
                                    ? NetworkImage(img)
                                    : const AssetImage(
                                            'assets/default_profile.png')
                                        as ImageProvider,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      // membership chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFFC62828),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isActive
                                                  ? 'Membership: Active'
                                                  : 'Membership: Inactive',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // edit button
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(
                                              color: Colors.white),
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Edit'),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const EditProfilePage(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                ],
              );
            },
          ),

          // ───────── SUBSCRIPTION TILE ─────────
          if (isTrainerPaymentsEnabled)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("trainer_profiles")
                  .doc(user?.uid)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox();
                final d = snap.data!.data() as Map<String, dynamic>? ?? {};
                final active = d['isActive'] ?? false;
                final stripeId = (d['stripeId'] ?? '').toString();

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

                // not active → activation card + promo link (no overflow)
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
                        onTap: _openSubscriptionSheet,
                      ),
                      if (!Platform.isIOS)
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 72.0, right: 16.0, bottom: 12.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: _showPromoDialog,
                              child: const Text(
                                'Have a promo code?',
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF2196F3),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          if (isTrainerPaymentsEnabled) const SizedBox(height: 16),

          // ───────── Other tiles ─────────
          _simpleTile(
            icon: Icons.edit,
            label: 'Edit Profile',
            page: const EditProfilePage(),
          ),
          _simpleTile(
            icon: Icons.help_outline,
            label: 'FAQ / Help',
            page: const FAQPage(),
          ),
          _simpleTile(
            icon: Icons.contact_mail,
            label: 'Contact Us / Support',
            page: const ContactUsPage(),
          ),
          _simpleTile(
            icon: Icons.receipt_long,
            label: 'Refund Policy',
            page: const RefundPolicyPage(),
          ),
          _termsTile(),
          _simpleTile(
            icon: Icons.privacy_tip,
            label: 'Privacy Policy',
            page: const PrivacyPolicyPage(),
          ),
          _simpleTile(
            icon: Icons.library_books,
            label: 'Legal Documents',
            page: const LegalDocumentsPage(),
          ),
          _deleteTile(),
          const SizedBox(height: 16),

          // ───────── Log out (captures nav BEFORE awaits) ─────────
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Log Out',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              // capture navigator first
              final navigator = Navigator.of(context);

              await FirebaseAuth.instance.signOut();
              await prefs.remove('userRole');
              await secureStorage.deleteData('userToken');
              await secureStorage.deleteData('last_profile_view');

              // navigate using captured navigator to avoid context-after-await
              SchedulerBinding.instance.addPostFrameCallback((_) {
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  /* ───────── helper tile builders (no context-after-await) ───────── */
  Widget _simpleTile({
    required IconData icon,
    required String label,
    required Widget page,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: Icon(icon, color: Colors.black),
            title: Text(label),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black),
            onTap: () {
              final navigator = Navigator.of(context);
              SchedulerBinding.instance.addPostFrameCallback((_) {
                navigator.push(MaterialPageRoute(builder: (_) => page));
              });
            },
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
            onTap: _handleDeleteAccount,
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
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => const TermsConditionsPage(),
                        ),
                      );
                    });
                  },
                )
              ],
            ),
          ),
        ),
      );
}
