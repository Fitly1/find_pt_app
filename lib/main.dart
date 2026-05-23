// ignore_for_file: prefer_const_constructors, avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/* ─── local files ─── */
import 'firebase_options.dart';
import 'package:find_pt_app/services/push_notification_service.dart';
import 'package:find_pt_app/navigation.dart'; // <-- navigatorKey lives here
import 'package:find_pt_app/landing_gate.dart';
import 'welcome_page.dart';
import 'marketplace_page.dart';
import 'signup_page.dart';
import 'trainer_profile_setup_page.dart';
import 'login_page.dart';
import 'forgot_password_page.dart';
import 'role_redirect.dart';
import 'listings_page.dart';
import 'trainer_home_page.dart';
import 'profile_page.dart' as profile;
import 'messages_page.dart';
import 'manage_subscription.dart';

final Logger logger = Logger(printer: PrettyPrinter());

/* ───────── EDGE-TO-EDGE UI STYLE ───────── */
const SystemUiOverlayStyle _edgeToEdgeOverlayStyle = SystemUiOverlayStyle(
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarContrastEnforced: false,
);

Future<void> _configureEdgeToEdgeSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(_edgeToEdgeOverlayStyle);
}

/* ───────── CRASHLYTICS SETUP ───────── */
Future<void> _configureCrashlytics() async {
  // Prevent debug/development testing from polluting Firebase Crashlytics.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    kReleaseMode,
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    }

    debugPrint('Uncaught platform error: $error');
    return false;
  };
}

/* ───────── HELPERS ───────── */
Future<bool> _runningOnIosSimulator() async {
  if (!Platform.isIOS) return false;
  final info = await DeviceInfoPlugin().iosInfo;
  return !info.isPhysicalDevice; // true when on simulator
}

/* ───────── FCM BACKGROUND HANDLER ───────── */
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔹 BG message handled: ${message.messageId}');
}

/* ───────── UPDATE GATE (Android + iOS) ───────── */
const String kAppStoreUrl = 'https://apps.apple.com/app/id6745589939';

class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      if (Platform.isAndroid) {
        // Only run Play Core update checks in release builds.
        if (kReleaseMode) {
          final info = await InAppUpdate.checkForUpdate();
          if (!mounted) return;
          if (info.updateAvailability == UpdateAvailability.updateAvailable) {
            await InAppUpdate.performImmediateUpdate();
          }
        }
      } else if (Platform.isIOS) {
        await _ensureRemoteConfigReady();
        final needUpdate = await _isBelowMinVersion(
          platformKey: 'min_version_ios',
        );
        if (!mounted) return;
        if (needUpdate) {
          await _showIosUpdateDialog();
        }
      } else {
        // Other platforms: optional check via Remote Config
        await _ensureRemoteConfigReady();
        await _isBelowMinVersion(platformKey: 'min_version_android'); // no-op
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    } finally {
      if (mounted) setState(() => _checked = true);
    }
  }

  Future<void> _ensureRemoteConfigReady() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    try {
      await rc.fetchAndActivate();
    } catch (_) {
      // Use cached/defaults if fetch fails
    }
  }

  Future<bool> _isBelowMinVersion({required String platformKey}) async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final current = pkg.version; // e.g., "1.0.3"
      final rc = FirebaseRemoteConfig.instance;
      final minRequired = rc.getString(platformKey).trim(); // e.g., "1.0.4"
      if (minRequired.isEmpty) return false;
      return _compareSemver(current, minRequired) < 0;
    } catch (e) {
      debugPrint('Version compare failed: $e');
      return false;
    }
  }

  /// Returns -1 if `a < b`, 0 if equal, 1 if `a > b`.
  int _compareSemver(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Use blocks with while (lint fix) and avoid < > in doc comment (lint fix).
    while (pa.length < 3) {
      pa.add(0);
    }
    while (pb.length < 3) {
      pb.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i] < pb[i] ? -1 : 1;
    }
    return 0;
  }

  Future<void> _showIosUpdateDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false, // force the update
      builder: (_) => AlertDialog(
        title: const Text('Update required'),
        content: const Text(
          'A newer version of the app is available. Please update to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse(kAppStoreUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Now that UpdateGate is inside MaterialApp, Directionality is already present.
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}

/* ───────── DEEP-LINK HANDLER ───────── */
class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  const DeepLinkHandler({super.key, required this.child});
  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  Future<void> _initDeepLinkListener() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleDeepLink(initial.toString());
    } catch (e) {
      debugPrint('Failed to get initial deep link: $e');
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) _handleDeepLink(uri.toString());
      },
      onError: (err) => debugPrint('Error receiving deep link: $err'),
    );
  }

  void _handleDeepLink(String link) {
    if (link.startsWith('fitly://billing-portal-return')) {
      Navigator.of(context).pushNamed('/ManageSubscription');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/* ───────── STRIPE CHECKOUT HELPER ───────── */
Future<void> startStripeCheckout(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email ?? "test@example.com";

    final response = await http.post(
      Uri.parse(
          "https://us-central1-findptapp.cloudfunctions.net/api/createCheckoutSession"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "trainerUid": FirebaseAuth.instance.currentUser?.uid ?? "12345",
        "email": userEmail,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['url'] != null) {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: data['url'],
          merchantDisplayName: "FindPTApp",
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } else {
      throw Exception("Failed to create Stripe session");
    }
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text("Payment failed! Try again.")),
    );
  }
}

