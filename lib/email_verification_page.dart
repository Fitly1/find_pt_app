import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'role_redirect.dart';
import 'welcome_page.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _card = Color(0xFF111318);
  static const Color _raised = Color(0xFF20242C);
  static const Color _border = Color(0xFF303540);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);
  static const Color _textSoft = Color(0xFF7E8794);
  static const Color _success = Color(0xFF6DD58C);
  static const Color _error = Color(0xFFE57373);

  bool _isChecking = false;
  bool _isResending = false;
  bool _resent = false;
  bool _navigated = false;

  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    _verificationTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_navigated) {
        timer.cancel();
        return;
      }

      try {
        final auth = FirebaseAuth.instance;
        await auth.currentUser?.reload();

        final user = auth.currentUser;

        if (user != null && user.emailVerified) {
          timer.cancel();
          await _handleVerified(user);
        }
      } catch (_) {
        // Background check failed silently. Manual check still works.
      }
    });
  }

  Future<void> _checkEmailVerifiedManually() async {
    if (_isChecking || _navigated) return;

    setState(() => _isChecking = true);

    try {
      final auth = FirebaseAuth.instance;
      await auth.currentUser?.reload();

      final user = auth.currentUser;

      if (user == null) {
        _showSnack(
          'Session expired. Please start again.',
          backgroundColor: _error,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
        return;
      }

      if (user.emailVerified) {
        await _handleVerified(user);
      } else {
        _showSnack(
          'Email not verified yet.',
          backgroundColor: _raised,
        );
      }
    } catch (_) {
      _showSnack(
        'Could not check verification. Try again.',
        backgroundColor: _error,
      );
    } finally {
      if (mounted && !_navigated) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _handleVerified(User user) async {
    if (_navigated) return;
    _navigated = true;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'emailVerified': true,
        'emailVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // If Firebase Auth confirms verification, do not block the user.
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleRedirect()),
      (_) => false,
    );
  }

  Future<void> _resendEmail() async {
    if (_isResending || _navigated) return;

    setState(() => _isResending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnack(
          'Session expired. Please start again.',
          backgroundColor: _error,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
        return;
      }

      await user.sendEmailVerification();

      if (!mounted) return;

      setState(() => _resent = true);

      _showSnack(
        'Verification email resent.',
        backgroundColor: _raised,
      );
    } catch (_) {
      _showSnack(
        'Failed to resend email. Try again soon.',
        backgroundColor: _error,
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showSnack(
    String message, {
    Color backgroundColor = _raised,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _bgBottom,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bgTop,
        appBar: AppBar(
          title: const Text(
            'Verify Email',
            style: TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          backgroundColor: _bgTop,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: _textMain),
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: _VerificationBackground()),
            Positioned.fill(
              child: SafeArea(
                top: false,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMainCard(email),
                        const SizedBox(height: 16),
                        _buildActionCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 82,
            width: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _raised,
              border: Border.all(
                color: _gold.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.15),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              color: _gold,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Check your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMain,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            email.isNotEmpty
                ? 'We sent a verification link to $email.'
                : 'We sent a verification link to your email.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 14.8,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Verify your email, then come back and tap the button below.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSoft,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (_resent) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _success.withValues(alpha: 0.45),
                ),
              ),
              child: const Text(
                'Verification email resent',
                style: TextStyle(
                  color: _success,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _PrimaryFitlyButton(
            text: _isChecking ? 'Checking...' : 'I have verified',
            loading: _isChecking,
            onPressed: _isChecking ? null : _checkEmailVerifiedManually,
          ),
          const SizedBox(height: 12),
          _SecondaryFitlyButton(
            text: _isResending ? 'Sending...' : 'Resend verification email',
            loading: _isResending,
            onPressed: _isResending ? null : _resendEmail,
          ),
        ],
      ),
    );
  }
}

class _PrimaryFitlyButton extends StatelessWidget {
  const _PrimaryFitlyButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  static const Color _gold = Color(0xFFE7B95C);
  static const Color _goldDeep = Color(0xFFC98E2B);
  static const Color _textDark = Color(0xFF121212);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _borderStrong = Color(0xFF343A46);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gold, _goldDeep],
                ),
          color: onPressed == null ? _borderStrong : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (onPressed != null)
              BoxShadow(
                color: _gold.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: _textDark,
            disabledForegroundColor: _textMain,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: loading
              ? const SizedBox(
                  height: 21,
                  width: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    valueColor: AlwaysStoppedAnimation<Color>(_textMain),
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SecondaryFitlyButton extends StatelessWidget {
  const _SecondaryFitlyButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  static const Color _raised = Color(0xFF20242C);
  static const Color _border = Color(0xFF343A46);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _raised,
          foregroundColor: _textMain,
          disabledForegroundColor: _textMuted,
          side: BorderSide(
            color: _border.withValues(alpha: 0.95),
            width: 1.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: EdgeInsets.zero,
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(_textMain),
                ),
              )
            : Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  color: _textMain,
                ),
              ),
      ),
    );
  }
}

class _VerificationBackground extends StatelessWidget {
  const _VerificationBackground();

  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _gold = Color(0xFFE7B95C);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
        ),
        Positioned(
          top: -140,
          right: -120,
          child: Container(
            height: 290,
            width: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.11),
            ),
          ),
        ),
        Positioned(
          bottom: -170,
          left: -140,
          child: Container(
            height: 340,
            width: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.07),
            ),
          ),
        ),
      ],
    );
  }
}
