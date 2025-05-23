import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trainer_home_page.dart';
import 'forgot_password_page.dart';
import 'email_verification_page.dart';
import 'customer_profile_page.dart';
import 'secure_storage_service.dart';

import 'package:logger/logger.dart';

// ───────────────────────────────────────────────────── logger
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

// ───────────────────────────────────────────────────── widget
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  final SecureStorageService secureStorage = SecureStorageService();

  /* ───────────────────────────────────────── login logic */
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      logger.w("Form validation failed");
      return;
    }

    // Sign-out an anonymous session if present
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      await _auth.signOut();
      logger.i("Anonymous user signed out before verified sign-in.");
    }

    try {
      logger.i("Attempting login with email: ${_emailController.text.trim()}");
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = cred.user;
      logger.i("Current user after sign-in: ${_auth.currentUser}");

      if (user == null) return;

      /* ───────── email verification */
      await user.reload();
      if (!user.emailVerified) {
        logger.w("Email not verified. Redirecting to verification page…");
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
        );
        return;
      }

      /* ───────── store ID token securely */
      final idToken = await user.getIdToken();
      await secureStorage.writeData('auth_token', idToken!);
      logger.i("ID Token stored securely.");

      /* ───────── get role from Firestore */
      logger.i("Fetching user role from Firestore…");
      final snap = await _fs.collection('users').doc(user.uid).get();

      if (!snap.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User document not found.")),
        );
        return;
      }

      final String role =
          snap['role'].toString().trim().toLowerCase(); // ← trimmed + lower

      /* ───────── cache role (wipe stale first) */
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userRole'); // ← clear old value
      await prefs.setString('userRole', role); // write fresh one
      logger.i("Processed role: $role");

      /* ───────── pick next page (unchanged) */
      Widget nextPage = const LoginPage(); // fallback
      if (role == 'customer') {
        nextPage = const CustomerProfilePage();
      } else if (role == 'trainer' || role == 'personal trainer') {
        nextPage = const TrainerHomePage();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid role. Contact support.")),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextPage),
      );
    } catch (e) {
      logger.e("Login failed: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    }
  }

  /* ───────────────────────────────────────── UI */
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
                    Image.asset("assets/Fitly2.png", height: 120),
                    const SizedBox(height: 24),
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
                                ? 'Please enter your email'
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
                                ? 'Please enter your password'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage()),
                              );
                            },
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