/* ══════════════════════════ main ══════════════════════════ */
Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await _configureEdgeToEdgeSystemUi();

      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await FirebaseAppCheck.instance.activate(
        androidProvider: kReleaseMode
            ? AndroidProvider.playIntegrity
            : AndroidProvider.debug,
        appleProvider:
            kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
      );

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      await PushNotificationService.initialize();

      Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? "";

      await _configureCrashlytics();

      runApp(
        ProviderScope(
          child: DeepLinkHandler(
            child: const FindPTApp(),
          ),
        ),
      );
    },
    (e, s) {
      if (kReleaseMode && Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(e, s, fatal: true);
      } else {
        debugPrint('Uncaught zone error: $e');
      }
    },
  );
}

/* ───────── (reference) ROOT GATE ───────── */
class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null || user.isAnonymous) return const MarketplacePage();
        return const RoleRedirect();
      },
    );
  }
}

/* ══════════════════════════ APP ══════════════════════════ */
class FindPTApp extends StatefulWidget {
  const FindPTApp({super.key});
  @override
  State<FindPTApp> createState() => _FindPTAppState();
}

class _FindPTAppState extends State<FindPTApp> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<RemoteMessage>? _fgSub;

  @override
  void initState() {
    super.initState();
    _configureFCM();
    _authSub =
        FirebaseAuth.instance.authStateChanges().listen((_) => _configureFCM());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _fgSub?.cancel();
    super.dispose();
  }

  /* ---------- save FCM token ---------- */
  Future<void> _saveToken(String? token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .doc(token)
        .set({
      'createdAt': FieldValue.serverTimestamp(),
      'platform': Platform.operatingSystem,
    });
    debugPrint('✅ token saved for $uid');
  }

  /* ---------- configure FCM ---------- */
  Future<void> _configureFCM() async {
    final fcm = FirebaseMessaging.instance;
    final settings =
        await fcm.requestPermission(alert: true, badge: true, sound: true);
    debugPrint('perm: ${settings.authorizationStatus}');

    if (await _runningOnIosSimulator()) {
      debugPrint('📵  Running on iOS simulator – skipping FCM/APNs token');
    } else {
      try {
        await _saveToken(await fcm.getToken());
      } catch (e) {
        debugPrint('❌ Failed to get FCM token: $e');
      }
      fcm.onTokenRefresh.listen(_saveToken);
    }

    _fgSub?.cancel();
    _fgSub = FirebaseMessaging.onMessage
        .listen((msg) => PushNotificationService.showFlutterNotification(msg));

    final initial = await fcm.getInitialMessage();
    if (initial != null) _handleNavigation(initial);
  }

  void _handleNavigation(RemoteMessage msg) {
    final route = msg.data['route'] as String?;
    if (route != null && mounted) {
      Navigator.of(context).pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _edgeToEdgeOverlayStyle,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Find PT App',
        debugShowCheckedModeBanner: false,
        // Wrap the home only, not the whole app
        home: const UpdateGate(
          child: LandingGate(),
        ), // guests → marketplace, signed-in → RoleRedirect
        routes: {
          '/welcome': (context) => const WelcomePage(),
          '/marketplace': (context) => const MarketplacePage(),
          '/signup': (context) => const SignupPage(),
          '/login': (context) => const LoginPage(),
          '/forgot_password': (context) => const ForgotPasswordPage(),
          '/trainer_profile_setup': (context) =>
              const TrainerProfileSetupPage(),
          '/role_redirect': (context) => const RoleRedirect(),
          '/listings': (context) => const ListingsPage(),
          '/trainer_home': (context) => const TrainerHomePage(),
          '/messages': (context) => const MessagesPage(),
          '/profile': (context) => const profile.ProfilePage(),
          '/ManageSubscription': (context) {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            return ManageSubscriptionPage(trainerUid: uid);
          },
        },
      ),
    );
  }
}
