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

  // Controllers
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

  // Secure storage
  final SecureStorageService secureStorage = SecureStorageService();

  String capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void _toggleAgreed(bool? newValue) =>
      setState(() => _agreedToTnC = newValue ?? false);

  Future<void> _submitForm() async {
    if (!mounted) return;
    if (_formKey.currentState!.validate()) {
      if (!_agreedToTnC) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must agree to the Terms & Conditions'),
            backgroundColor: Color(0xFFFFA726),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // 1️⃣ Create user
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        User? user = userCredential.user;

        // 2️⃣ Send verification email
        await user?.sendEmailVerification();

        // 3️⃣ Securely store ID token
        if (user != null) {
          final String idToken = (await user.getIdToken())!;
          await secureStorage.writeData('auth_token', idToken);
        }

        // 4️⃣ Prepare & save profile
        final String formattedFirstName =
            capitalize(_firstNameController.text.trim());
        final String formattedLastName =
            capitalize(_lastNameController.text.trim());
        final String displayName = "$formattedFirstName $formattedLastName";

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .set({
          'firstName': formattedFirstName,
          'firstName_lowerCase': formattedFirstName.toLowerCase(),
          'lastName': formattedLastName,
          'lastName_lowerCase': formattedLastName.toLowerCase(),
          'displayName': displayName,
          'displayName_lowerCase': displayName.toLowerCase(),
          'dob': _dobController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': _selectedRole,
          'emailVerified': false,
          'hasAgreedToTnC': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        // 5️⃣ Success UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "✅ Signup complete! Check your inbox (and junk folder) for the verification email.",
            ),
            backgroundColor: Color(0xFFFFA726),
          ),
        );

        // 6️⃣ Clear old SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (!mounted) return; // ⬅️ NEW GUARD

        // 7️⃣ Navigate to verification
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Signup Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(
          () => _dobController.text = "${pickedDate.toLocal()}".split(' ')[0]);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign Up',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFA726),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
          child: Card(
            elevation: 3,
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'Create your account',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    const SizedBox(height: 20),

                    // First Name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your first name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your last name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // DOB
                    TextFormField(
                      controller: _dobController,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please select your date of birth'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        final regex = RegExp(
                            r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}");
                        return regex.hasMatch(v) ? null : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter a password';
                        } else if (v.trim().length < 6) {
                          return 'Password must be at least 6 characters long';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please confirm your password';
                        } else if (v.trim() !=
                            _passwordController.text.trim()) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Role
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Sign up as',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'customer',
                          child: Text('Customer'),
                        ),
                        DropdownMenuItem(
                          value: 'trainer',
                          child: Text('Personal Trainer'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                    const SizedBox(height: 16),

                    // T&C
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTnC,
                          onChanged: _toggleAgreed,
                        ),
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

                    // Sign Up button
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
