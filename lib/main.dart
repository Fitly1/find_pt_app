// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kReleaseMode
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
import 'manage_subscription.dart'; // This now uses your dynamic portal logic.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // Import Firebase App Check
import 'package:logger/logger.dart';

// Create a logger instance
final Logger logger = Logger(printer: PrettyPrinter());

/// FCM: Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

/// DeepLinkHandler listens for incoming app links.
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
      // Using the new API: getInitialLink() returns the initial deep link URI.
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink.toString());
      }
    } catch (e) {
      debugPrint('Failed to get initial deep link: $e');
    }

    _linkSub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri.toString());
      }
    }, onError: (err) {
      debugPrint('Error receiving deep link: $err');
    });
  }

  void _handleDeepLink(String link) {
    debugPrint('Deep link received: $link');

    if (link.startsWith('fitly://payment-success')) {
      debugPrint('Payment was successful!');
      // Additional logic if needed.
    } else if (link.startsWith('fitly://payment-cancel')) {
      debugPrint('Payment was cancelled!');
      // Additional logic if needed.
    } else if (link.startsWith('fitly://billing-portal-return')) {
      debugPrint('Billing portal return received!');
      Navigator.of(context).pushNamed('/ManageSubscription');
    } else {
      debugPrint('Received unknown link: $link');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Initiates a Stripe checkout session.
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

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 && responseData['url'] != null) {
      final checkoutUrl = responseData['url'];
      debugPrint("Opening Stripe Checkout URL: $checkoutUrl");

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: checkoutUrl,
          merchantDisplayName: "FindPTApp",
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } else {
      throw Exception("Failed to create Stripe session");
    }
  } catch (error) {
    debugPrint("❌ Payment error: $error");
    messenger.showSnackBar(
      SnackBar(content: Text("Payment failed! Try again.")),
    );
  }
}

/// This function checks if there is an existing user and forces sign-out if they are anonymous.
/// Adjust this logic if you want to allow anonymous access for non-sensitive features.
Future<void> initAuth() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && user.isAnonymous) {
    await FirebaseAuth.instance.signOut();
    debugPrint(
        "Anonymous user signed out before proceeding with verified sign-in.");
  } else if (user == null) {
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint(
        "Signed in anonymously: ${FirebaseAuth.instance.currentUser?.uid}");
  }
}

Future<void> main() async {
  // Ensure Flutter bindings are initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from the .env file in the project root.
  await dotenv.load(fileName: ".env");
  logger.i(
      "Environment loaded: Stripe publishable key = ${dotenv.env['STRIPE_PUBLISHABLE_KEY']}");

  // Initialize Firebase BEFORE any Firebase services are used.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  logger.i("Firebase initialized.");

  // Now, run the rest of your initialization within a zone.
  runZonedGuarded(() async {
    // Activate Firebase App Check.
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      appleProvider:
          kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
    );
    logger.i("Firebase App Check activated.");

    // Initialize authentication.
    await initAuth();
    logger.i("Authentication initialized.");

    // Register FCM background message handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Set the Stripe publishable key from environment variables.
    Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? "";
    logger.i("Stripe publishable key set.");

    // Optional: Set up FCM foreground listener.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          'Received a foreground message: ${message.notification?.title}');
    });

    // Set up Crashlytics global error handling.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    logger.i("Crashlytics set up.");

    // Run the app.
    runApp(
      ProviderScope(
        child: DeepLinkHandler(
          child: const FindPTApp(),
        ),
      ),
    );
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
  });
}

class FindPTApp extends StatelessWidget {
  const FindPTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Find PT App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/marketplace': (context) => const MarketplacePage(),
        '/signup': (context) => const SignupPage(),
        '/login': (context) => const LoginPage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/trainer_profile_setup': (context) => const TrainerProfileSetupPage(),
        '/role_redirect': (context) => const RoleRedirect(),
        '/listings': (context) => const ListingsPage(),
        '/trainer_home': (context) => const TrainerHomePage(),
        '/messages': (context) => const MessagesPage(),
        '/profile': (context) => const profile.ProfilePage(),
        '/ManageSubscription': (context) {
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          return ManageSubscriptionPage(trainerUid: currentUid);
        },
      },
    );
  }
}
