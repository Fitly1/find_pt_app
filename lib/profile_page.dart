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
import 'concierge_inbox_page.dart';
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
import 'widgets/trainer_fitness_identity_card.dart';

final Logger logger = Logger();
const Set<String> _kProductIds = <String>{'fitly.membership.1'};

const Color _fitlyBg = Color(0xFF07080A);
const Color _fitlyBgAlt = Color(0xFF0B0D10);
const Color _fitlyCard = Color(0xFF111318);
const Color _fitlyCardAlt = Color(0xFF171B22);
const Color _fitlyRaised = Color(0xFF20242C);
const Color _fitlyBorder = Color(0xFF303540);
const Color _fitlyBorderAlt = Color(0xFF343A46);
const Color _fitlyGold = Color(0xFFE7B95C);
const Color _fitlyMuted = Color(0xFFA6ADB8);
const Color _fitlyText = Color(0xFFF5F6F8);
const Color _fitlySubtleText = Color(0xFFD6DAE1);
const Color _fitlyDanger = Color(0xFFE05A5A);
const Color _fitlySuccess = Color(0xFF4CD17D);

const Color _brandColor = _fitlyGold;

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
      backgroundColor: _fitlyCardAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: _fitlyBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: error ? _fitlyDanger : _brandColor,
              child: Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                color: error ? Colors.white : _fitlyBg,
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
                color: _fitlyText,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: _fitlyMuted,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: error ? _fitlyDanger : _brandColor,
                  foregroundColor: error ? Colors.white : _fitlyBg,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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

  const _SubscriptionSheet({
    required this.product,
    required this.onStart,
  });

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
      child: Container(
        decoration: const BoxDecoration(
          color: _fitlyCardAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: _fitlyBorderAlt),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: _fitlyBorderAlt,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Text(
                'Fitly PRO Membership',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _fitlyText,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Length: Auto-renewing monthly subscription',
                style: TextStyle(
                  fontSize: 15,
                  color: _fitlyMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Price: ${_priceString()} after a 3-month free trial',
                style: const TextStyle(
                  fontSize: 15,
                  color: _fitlyMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _fitlyGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: _fitlyGold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: _fitlyGold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            color: _fitlySubtleText,
                            fontSize: 14.5,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  TextButton(
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(color: _fitlyGold),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    ),
                  ),
                  TextButton(
                    child: const Text(
                      'Terms of Use',
                      style: TextStyle(color: _fitlyGold),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsConditionsPage(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _fitlyGold,
                    foregroundColor: _fitlyBg,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Start Free Trial',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onStart();
                  },
                ),
              ),
            ],
          ),
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
  bool _isAdmin = false;
  final SecureStorageService secureStorage = SecureStorageService();

  final TextEditingController _promoCodeController = TextEditingController();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  ProductDetails? _membershipProduct;
  InAppPurchaseStoreKitPlatformAddition? _skAddition;

  bool get _isTrainerRole {
    return ['trainer', 'personal trainer', 'personaltrainer']
        .contains(userRole.toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadAdminAccess();
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
        backgroundColor: _fitlyCardAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _fitlyBorder),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _brandColor,
                child: const Icon(
                  Icons.local_offer_rounded,
                  color: _fitlyBg,
                  size: 38,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Enter Promo Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _fitlyText,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _promoCodeController,
                style: const TextStyle(color: _fitlyText),
                cursorColor: _fitlyGold,
                decoration: InputDecoration(
                  hintText: 'Promo code',
                  hintStyle: const TextStyle(color: _fitlyMuted),
                  filled: true,
                  fillColor: _fitlyRaised,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _fitlyBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _fitlyGold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your card is used only for verification. Cancel any time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _fitlyMuted),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _fitlySubtleText,
                        side: const BorderSide(color: _fitlyBorderAlt),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fitlyGold,
                        foregroundColor: _fitlyBg,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
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

  Future<void> _loadAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;

    debugPrint('FITLY ADMIN CHECK - current UID: ${user?.uid}');
    debugPrint('FITLY ADMIN CHECK - current email: ${user?.email}');

    if (user == null) {
      if (mounted) setState(() => _isAdmin = false);
      return;
    }

    try {
      bool isAdminFromAdminsCollection = false;
      bool isAdminFromAppConfig = false;

      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      final adminData = adminDoc.data() ?? <String, dynamic>{};

      isAdminFromAdminsCollection =
          adminDoc.exists && adminData['active'] == true;

      final configDoc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('fitly')
          .get();

      final configData = configDoc.data() ?? <String, dynamic>{};

      final conciergeAdminUid =
          (configData['conciergeAdminUid'] ?? '').toString().trim();

      isAdminFromAppConfig = conciergeAdminUid == user.uid;

      debugPrint(
        'FITLY ADMIN CHECK - admins doc exists: ${adminDoc.exists}, active: ${adminData['active']}',
      );
      debugPrint(
        'FITLY ADMIN CHECK - conciergeAdminUid: $conciergeAdminUid',
      );
      debugPrint(
        'FITLY ADMIN CHECK - final isAdmin: ${isAdminFromAdminsCollection || isAdminFromAppConfig}',
      );

      if (!mounted) return;

      setState(() {
        _isAdmin = isAdminFromAdminsCollection || isAdminFromAppConfig;
      });
    } catch (e) {
      debugPrint('FITLY ADMIN CHECK FAILED: $e');

      if (!mounted) return;

      setState(() => _isAdmin = false);
    }
  }

  /* ───────── Start subscription (no context-after-await) ───────── */
  Future<void> _activateSubscription() async {
    final messenger = ScaffoldMessenger.of(context);

    if (Platform.isIOS) {
      if (_membershipProduct == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Product not ready. Try again.'),
            backgroundColor: _fitlyDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Loading…'),
          backgroundColor: _fitlyRaised,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final callable = FirebaseFunctions.instance
          .httpsCallable('createSubscriptionCheckoutSession');

      final result =
          await callable.call({'promoCode': _promoCodeController.text.trim()});

      final sessionUrl = result.data['sessionUrl'];

      if (sessionUrl == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to get checkout URL.'),
            backgroundColor: _fitlyDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await launchUrl(
        Uri.parse(sessionUrl),
        mode: LaunchMode.externalApplication,
      );
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
      backgroundColor: Colors.transparent,
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
        backgroundColor: _fitlyCardAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _fitlyBorder),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: _fitlyDanger,
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Delete Account?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _fitlyText,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'This action is permanent and will remove all your data.\nAre you sure you want to continue?',
                textAlign: TextAlign.center,
                style: TextStyle(color: _fitlyMuted, height: 1.4),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _fitlySubtleText,
                        side: const BorderSide(color: _fitlyBorderAlt),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fitlyDanger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
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
        backgroundColor: _fitlyCardAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _fitlyBorder),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _brandColor,
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: _fitlyBg,
                  size: 38,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Confirm with Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _fitlyText,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: pwController,
                obscureText: true,
                style: const TextStyle(color: _fitlyText),
                cursorColor: _fitlyGold,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: _fitlyMuted),
                  filled: true,
                  fillColor: _fitlyRaised,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _fitlyBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _fitlyGold),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _fitlySubtleText,
                        side: const BorderSide(color: _fitlyBorderAlt),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fitlyGold,
                        foregroundColor: _fitlyBg,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
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
    var account =
        await gsi.GoogleSignIn.instance.attemptLightweightAuthentication();

    account ??= await gsi.GoogleSignIn.instance.authenticate();

    final googleAuth = account.authentication;
    final cred = GoogleAuthProvider.credential(idToken: googleAuth.idToken);

    await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(cred);
  }

  Future<void> _reauthApple() async {
    final appleCred = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );

    final cred = OAuthProvider('apple.com').credential(
      idToken: appleCred.identityToken,
      accessToken: appleCred.authorizationCode,
    );

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

    final nav = Navigator.of(context);

    if (!await _confirmDeletion()) return;

    try {
      final providers = user.providerData.map((e) => e.providerId).toList();

      if (providers.contains('google.com')) {
        await _reauthGoogle();
      } else if (providers.contains('apple.com')) {
        await _reauthApple();
      } else {
        await _reauthEmail(user.email ?? '');
      }

      final batch = FirebaseFirestore.instance.batch();

      batch.delete(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
      );

      batch.delete(
        FirebaseFirestore.instance.collection('trainer_profiles').doc(user.uid),
      );

      await batch.commit();

      await user.delete();

      if (providers.contains('google.com')) {
        await gsi.GoogleSignIn.instance.disconnect();
      }

      await secureStorage.deleteData('userToken');
      await secureStorage.deleteData('last_profile_view');

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Account Deleted',
          message: 'Your account has been deleted successfully.',
        );
      }

      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'cancelled') return;

      if (mounted) {
        await showInfoDialog(
          context,
          title: 'Error',
          message: prettyAuthError(e),
          error: true,
        );
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
    return _isTrainerRole
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
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _fitlyText,
              ),
              onPressed: _handleReviewBellTap,
            ),
            if (hasNew)
              Positioned(
                right: 9,
                top: 9,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _fitlyDanger,
                    shape: BoxShape.circle,
                    border: Border.all(color: _fitlyBg, width: 1.5),
                  ),
                ),
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

    await showInfoDialog(
      context,
      title: 'New Review',
      message: 'You have received a new review!',
      buttonText: 'OK',
    );
  }

  void _showSignUpPrompt() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _fitlyCardAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _fitlyBorder),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _brandColor,
                child: const Icon(
                  Icons.login_rounded,
                  color: _fitlyBg,
                  size: 38,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Sign-In Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _fitlyText,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Please sign in or sign up to manage your subscription.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _fitlyMuted, height: 1.4),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _fitlySubtleText,
                        side: const BorderSide(color: _fitlyBorderAlt),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fitlyGold,
                        foregroundColor: _fitlyBg,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginPage(),
                          ),
                        );
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

  bool _profileIsVisibleWhenPaywallOff(Map<String, dynamic> data) {
    if (data['profileHidden'] == true ||
        data['isHidden'] == true ||
        data['hidden'] == true) {
      return false;
    }

    if (data['profileVisible'] == false ||
        data['isVisible'] == false ||
        data['visible'] == false) {
      return false;
    }

    return true;
  }

  /* ───────── UI ───────── */
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nav = Navigator.of(context);

    return Scaffold(
      backgroundColor: _fitlyBg,
      bottomNavigationBar: _buildBottomNavigation(),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _fitlyBg,
        surfaceTintColor: _fitlyBg,
        titleSpacing: 0,
        title: const Text(
          'Account',
          style: TextStyle(
            color: _fitlyText,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _fitlyText,
            size: 20,
          ),
          onPressed: () {
            nav.pushReplacement(
              MaterialPageRoute(
                builder: (_) => _isTrainerRole
                    ? const TrainerDashboardPage()
                    : const MarketplacePage(),
              ),
            );
          },
        ),
        actions: [
          if (_isTrainerRole && user != null) _buildReviewBellIcon(user.uid),
          const SizedBox(width: 6),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_fitlyBg, _fitlyBgAlt],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("trainer_profiles")
                  .doc(user?.uid)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                    height: 260,
                    child: Center(
                      child: CircularProgressIndicator(color: _fitlyGold),
                    ),
                  );
                }

                final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                final img = (data['profileImageUrl'] ?? '').toString();

                final bool rawMembershipActive = data['isActive'] ?? false;

                final bool statusIsActive = isTrainerPaymentsEnabled
                    ? rawMembershipActive
                    : _profileIsVisibleWhenPaywallOff(data);

                String displayName = (data['displayName'] ?? '').toString();

                if (displayName.isEmpty) {
                  displayName = user?.displayName ?? 'No Name';
                }

                final String roleLabel =
                    _isTrainerRole ? 'Personal Trainer' : 'Fitly Member';

                final String statusLabel = isTrainerPaymentsEnabled
                    ? (statusIsActive
                        ? 'Membership: Active'
                        : 'Membership: Inactive')
                    : (statusIsActive ? 'Profile: Active' : 'Profile: Hidden');

                final String statusHint = isTrainerPaymentsEnabled
                    ? (statusIsActive
                        ? 'Your trainer membership is active.'
                        : 'Your trainer membership is inactive.')
                    : (statusIsActive
                        ? 'Your profile is visible in the Marketplace.'
                        : 'Your profile is currently hidden from the Marketplace.');

                return Column(
                  children: [
                    _profileHeroCard(
                      imageUrl: img,
                      displayName: displayName,
                      roleLabel: roleLabel,
                      showStatus: _isTrainerRole,
                      statusLabel: statusLabel,
                      statusHint: statusHint,
                      statusIsActive: statusIsActive,
                    ),
                    const SizedBox(height: 14),
                    if (_isTrainerRole) const TrainerFitnessIdentityCard(),
                    if (_isTrainerRole) const SizedBox(height: 14),
                  ],
                );
              },
            ),
            if (_isAdmin) ...[
              _sectionLabel('Fitly Admin'),
              _adminConciergeTile(),
            ],
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _premiumActionTile(
                        icon: Icons.manage_accounts_rounded,
                        title: 'Manage Subscription',
                        subtitle: 'Update billing or manage your plan.',
                        trailingIcon: Icons.arrow_forward_ios_rounded,
                        onTap: () async {
                          if (Platform.isIOS) {
                            await _openIOSManage();
                          } else {
                            if (stripeId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManageSubscriptionPage(
                                    trainerUid: user!.uid,
                                  ),
                                ),
                              );
                            } else if (d['iosOriginalTxId'] != null) {
                              const url =
                                  'https://apps.apple.com/account/subscriptions';

                              await launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
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

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _inactiveMembershipCard(),
                  );
                },
              ),
            _sectionLabel('Profile'),
            _simpleTile(
              icon: Icons.edit_rounded,
              label: 'Edit Profile',
              subtitle: 'Update photos, bio, services and profile details.',
              page: const EditProfilePage(),
            ),
            _sectionLabel('Support'),
            _simpleTile(
              icon: Icons.help_outline_rounded,
              label: 'FAQ / Help',
              subtitle: 'Find answers to common Fitly questions.',
              page: const FAQPage(),
            ),
            _simpleTile(
              icon: Icons.contact_mail_rounded,
              label: 'Contact Us / Support',
              subtitle: 'Get help or send feedback to Fitly.',
              page: const ContactUsPage(),
            ),
            _sectionLabel('Legal'),
            if (isTrainerPaymentsEnabled)
              _simpleTile(
                icon: Icons.receipt_long_rounded,
                label: 'Refund Policy',
                subtitle: 'View the refund and billing policy.',
                page: const RefundPolicyPage(),
              ),
            _termsTile(),
            _simpleTile(
              icon: Icons.privacy_tip_rounded,
              label: 'Privacy Policy',
              subtitle: 'See how Fitly handles your information.',
              page: const PrivacyPolicyPage(),
            ),
            _simpleTile(
              icon: Icons.library_books_rounded,
              label: 'Legal Documents',
              subtitle: 'Access Fitly’s legal pages in one place.',
              page: const LegalDocumentsPage(),
            ),
            _sectionLabel('Account'),
            _deleteTile(),
            const SizedBox(height: 4),
            _logoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _profileHeroCard({
    required String imageUrl,
    required String displayName,
    required String roleLabel,
    required bool showStatus,
    required String statusLabel,
    required String statusHint,
    required bool statusIsActive,
  }) {
    final ImageProvider avatarImage = imageUrl.isNotEmpty
        ? NetworkImage(imageUrl)
        : const AssetImage('assets/default_profile.png') as ImageProvider;

    return Container(
      height: 268,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _fitlyCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _fitlyBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/default_profile.png',
                fit: BoxFit.cover,
              ),
            )
          else
            Image.asset(
              'assets/default_profile.png',
              fit: BoxFit.cover,
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(7, 8, 10, 0.12),
                  Color.fromRGBO(7, 8, 10, 0.52),
                  Color.fromRGBO(7, 8, 10, 0.94),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _fitlyGold.withValues(alpha: 0.16),
                    border: Border.all(
                      color: _fitlyGold.withValues(alpha: 0.65),
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: _fitlyRaised,
                    backgroundImage: avatarImage,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _fitlyText,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _fitlyMuted,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (showStatus)
                              Tooltip(
                                message: statusHint,
                                preferBelow: false,
                                child: _statusPill(
                                  label: statusLabel,
                                  active: statusIsActive,
                                ),
                              ),
                            _smallEditButton(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required bool active,
  }) {
    final Color dotColor = active ? _fitlySuccess : _fitlyDanger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _fitlyBg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? _fitlySuccess.withValues(alpha: 0.45)
              : _fitlyDanger.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.5,
            height: 7.5,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _fitlyText,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallEditButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const EditProfilePage(),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _fitlyGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _fitlyGold.withValues(alpha: 0.45),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_rounded,
              color: _fitlyGold,
              size: 15,
            ),
            SizedBox(width: 6),
            Text(
              'Edit',
              style: TextStyle(
                color: _fitlyGold,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inactiveMembershipCard() {
    return Container(
      decoration: BoxDecoration(
        color: _fitlyCardAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _fitlyGold.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _openSubscriptionSheet,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _fitlyGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _fitlyGold.withValues(alpha: 0.32),
                      ),
                    ),
                    child: const Icon(
                      Icons.payment_rounded,
                      color: _fitlyGold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activate Membership',
                          style: TextStyle(
                            color: _fitlyText,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Start your trainer subscription.',
                          style: TextStyle(
                            color: _fitlyMuted,
                            fontSize: 13.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _fitlyMuted,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (!Platform.isIOS)
            Padding(
              padding: const EdgeInsets.fromLTRB(78, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _showPromoDialog,
                  child: const Text(
                    'Have a promo code?',
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _fitlyGold,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: _fitlyGold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 9),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: _fitlyMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _premiumActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required IconData trailingIcon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color iconColor = _fitlyGold,
    Color? titleColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _fitlyCardAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _fitlyBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.26),
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? _fitlyText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _fitlyMuted,
                        fontSize: 13,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                trailingIcon,
                color: _fitlyMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ───────── helper tile builders (no context-after-await) ───────── */
  Widget _simpleTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Widget page,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _premiumActionTile(
          icon: icon,
          title: label,
          subtitle: subtitle,
          trailingIcon: Icons.arrow_forward_ios_rounded,
          onTap: () {
            final navigator = Navigator.of(context);

            SchedulerBinding.instance.addPostFrameCallback((_) {
              navigator.push(MaterialPageRoute(builder: (_) => page));
            });
          },
        ),
      );

  Widget _adminConciergeTile() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _premiumActionTile(
          icon: Icons.support_agent_rounded,
          title: 'Concierge Inbox',
          subtitle: 'View and reply to customer trainer requests.',
          trailingIcon: Icons.arrow_forward_ios_rounded,
          iconColor: _fitlyGold,
          onTap: () {
            final navigator = Navigator.of(context);

            SchedulerBinding.instance.addPostFrameCallback((_) {
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => const ConciergeInboxPage(),
                ),
              );
            });
          },
        ),
      );

  Widget _deleteTile() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _premiumActionTile(
          icon: Icons.delete_forever_rounded,
          title: 'Delete Account',
          subtitle: 'Permanently remove your account and profile data.',
          trailingIcon: Icons.arrow_forward_ios_rounded,
          iconColor: _fitlyDanger,
          titleColor: _fitlyDanger,
          onTap: _handleDeleteAccount,
        ),
      );

  Widget _termsTile() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: _fitlyCardAlt,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _fitlyBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _fitlyGold.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _fitlyGold.withValues(alpha: 0.26),
                    ),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: _fitlyGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          color: _fitlyText,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'By using this platform, you agree to our Terms & Conditions.',
                        style: TextStyle(
                          color: _fitlyMuted,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: _fitlyGold,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'View Terms & Conditions',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                            decorationColor: _fitlyGold,
                          ),
                        ),
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _fitlyDanger,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.logout_rounded),
        label: const Text(
          'Log Out',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          final navigator = Navigator.of(context);

          await FirebaseAuth.instance.signOut();
          await prefs.remove('userRole');
          await secureStorage.deleteData('userToken');
          await secureStorage.deleteData('last_profile_view');

          SchedulerBinding.instance.addPostFrameCallback((_) {
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const WelcomePage()),
            );
          });
        },
      ),
    );
  }
}
