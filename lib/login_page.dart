import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'trainer_home_page.dart';
import 'forgot_password_page.dart';
import 'email_verification_page.dart'; // For email verification
import 'customer_profile_page.dart'; // Customer Profile Page
import 'package:logger/logger.dart';
import 'secure_storage_service.dart';

// Create a logger instance
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create an instance of SecureStorageService (singleton)
  final SecureStorageService secureStorage = SecureStorageService();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      logger.w("Form validation failed");
      return;
    }

    // Force complete sign-out if current user is anonymous.
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      await _auth.signOut();
      logger.i("Anonymous user signed out before verified sign-in.");
    }

    try {
      logger.i("Attempting login with email: ${_emailController.text.trim()}");
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      logger.i("Current user after sign-in: ${_auth.currentUser}");
      logger.i("Is current user anonymous? ${_auth.currentUser?.isAnonymous}");

      if (user != null) {
        logger.i("Login successful. Checking email verification...");
        await user.reload();
        if (!user.emailVerified) {
          logger.w("Email not verified. Redirecting to verification page...");
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const EmailVerificationPage(),
            ),
          );
          return;
        }

        // Retrieve and store the ID token securely (with non-null assertion)
        final String idToken = (await user.getIdToken())!;
        await secureStorage.writeData('auth_token', idToken);
        logger.i("ID Token stored securely.");

        logger.i("Email is verified. Fetching user role...");
        DocumentSnapshot userDoc =
            await _firestore.collection("users").doc(user.uid).get();

        if (userDoc.exists) {
          // Force the role value to a non-nullable String:
          final String role = userDoc["role"]!.toString().toLowerCase();

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("userRole", role);

          logger.i("Processed role: $role");

          Widget nextPage = const LoginPage(); // Default fallback
          if (role == "customer") {
            logger.i("Navigating to Customer Profile Page...");
            nextPage = const CustomerProfilePage();
          } else if (role == "personal trainer" || role == "trainer") {
            logger.i("Navigating to Trainer Home Page...");
            nextPage = const TrainerHomePage();
          } else {
            logger.e("Invalid role detected.");
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invalid role. Contact support.")),
            );
            return;
          }

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => nextPage),
          );
        } else {
          logger.e("User document not found in Firestore.");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("User document not found. Contact support."),
            ),
          );
        }
      }
    } catch (e) {
      logger.e("Login failed: ${e.toString()}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Full-screen gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(255, 167, 38, 1), // Orange
              Color(0xFFFB8C00), // Darker orange
            ],
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
                    // Logo
                    Image.asset(
                      "assets/Fitly2.png",
                      height: 120,
                    ),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          // Login Button
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
                              child: const Text(
                                'Login',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Forgot Password Button
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordPage(),
                                ),
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
      // Optionally, you can add an AppBar or remove it if the design calls for full-screen login.
    );
  }
}
