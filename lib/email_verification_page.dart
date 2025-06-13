import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'marketplace_page.dart';
import 'trainer_profile_setup_page.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isEmailVerified = false;
  bool _isLoading = false;
  bool _resent = false;
  String? userRole;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      final verified = user?.emailVerified ?? false;

      if (verified) {
        timer.cancel();

        // ✅ Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .set({'emailVerified': true}, SetOptions(merge: true));

        // ✅ Load user role from Firestore before navigating
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        userRole = (doc.data()?['role'] as String?)?.toLowerCase();

        if (!mounted) return;
        _navigateAfterVerify();
      }
    });
  }

  Future<void> _checkEmailVerifiedManually() async {
    setState(() => _isLoading = true);
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;
    final verified = user?.emailVerified ?? false;

    if (verified) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set({'emailVerified': true}, SetOptions(merge: true));

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      userRole = (doc.data()?['role'] as String?)?.toLowerCase();

      if (!mounted) return;
      _navigateAfterVerify();
    } else {
      setState(() {
        _isEmailVerified = false;
        _isLoading = false;
      });
      _showSnack(const Text('Email not verified yet.'));
    }
  }

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
    if (!mounted) return;

    if (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrainerProfileSetupPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MarketplacePage()),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFA726),
      appBar: AppBar(
        title: const Text('Verify Your Email',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFFA726),
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
                  const Icon(Icons.email, size: 50, color: Colors.orange),
                  const SizedBox(height: 12),
                  const Text(
                    'Please Verify Your Email Address',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We have sent a verification link to your email. '
                    'Please check your inbox (and spam) and verify your account '
                    'to continue.',
                    style: TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 16),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
