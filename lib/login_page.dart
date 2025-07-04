import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'email_verification_page.dart';
import 'forgot_password_page.dart';
import 'role_redirect.dart';
import 'secure_storage_service.dart';
import 'services/auth_service.dart'; // ← NEW
import 'ui/social_signin_buttons.dart';

/* ───────────────────── Logger ───────────────────── */
final Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/* ──────── Helper that turns Firebase errors into nice text ─────── */
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

/* ───────────────────── Widget ───────────────────── */
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /* Controllers & services */
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecureStorageService secureStorage = SecureStorageService();
  final Color _brandColor = const Color(0xFFFFA726);

  /* Simple loading flag */
  bool _isLoading = false;

  /* ───────────── styled info / error dialog ───────────── */
  Future<void> _showInfoDialog({
    required String title,
    required String message,
    bool error = false,
    String buttonText = 'OK',
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: error ? Colors.red : _brandColor,
                child: Icon(
                  error
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(buttonText, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ──────────────── Social sign-in handler ─────────────── */
  Future<void> _handleSocialSignIn(
      Future<UserCredential?> Function() providerMethod) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final cred = await providerMethod();
      if (cred == null) throw Exception('Sign-in aborted by user');

      // look up user profile
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(cred.user!.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        await _showInfoDialog(
          title: 'No account found',
          message:
              'This e-mail address is not registered yet. Please create an account before logging in.',
          error: true,
          buttonText: 'Go back',
        );
        await _auth.signOut();
        setState(() => _isLoading = false);
        return;
      }

      // cache role
      final role = (docSnap.data()!['role'] ?? '').toString().toLowerCase();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', role);

      // fresh ID token
      final idToken = await cred.user!.getIdToken();
      unawaited(secureStorage.writeData('auth_token', idToken!));

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleRedirect()),
        (_) => false,
      );
    } catch (e, s) {
      logger.e('Social sign-in failed', error: e, stackTrace: s);
      await _showInfoDialog(
        title: 'Login failed',
        message: prettyAuthError(e),
        error: true,
        buttonText: 'Close',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ───────────────────────── Email Login ───────────────────────── */
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      logger.w('Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // tear down anonymous session
      if (_auth.currentUser?.isAnonymous == true) {
        await _auth.signOut();
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = cred.user;
      if (user == null) throw Exception('Null user');

      // e-mail verification
      if (!user.emailVerified) {
        await user.reload();
        if (!user.emailVerified) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
          );
          return;
        }
      }

      // fresh token
      final idToken = await user.getIdToken();
      if (idToken != null) {
        unawaited(secureStorage.writeData('auth_token', idToken));
      }

      // clear cached role (will be re-set inside RoleRedirect)
      unawaited(_clearCachedRole());

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleRedirect()),
        (_) => false,
      );
    } catch (e, s) {
      logger.e('Login failed', error: e, stackTrace: s);
      await _showInfoDialog(
        title: 'Login failed',
        message: prettyAuthError(e),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCachedRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
  }

  /* ───────────────────────── UI ───────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromRGBO(255, 167, 38, 1), Color(0xFFFB8C00)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/Fitly2.png', height: 120),
                    const SizedBox(height: 24),

                    /* ───────────── Email / password form ───────────── */
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter your email'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter your password'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : ElevatedButton(
                                    onPressed: _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      textStyle: const TextStyle(fontSize: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Login',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage()),
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    /* ───────────── Social buttons ───────────── */
                    SocialSignInButtons(
                      loading: _isLoading,
                      onGooglePressed: () =>
                          _handleSocialSignIn(AuthService.googleOneTap),
                      onApplePressed: () =>
                          _handleSocialSignIn(AuthService.appleOneTap),
                    ),

                    // Optional notice for non-Apple platforms (button already hides itself)
                    if (!Platform.isIOS && !Platform.isMacOS) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Apple Sign-In available on iOS',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
