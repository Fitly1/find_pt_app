import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'marketplace_page.dart';
import 'trainer_profile_setup_page.dart';
import 'welcome_page.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isLoading = false;
  bool _resent = false;
  String? _userRole;
  Timer? _verificationTimer;
  bool _navigated = false; // ✅ prevents double navigation

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  // Periodically check if the user verified their email
  void _startVerificationCheck() {
    _verificationTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      // ensure we have a user
      final auth = FirebaseAuth.instance;
      await auth.currentUser?.reload();
      final user = auth.currentUser;
      final verified = user?.emailVerified ?? false;

      if (verified && user != null) {
        timer.cancel();
        await _handleVerified(user);
      }
    });
  }

  // Manual "I have verified" button
  Future<void> _checkEmailVerifiedManually() async {
    setState(() => _isLoading = true);

    final auth = FirebaseAuth.instance;
    await auth.currentUser?.reload();
    final user = auth.currentUser;
    final verified = user?.emailVerified ?? false;

    if (verified && user != null) {
      await _handleVerified(user);
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(const Text('Email not verified yet.'));
    }
  }

  // Common path once verified
  Future<void> _handleVerified(User user) async {
    if (_navigated) return; // ✅ guard

    // Mark verified in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'emailVerified': true}, SetOptions(merge: true));

    // Fetch role
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    _userRole = (doc.data()?['role'] as String?)?.toLowerCase();

    if (!mounted) return;
    _navigateAfterVerify();
  }

  // Resend verification email
  Future<void> _resendEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      setState(() => _resent = true);
      _showSnack(const Text('Verification email resent!'));
    } catch (e) {
      _showSnack(Text('Failed to resend email: $e'));
    }
  }

  void _showSnack(Widget content) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: content));
  }

  void _navigateAfterVerify() {
    if (!mounted || _navigated) return;
    _navigated = true;

    final role = (_userRole ?? '').toLowerCase();

    if (role == 'trainer' ||
        role == 'personal trainer' ||
        role == 'personaltrainer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrainerProfileSetupPage()),
      );
    } else if (role == 'customer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MarketplacePage()),
      );
    } else {
      // Fallback if role missing/unknown
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );
    }
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFFFA726);

    return Scaffold(
      backgroundColor: brand,
      appBar: AppBar(
        title: const Text('Verify Your Email',
            style: TextStyle(color: Colors.white)),
        backgroundColor: brand,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email, size: 50, color: brand),
                  const SizedBox(height: 12),
                  const Text(
                    'Please Verify Your Email Address',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We have sent a verification link to your email. '
                    'Please check your inbox (and spam) and verify your account to continue.',
                    style: TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Manual check button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('I have verified'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      textStyle: const TextStyle(fontSize: 16),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _checkEmailVerifiedManually,
                  ),
                  const SizedBox(height: 12),

                  // Resend button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _resendEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Resend Verification Email',
                        style: TextStyle(color: Colors.white)),
                  ),

                  if (_resent)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Verification email resent.',
                          style: TextStyle(color: Colors.green)),
                    ),

                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
