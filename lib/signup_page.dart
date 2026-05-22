// lib/signup_page.dart
// ─────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/auth_service.dart';
import 'email_verification_page.dart';
import 'legal_agreement_page.dart';
import 'role_redirect.dart';
import 'ui/social_signin_buttons.dart';

/* ───────── Firebase-error → friendly copy ───────── */
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
      case 'apple-signin-unsupported':
        return 'Apple Sign-In is only available on iOS.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  return 'Something went wrong. Please try again.';
}

/* ───────────────────────────────────────────────────────────── */
class SignupPage extends StatefulWidget {
  final String? role;
  final String? preselectedRole;

  const SignupPage({
    super.key,
    this.role,
    this.preselectedRole,
  }) : assert(
          role == null || preselectedRole == null,
          'Pass only role OR preselectedRole, not both.',
        );

  @override
  SignupPageState createState() => SignupPageState();
}

class SignupPageState extends State<SignupPage> {
  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _card = Color(0xFF111318);
  static const Color _raised = Color(0xFF20242C);
  static const Color _raisedSoft = Color(0xFF171B22);
  static const Color _border = Color(0xFF303540);
  static const Color _borderStrong = Color(0xFF343A46);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _goldDeep = Color(0xFFC98E2B);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);
  static const Color _textSoft = Color(0xFF7E8794);
  static const Color _error = Color(0xFFE57373);

  static const String _termsVersion = '2026-05-21';

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String? _selectedRole;
  late bool _hideRoleDropdown;

  bool _isLoading = false;
  bool _agreedToTnC = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _hasRole =>
      _selectedRole == 'customer' || _selectedRole == 'trainer';

  bool get _socialEnabled => _hasRole && _agreedToTnC && !_isLoading;

  String get _socialHint {
    if (!_hasRole) return 'Choose Customer or Personal trainer first.';
    if (!_agreedToTnC) return 'Agree to the Terms before continuing.';
    return '';
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() => _isLoading = value);
  }

  void _toggleAgreed(bool? value) {
    setState(() => _agreedToTnC = value ?? false);
  }

  String _cap(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  List<String?> _splitDisplayName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return [null, null];
    }

    final parts = displayName.trim().split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return [parts.first, null];
    }

    return [
      parts.first,
      parts.sublist(1).join(' '),
    ];
  }

  String? _normaliseRole(String? value) {
    if (value == null) return null;
    final role = value.trim().toLowerCase();

    if (role == 'trainer' || role == 'personal trainer') return 'trainer';
    if (role == 'customer') return 'customer';

    return role;
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _raisedSoft,
      labelStyle: const TextStyle(
        color: _textMuted,
        fontWeight: FontWeight.w500,
      ),
      helperStyle: const TextStyle(
        color: _textSoft,
        fontWeight: FontWeight.w500,
      ),
      errorStyle: const TextStyle(
        color: _error,
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _gold, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _error, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedRole = _normaliseRole(widget.role ?? widget.preselectedRole);
    _hideRoleDropdown = _selectedRole != null;
  }

  Future<void> _markTermsAccepted(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'hasAgreedToTnC': true,
      'hasAgreedToTnc': true,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'termsVersion': _termsVersion,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureRoleProfile({
    required User user,
    String? firstName,
    String? lastName,
    String? dob,
    String? phone,
  }) async {
    final role = _selectedRole?.toLowerCase();

    if (role == 'trainer') {
      await _ensureTrainerProfile(user.uid);
      return;
    }

    if (role == 'customer') {
      await _ensureCustomerProfile(
        user: user,
        firstName: firstName,
        lastName: lastName,
        dob: dob,
        phone: phone,
      );
    }
  }

  Future<void> _ensureTrainerProfile(String uid) async {
    final ref =
        FirebaseFirestore.instance.collection('trainer_profiles').doc(uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'isActive': true,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final data = snap.data() ?? <String, dynamic>{};
    final patch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!data.containsKey('isActive')) {
      patch['isActive'] = true;
    }

    if (!data.containsKey('completed')) {
      patch['completed'] = false;
    }

    await ref.set(patch, SetOptions(merge: true));
  }

  Future<void> _ensureCustomerProfile({
    required User user,
    String? firstName,
    String? lastName,
    String? dob,
    String? phone,
  }) async {
    final uid = user.uid;
    final ref =
        FirebaseFirestore.instance.collection('customer_profiles').doc(uid);
    final snap = await ref.get();

    final fallbackNames = _splitDisplayName(user.displayName);

    final first = (firstName ?? fallbackNames[0] ?? '').trim();
    final last = (lastName ?? fallbackNames[1] ?? '').trim();
    final typedDisplay = '$first $last'.trim();
    final authDisplay = (user.displayName ?? '').trim();
    final displayName = typedDisplay.isNotEmpty ? typedDisplay : authDisplay;

    if (!snap.exists) {
      await ref.set({
        'role': 'customer',
        'email': user.email ?? _emailController.text.trim(),
        'firstName': first,
        'firstName_lowerCase': first.toLowerCase(),
        'lastName': last,
        'lastName_lowerCase': last.toLowerCase(),
        'displayName': displayName,
        'displayName_lowerCase': displayName.toLowerCase(),
        'dob': dob ?? '',
        'phone': phone ?? '',
        'photoURL': user.photoURL ?? '',
        'profileCompleted': false,
        'quizCompleted': false,
        'fitnessIdentity': '',
        'fitnessIdentityKey': '',
        'badgeAsset': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final data = snap.data() ?? <String, dynamic>{};
    final patch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'role': 'customer',
    };

    if (!data.containsKey('email') || '${data['email']}'.trim().isEmpty) {
      patch['email'] = user.email ?? _emailController.text.trim();
    }

    if (!data.containsKey('displayName') ||
        '${data['displayName']}'.trim().isEmpty) {
      patch['displayName'] = displayName;
      patch['displayName_lowerCase'] = displayName.toLowerCase();
    }

    if (!data.containsKey('firstName') ||
        '${data['firstName']}'.trim().isEmpty) {
      patch['firstName'] = first;
      patch['firstName_lowerCase'] = first.toLowerCase();
    }

    if (!data.containsKey('lastName') || '${data['lastName']}'.trim().isEmpty) {
      patch['lastName'] = last;
      patch['lastName_lowerCase'] = last.toLowerCase();
    }

    if (!data.containsKey('dob')) {
      patch['dob'] = dob ?? '';
    }

    if (!data.containsKey('phone')) {
      patch['phone'] = phone ?? '';
    }

    if (!data.containsKey('photoURL')) {
      patch['photoURL'] = user.photoURL ?? '';
    }

    if (!data.containsKey('profileCompleted')) {
      patch['profileCompleted'] = false;
    }

    if (!data.containsKey('quizCompleted')) {
      patch['quizCompleted'] = false;
    }

    if (!data.containsKey('fitnessIdentity')) {
      patch['fitnessIdentity'] = '';
    }

    if (!data.containsKey('fitnessIdentityKey')) {
      patch['fitnessIdentityKey'] = '';
    }

    if (!data.containsKey('badgeAsset')) {
      patch['badgeAsset'] = '';
    }

    await ref.set(patch, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> _loadUserDocData(String uid) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    return snap.data() ?? <String, dynamic>{};
  }

  Future<void> _handleSocialSignIn(
    Future<UserCredential?> Function() method,
  ) async {
    if (!_hasRole) {
      _showSnack(
        'Please choose Customer or Trainer first.',
        backgroundColor: _goldDeep,
      );
      return;
    }

    if (!_agreedToTnC) {
      _showSnack(
        'You must agree to the Terms & Conditions.',
        backgroundColor: _goldDeep,
      );
      return;
    }

    if (_isLoading) return;
    _setLoading(true);

    try {
      final cred = await method();
      if (cred == null) throw Exception('cancelled');

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user returned from sign-in.',
        );
      }

      await _markTermsAccepted(user.uid);

      final userData = await _loadUserDocData(user.uid);
      final fallbackNames = _splitDisplayName(user.displayName);

      final firstName = _clean(userData['firstName']).isNotEmpty
          ? _clean(userData['firstName'])
          : fallbackNames[0];

      final lastName = _clean(userData['lastName']).isNotEmpty
          ? _clean(userData['lastName'])
          : fallbackNames[1];

      await _ensureRoleProfile(
        user: user,
        firstName: firstName,
        lastName: lastName,
        dob: _clean(userData['dob']),
        phone: _clean(userData['phone']),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', _selectedRole!.toLowerCase());

      final isSocial = user.providerData.any(
        (provider) =>
            provider.providerId == 'apple.com' ||
            provider.providerId == 'google.com',
      );
      final needVerify = !isSocial && !(user.emailVerified);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              needVerify ? const EmailVerificationPage() : const RoleRedirect(),
        ),
      );
    } catch (e) {
      _showSnack(
        '❌ ${prettyAuthError(e)}',
        backgroundColor: _error,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _submitForm() async {
    if (!mounted || _isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_hasRole) {
      _showSnack(
        'Please choose Customer or Trainer first.',
        backgroundColor: _goldDeep,
      );
      return;
    }

    final dob = DateTime.tryParse(_dobController.text.trim());
    if (dob == null || DateTime.now().difference(dob).inDays < 365 * 18) {
      _showSnack(
        'You must be at least 18 years old to sign up.',
        backgroundColor: _error,
      );
      return;
    }

    if (!_agreedToTnC) {
      _showSnack(
        'You must agree to the Terms & Conditions.',
        backgroundColor: _goldDeep,
      );
      return;
    }

    _setLoading(true);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user returned after signup.',
        );
      }

      await user.sendEmailVerification();

      final first = _cap(_firstNameController.text.trim());
      final last = _cap(_lastNameController.text.trim());
      final display = '$first $last'.trim();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
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
        'hasAgreedToTnc': true,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': _termsVersion,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _ensureRoleProfile(
        user: user,
        firstName: first,
        lastName: last,
        dob: _dobController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', _selectedRole!.toLowerCase());

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
      );
    } catch (e) {
      _showSnack(
        '❌ ${prettyAuthError(e)}',
        backgroundColor: _error,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _gold,
              onPrimary: Color(0xFF121212),
              surface: _card,
              onSurface: _textMain,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _gold,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = picked.toIso8601String().split('T')[0];
      });
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
            'Sign Up',
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
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              const _SignupBackground(),
              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 16),
                        _buildSignupCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final roleText = _selectedRole == 'trainer'
        ? 'Personal trainer'
        : _selectedRole == 'customer'
            ? 'Customer'
            : 'Choose your role';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_gold, _goldDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFF121212),
              size: 31,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Create your account',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMain,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hideRoleDropdown
                ? 'Signing up as $roleText'
                : 'Start with the right account type.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_hideRoleDropdown) ...[
            const Text(
              'Account type',
              style: TextStyle(
                color: _textMain,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              dropdownColor: _card,
              style: const TextStyle(
                color: _textMain,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
              iconEnabledColor: _gold,
              decoration: _inputDecoration('I want to sign up as'),
              items: const [
                DropdownMenuItem(
                  value: 'customer',
                  child: Text('Customer'),
                ),
                DropdownMenuItem(
                  value: 'trainer',
                  child: Text('Personal trainer'),
                ),
              ],
              validator: (value) => value == null ? 'Required' : null,
              onChanged: (value) {
                setState(() => _selectedRole = _normaliseRole(value));
              },
            ),
            const SizedBox(height: 14),
          ],
          _buildTermsRow(),
          const SizedBox(height: 16),
          SocialSignInButtons(
            loading: _isLoading,
            onGooglePressed: _socialEnabled
                ? () => _handleSocialSignIn(
                      () => AuthService.googleOneTap(
                        role: _selectedRole,
                        createUserDocument: true,
                      ),
                    )
                : null,
            onApplePressed: _socialEnabled
                ? () => _handleSocialSignIn(
                      () => AuthService.appleOneTap(
                        role: _selectedRole,
                        createUserDocument: true,
                      ),
                    )
                : null,
          ),
          if (!_socialEnabled && _socialHint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _socialHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 18),
          const _OrDivider(),
          const SizedBox(height: 18),
          TextFormField(
            controller: _firstNameController,
            style:
                const TextStyle(color: _textMain, fontWeight: FontWeight.w600),
            cursorColor: _gold,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('First name'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _lastNameController,
            style:
                const TextStyle(color: _textMain, fontWeight: FontWeight.w600),
            cursorColor: _gold,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('Last name'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dobController,
            readOnly: true,
            onTap: _pickDate,
            style:
                const TextStyle(color: _textMain, fontWeight: FontWeight.w600),
            cursorColor: _gold,
            decoration: _inputDecoration(
              'Date of birth',
              helperText: 'You must be 18+',
              suffixIcon: const Icon(
                Icons.calendar_today_rounded,
                color: _textMuted,
                size: 20,
              ),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style:
                const TextStyle(color: _textMain, fontWeight: FontWeight.w600),
            cursorColor: _gold,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('E-mail'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
              final regex = RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              );
              return regex.hasMatch(value.trim()) ? null : 'Invalid e-mail';
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style:
                const TextStyle(color: _textMain, fontWeight: FontWeight.w600),
            cursorColor: _gold,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('Phone optional'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style:
                const TextStyle(color: _textMain, fontWeight: FontWeight.w600),
            cursorColor: _gold,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              'Password',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _textMuted,
                  size: 21,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
              if (value.trim().length < 6) return 'Min 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style:
                const TextStyle(color: _textMain, fontWeight: FontWeight.w600),
            cursorColor: _gold,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              'Confirm password',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _textMuted,
                  size: 21,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
              if (value.trim() != _passwordController.text.trim()) {
                return 'Passwords don’t match';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildTermsRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
      decoration: BoxDecoration(
        color: _raisedSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _agreedToTnC,
            onChanged: _toggleAgreed,
            activeColor: _gold,
            checkColor: const Color(0xFF121212),
            side: const BorderSide(color: _textMuted, width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalAgreementPage(),
                  ),
                );
              },
              child: const Text(
                'I agree to the Terms & Conditions',
                style: TextStyle(
                  color: _gold,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _gold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gold, _goldDeep],
                ),
          color: _isLoading ? _borderStrong : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (!_isLoading)
              BoxShadow(
                color: _gold.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF121212),
            disabledForegroundColor: _textMuted,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 21,
                  width: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    valueColor: AlwaysStoppedAnimation<Color>(_textMain),
                  ),
                )
              : const Text(
                  'Create account',
                  style: TextStyle(
                    color: Color(0xFF121212),
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  static const Color _border = Color(0xFF303540);
  static const Color _textSoft = Color(0xFF7E8794);

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: _border, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'OR',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _textSoft,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: Divider(color: _border, thickness: 1)),
      ],
    );
  }
}

class _SignupBackground extends StatelessWidget {
  const _SignupBackground();

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
          top: -150,
          right: -120,
          child: Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.12),
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
