import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'marketplace_page.dart';
import 'trainer_profile_setup_page.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  EmailVerificationPageState createState() => EmailVerificationPageState();
}

class EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isEmailVerified = false;
  bool _isResending = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkEmailVerified();
  }

  // ✅ Check if email is verified
  Future<void> _checkEmailVerified() async {
    setState(() {
      _isChecking = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      bool isVerified = user?.emailVerified ?? false;

      if (!mounted) return;
      setState(() {
        _isEmailVerified = isVerified;
      });

      if (_isEmailVerified) {
        // ✅ Update Firestore to mark email as verified
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({
          'emailVerified': true,
        });

        // ✅ Get user role safely
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        String role = userDoc.exists ? userDoc.get('role') : 'Customer';

        if (!mounted) return;

        // ✅ Redirect based on role
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => (role == 'Personal Trainer')
                ? const TrainerProfileSetupPage()
                : const MarketplacePage(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error checking email verification: $e")),
      );
    }

    setState(() {
      _isChecking = false;
    });
  }

  // ✅ Resend verification email
  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
    });

    try {
      await FirebaseAuth.instance.currentUser!.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("📩 Verification email resent! Check inbox.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to resend email: $e")),
      );
    }

    setState(() {
      _isResending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Your Email")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "A verification email has been sent to your email.\nPlease verify before continuing.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isResending ? null : _resendEmail,
                child: _isResending
                    ? const CircularProgressIndicator()
                    : const Text("Resend Verification Email"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isChecking ? null : _checkEmailVerified,
                child: _isChecking
                    ? const CircularProgressIndicator()
                    : const Text("I have verified my email"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
