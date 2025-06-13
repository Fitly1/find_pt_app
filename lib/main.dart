// ignore_for_file: prefer_const_constructors
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import 'firebase_options.dart';
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

/* ───────── FCM background handler ───────── */
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

/* ───────── Deep-link handler widget ───────── */
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
    debugPrint('Deep link: $link');
    if (link.startsWith('fitly://payment-success')) {
      debugPrint('Payment success');
    } else if (link.startsWith('fitly://payment-cancel')) {
      debugPrint('Payment cancel');
    } else if (link.startsWith('fitly://billing-portal-return')) {
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

/* ───────── Stripe checkout helper (unchanged) ───────── */
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
    debugPrint("❌ Payment error: $e");
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

      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);

      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
        appleProvider:
            kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
      );

      // NOTE: No automatic anonymous sign-in here.
      // “Browse as guest” will call signInAnonymously() explicitly
      // from the WelcomePage.

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? "";

      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError = (FlutterErrorDetails details) {
        try {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } catch (e) {
          debugPrint('⚠️ Crashlytics upload failed: $e');
        }
      };

      runApp(
        ProviderScope(
          child: DeepLinkHandler(
            child: const FindPTApp(),
          ),
        ),
      );
    },
    (error, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack);
      } catch (_) {
        debugPrint('⚠️ Crashlytics recordError failed');
      }
    },
  );
}

/* ───────── Root gate to keep users logged-in ───────── */
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        if (user == null || user.isAnonymous) return const WelcomePage();

        return const RoleRedirect();
      },
    );
  }
}

/* ───────── MaterialApp & routes ───────── */
class FindPTApp extends StatelessWidget {
  const FindPTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Find PT App',
      debugShowCheckedModeBanner: false,
      home: const RootGate(),
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
    );
  }
}