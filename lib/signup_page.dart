// lib/signup_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'legal_agreement_page.dart';
import 'email_verification_page.dart';
import 'secure_storage_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  SignupPageState createState() => SignupPageState();
}

class SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  // ─── controllers ────────────────────────────────────────────────
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String _selectedRole = 'customer';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _agreedToTnC = false;

  // secure storage
  final SecureStorageService secureStorage = SecureStorageService();

  // ─── helpers ─────────────────────────────────────────────────────
  String capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void _toggleAgreed(bool? newValue) =>
      setState(() => _agreedToTnC = newValue ?? false);

  // ─── main submit ─────────────────────────────────────────────────
  Future<void> _submitForm() async {
    if (!mounted) return;

    if (_formKey.currentState!.validate()) {
      // 1️⃣ age-check (18+)
      final DateTime? dob = DateTime.tryParse(_dobController.text.trim());
      if (dob == null || DateTime.now().difference(dob).inDays < 365 * 18) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must be at least 18 years old to sign up.'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      if (!_agreedToTnC) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must agree to the Terms & Conditions'),
          backgroundColor: Color(0xFFFFA726),
        ));
        return;
      }

      setState(() => _isLoading = true);

      try {
        // 🚩 NEW: if the current user is a guest, sign out before creating account
        final current = _auth.currentUser;
        if (current != null && current.isAnonymous) {
          await _auth.signOut();
        }

        // 2️⃣ create user
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 3️⃣ send verification email
        await cred.user?.sendEmailVerification();

        // 4️⃣ store ID token (optional)
        if (cred.user != null) {
          final idToken = await cred.user!.getIdToken();
          await secureStorage.writeData('auth_token', idToken!);
        }

        // 5️⃣ save Firestore profile
        final String first = capitalize(_firstNameController.text.trim());
        final String last = capitalize(_lastNameController.text.trim());
        final String display = "$first $last";

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'firstName': first,
          'firstName_lowerCase': first.toLowerCase(),
          'lastName': last,
          'lastName_lowerCase': last.toLowerCase(),
          'displayName': display,
          'displayName_lowerCase': display.toLowerCase(),
          'dob': _dobController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': _selectedRole,
          'emailVerified': false,
          'hasAgreedToTnC': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 6️⃣ cache role locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await prefs.setString('userRole', _selectedRole.toLowerCase());

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              '✅ Signup complete! Check your inbox (and junk folder) for the verification email.'),
          backgroundColor: Color(0xFFFFA726),
        ));

        // 7️⃣ go to verification page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Signup Failed: $e'),
          backgroundColor: Colors.red,
        ));
      }

      setState(() => _isLoading = false);
    }
  }

  // ─── date picker ────────────────────────────────────────────────
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dobController.text = picked.toIso8601String().split('T')[0]);
    }
  }

  // ─── dispose ────────────────────────────────────────────────────
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ─── UI / build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFA726),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text('Create your account',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    const SizedBox(height: 20),

                    // First name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Last name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Info line
                    const Text(
                      "We ask for your birthdate to verify you're 18+, as required by our community guidelines.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),

                    // DOB
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth (18+ age verification)',
                        hintText: 'e.g. 2000-01-01',
                        helperText: 'We use this to confirm you are over 18',
                        border: OutlineInputBorder(),
                      ),
                      onTap: () => _selectDate(context),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        final regex = RegExp(
                            r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}");
                        return regex.hasMatch(v) ? null : 'Invalid email';
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone (optional)
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        } else if (v.trim().length < 6) {
                          return 'Min 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        } else if (v.trim() != _passwordController.text.trim()) {
                          return 'Passwords don\'t match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Role dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Sign up as',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'customer', child: Text('Customer')),
                        DropdownMenuItem(
                            value: 'trainer',
                            child: Text('Personal Trainer')),
                      ],
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                    const SizedBox(height: 16),

                    // Terms and conditions
                    Row(
                      children: [
                        Checkbox(value: _agreedToTnC, onChanged: _toggleAgreed),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LegalAgreementPage()),
                            ),
                            child: const Text(
                              'I agree to the Terms & Conditions',
                              style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.blue),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sign up button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : const Text('Sign Up',
                                style: TextStyle(color: Colors.white)),
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