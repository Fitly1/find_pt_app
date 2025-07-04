// lib/signup_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/auth_service.dart';
import 'email_verification_page.dart';
import 'legal_agreement_page.dart';
import 'role_redirect.dart';
import 'secure_storage_service.dart';
import 'ui/social_signin_buttons.dart';

/* ───────── friendly helper to mask Firebase error codes ───────── */
String prettyAuthError(dynamic error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'That e-mail address is already in use.';
      case 'invalid-email':
        return 'Please enter a valid e-mail address.';
      case 'weak-password':
        return 'Your password is too weak.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect e-mail or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account exists for that e-mail address.';
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

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  SignupPageState createState() => SignupPageState();
}

class SignupPageState extends State<SignupPage> {
  // ───────────────────────── Configuration ─────────────────────────
  final Color _brandColor = const Color(0xFFFFA726);

  // ───────────────────────── controllers ───────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ───────────────────────── misc state ────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecureStorageService secureStorage = SecureStorageService();

  String _selectedRole = 'customer';
  bool _isLoading = false;
  bool _agreedToTnC = false;

  // ───────────────────────── helpers ───────────────────────────────
  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void _setLoading(bool v) => setState(() => _isLoading = v);
  void _toggleAgreed(bool? v) => setState(() => _agreedToTnC = v ?? false);

  // ───────────────── prettier conflict dialog ─────────────────────
  Future<void> _showRoleConflictDialog({
    required String existingRole,
    required String email,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
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
                backgroundColor: _brandColor,
                child: const Icon(Icons.info_outline_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 22),
              const Text('Account already exists',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Text(
                'The e-mail address\n$email\nis already registered as a '
                '$existingRole. To create a separate $_selectedRole account, '
                'please choose a different e-mail address.',
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Choose another e-mail',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await FirebaseAuth.instance.signOut();
  }

  // ───────────────── social sign-in handler ───────────────────────
  Future<void> _handleSocialSignIn(
      Future<UserCredential?> Function() method) async {
    if (_isLoading) return;
    _setLoading(true);

    try {
      final cred = await method();
      if (cred == null) throw Exception('Sign-in aborted');

      final docRef =
          FirebaseFirestore.instance.collection('users').doc(cred.user!.uid);
      final doc = await docRef.get();

      // conflict?
      if (doc.exists) {
        final existingRole =
            (doc.data()!['role'] ?? '').toString().toLowerCase();
        if (existingRole != _selectedRole.toLowerCase()) {
          await _showRoleConflictDialog(
              existingRole: existingRole, email: cred.user!.email ?? '');
          _setLoading(false);
          return;
        }
      }

      // create profile if first time
      if (!doc.exists) {
        final display = cred.user!.displayName ?? '';
        final parts = display.split(' ');
        final first = _cap(parts.isNotEmpty ? parts.first : '');
        final last = _cap(parts.length > 1 ? parts.sublist(1).join(' ') : '');

        await docRef.set({
          'firstName': first,
          'firstName_lowerCase': first.toLowerCase(),
          'lastName': last,
          'lastName_lowerCase': last.toLowerCase(),
          'displayName': display,
          'displayName_lowerCase': display.toLowerCase(),
          'dob': '',
          'email': cred.user!.email ?? '',
          'phone': cred.user!.phoneNumber ?? '',
          'role': _selectedRole,
          'emailVerified': cred.user!.emailVerified,
          'hasAgreedToTnC': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // cache role
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', _selectedRole.toLowerCase());

      // decide destination
      final verified = cred.user?.emailVerified ?? false;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => verified
                ? const RoleRedirect()
                : const EmailVerificationPage()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text('❌ ${prettyAuthError(e)}'),
        ));
      }
    }

    _setLoading(false);
  }

  // ───────────────── email/password sign-up ───────────────────────
  Future<void> _submitForm() async {
    if (!mounted || _isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    // age check
    final dob = DateTime.tryParse(_dobController.text.trim());
    if (dob == null || DateTime.now().difference(dob).inDays < 365 * 18) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.red,
        content: Text('You must be at least 18 years old to sign up.'),
      ));
      return;
    }

    if (!_agreedToTnC) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _brandColor,
        content: const Text('You must agree to the Terms & Conditions'),
      ));
      return;
    }

    _setLoading(true);
    try {
      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) await _auth.signOut();

      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await cred.user?.sendEmailVerification();

      // optional token
      if (cred.user != null) {
        final token = await cred.user!.getIdToken();
        await secureStorage.writeData('auth_token', token!);
      }

      final first = _cap(_firstNameController.text.trim());
      final last = _cap(_lastNameController.text.trim());
      final display = '$first $last';

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

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setString('userRole', _selectedRole.toLowerCase());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _brandColor,
        content: const Text(
            '✅ Signup complete! Check your inbox for the verification e-mail.'),
      ));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text('❌ ${prettyAuthError(e)}'),
        ));
      }
    }
    _setLoading(false);
  }

  // ───────────────── date picker ──────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(
          () => _dobController.text = picked.toIso8601String().split('T')[0]);
    }
  }

  // ───────────────── lifecycle ────────────────────────────────────
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

  // ───────────────── UI ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dividerGrey = Colors.grey.shade400;

    Widget orDivider() => Row(
          children: [
            Expanded(child: Divider(color: dividerGrey, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('OR',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: dividerGrey,
                      fontSize: 12)),
            ),
            Expanded(child: Divider(color: dividerGrey, thickness: 1)),
          ],
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _brandColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
          child: Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Title ─────────────────────────────────────
                    const Text('Create your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    const SizedBox(height: 24),

                    // ─── Social sign-in buttons (now at the top) ───
                    SocialSignInButtons(
                      loading: _isLoading,
                      onGooglePressed: () =>
                          _handleSocialSignIn(AuthService.googleOneTap),
                      onApplePressed: () =>
                          _handleSocialSignIn(AuthService.appleOneTap),
                    ),
                    const SizedBox(height: 18),
                    orDivider(),
                    const SizedBox(height: 20),

                    // ─── Email signup form ────────────────────────
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Date of birth',
                        helperText: 'You must be 18+',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final r = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                        return r.hasMatch(v) ? null : 'Invalid e-mail';
                      },
                    ),
                    const SizedBox(height: 16),

                    // Optional phone field (still kept, shorter page if you delete)
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.trim().length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.trim() != _passwordController.text.trim()) {
                          return 'Passwords don’t match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

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
                            value: 'trainer', child: Text('Personal trainer')),
                      ],
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                    const SizedBox(height: 16),

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

                    // ─── Submit button ─────────────────────────────
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
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white)))
                            : const Text('Sign up',
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
