import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'trainer_home_page.dart';
import 'feature_flags.dart'; // ← NEW

class PaymentSetupPage extends StatefulWidget {
  const PaymentSetupPage({super.key});

  @override
  PaymentSetupPageState createState() => PaymentSetupPageState();
}

class PaymentSetupPageState extends State<PaymentSetupPage> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Skip this screen entirely while payments are disabled.
    if (!isTrainerPaymentsEnabled) {
      debugPrint('▶️ Trainer payments disabled — skipping PaymentSetupPage');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  // Simulated Stripe PaymentSheet flow.
  Future<void> _processStripePayment() async {
    if (!mounted) return;

    setState(() => _isProcessing = true);

    try {
      // Replace with clientSecret returned by your backend.
      const String clientSecret =
          'pi_3NXXXxXXXXXXXXXXXXXXXX_secret_XXXXXXXXXXXXXXXX';

      // 1. Init Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Your App Name',
          style: ThemeMode.light,
        ),
      );

      // 2. Present Sheet
      await Stripe.instance.presentPaymentSheet();

      // 3. Mark trainer as paid
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('trainer_profiles')
            .doc(user.uid)
            .update({'paymentCompleted': true});
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Payment Successful.')));

      // 4. Go to Trainer Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TrainerHomePage(
            showProfileCompleteMessage: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Payment failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Failed. Please try again.')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extra guard: if flag is off and we’re still here, show nothing.
    if (!isTrainerPaymentsEnabled) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Setup'),
        backgroundColor: Colors.lightBlue,
      ),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Please complete your payment to continue.\n\n'
                      'A Stripe PaymentSheet will be displayed for test payment processing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      onPressed: _processStripePayment,
                      child: const Text('Complete Payment'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
