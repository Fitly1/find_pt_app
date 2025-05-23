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

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _checkEmailVerified();
  }

  /* ───────────────────────────────── ROLE ───────────────────────────────── */

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    String? role = prefs.getString('userRole');

    if (role == null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        role = (doc['role'] as String?)?.toLowerCase();
        if (role != null) await prefs.setString('userRole', role);
      }
    } else {
      role = role.toLowerCase();
    }

    if (mounted) setState(() => userRole = role);
  }

  /* ───────────────────────────── VERIFY / RESEND ────────────────────────── */

  Future<void> _checkEmailVerified() async {
    setState(() => _isLoading = true);
    await FirebaseAuth.instance.currentUser?.reload();
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (mounted) {
      setState(() {
        _isEmailVerified = verified;
        _isLoading = false;
      });
    }
  }

  Future<void> _resendEmail() async {
    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
    if (!mounted) return; // guard ①
    setState(() => _resent = true);
    _showSnack(const Text('Verification email resent!'));
  }

  /* ─────────────────────────── CONTEXT HELPERS ─────────────────────────── */

  void _showSnack(Widget content) {
    if (!mounted) return; // guard ② (directly before context)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: content));
  }

  void _navigateAfterVerify() {
    if (!mounted) return; // guard ③
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

  /* ────────────────────────────────── UI ────────────────────────────────── */

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

                  /* ─────────── “I have verified” ─────────── */
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
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await _checkEmailVerified();
                            if (!mounted) return; // guard just after await
                            if (_isEmailVerified) {
                              _navigateAfterVerify();
                            } else {
                              _showSnack(const Text('Email not verified yet.'));
                            }
                          },
                  ),
                  const SizedBox(height: 16),

                  /* ─────────── Resend verification ─────────── */
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
