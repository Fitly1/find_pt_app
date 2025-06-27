// lib/login_page.dart
import 'dart:async' show unawaited; // ← for unawaited()
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import 'role_redirect.dart';
import 'forgot_password_page.dart';
import 'email_verification_page.dart';
import 'secure_storage_service.dart';

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

/* ───────────────────── Widget ───────────────────── */
class LoginPage extends StatefulWidget {
  const LoginPage({super.key}); // hint addressed with super.key

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

  /* Simple loading flag */
  bool _isLoading = false;

/* ─────────────── Login logic ─────────────── */
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      logger.w('Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      /* 0️⃣  Tear down any anonymous session */
      if (_auth.currentUser?.isAnonymous == true) {
        await _auth.signOut();
        logger.i('Anonymous user signed-out');
      }

      /* 1️⃣  Network call – sign-in */
      logger.i('Logging-in: ${_emailController.text.trim()}');
      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = cred.user;
      if (user == null) throw Exception('Null user returned from Firebase');

      /* 2️⃣  Verify e-mail status; reload only if needed */
      if (!user.emailVerified) {
        await user.reload();
        if (!user.emailVerified) {
          logger.w('E-mail not verified – redirecting');
          if (!mounted) return;
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
          );
          return; // ← keeps return-type void
        }
      }

      /* 3️⃣  Obtain fresh ID token */
      final String? idToken = await user.getIdToken();
      logger.i('ID token obtained');

      /* 4️⃣  Local storage – run in background so UI is not blocked */
      if (idToken != null) {
        unawaited(secureStorage.writeData(
            'auth_token', idToken)); // idToken is non-null inside
      }
      unawaited(_clearCachedRole());

      /* 5️⃣  Navigate to app proper */
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleRedirect()),
        (route) => false,
      );
    } catch (e, s) {
      logger.e('Login failed', error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* Helper: clear cached role */
  Future<void> _clearCachedRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
    logger.i('Cached role cleared');
  }

/* ─────────────── UI ─────────────── */
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
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          /* E-mail */
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Please enter your email'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          /* Password */
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Please enter your password'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          /* Login button or loader */
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
                          /* Forgot password */
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
