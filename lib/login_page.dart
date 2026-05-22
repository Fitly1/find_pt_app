// lib/login_page.dart
import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'email_verification_page.dart';
import 'forgot_password_page.dart';
import 'role_redirect.dart';
import 'secure_storage_service.dart';
import 'services/auth_service.dart';
import 'ui/social_signin_buttons.dart';

final Logger logger = Logger(
  printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5),
);

/* ───────── error helper ───────── */
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
      case 'apple-signin-unsupported':
        return 'Apple Sign-In is only available on iOS.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  return 'Something went wrong. Please try again.';
}

/* ───────────────── widget ───────────────── */
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecureStorageService secureStorage = SecureStorageService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _textMuted, size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _raisedSoft,
      labelStyle: const TextStyle(
        color: _textMuted,
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

  /* ───── styled dialog ───── */
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
      builder: (ctx) {
        return Dialog(
          backgroundColor: _card,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: error
                        ? _error.withValues(alpha: 0.16)
                        : _gold.withValues(alpha: 0.16),
                    border: Border.all(
                      color: error ? _error : _gold,
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    error
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    color: error ? _error : _gold,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 14.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_gold, _goldDeep],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFF121212),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF121212),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /* ───── social sign-in ───── */
  Future<void> _handleSocialSignIn(
    Future<UserCredential?> Function() providerMethod,
  ) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final cred = await providerMethod();
      if (cred == null) throw Exception('cancelled');

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user returned from sign-in.',
        );
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await _showInfoDialog(
          title: 'No account found',
          message: 'This login has no Fitly account yet. Please sign up first.',
          error: true,
        );

        await AuthService.signOut();
        return;
      }

      /* cache role */
      final data = doc.data() ?? {};
      var role = (data['role'] ?? '').toString().toLowerCase().trim();

      if (role == 'personal trainer' || role == 'personaltrainer') {
        role = 'trainer';
      }

      final prefs = await SharedPreferences.getInstance();

      if (role.isNotEmpty) {
        await prefs.setString('userRole', role);
      } else {
        await prefs.remove('userRole');
      }

      /* fresh token */
      final token = await user.getIdToken();
      if (token != null) {
        unawaited(secureStorage.writeData('auth_token', token));
      }

      /* navigation decision */
      final isPassword = user.providerData
          .any((provider) => provider.providerId == 'password');
      final needVerify = isPassword && !user.emailVerified;

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              needVerify ? const EmailVerificationPage() : const RoleRedirect(),
        ),
        (_) => false,
      );
    } catch (e, s) {
      logger.e('Social sign-in failed', error: e, stackTrace: s);

      await _showInfoDialog(
        title: 'Login failed',
        message: prettyAuthError(e),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /* ───── email / password ───── */
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // sign out any anonymous session first
      if (_auth.currentUser?.isAnonymous == true) {
        await _auth.signOut();
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = cred.user!;
      final isPassword =
          user.providerData.any((p) => p.providerId == 'password');

      // email verification for password users
      if (isPassword && !user.emailVerified) {
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

      // save auth token
      final token = await user.getIdToken();
      if (token != null) {
        unawaited(secureStorage.writeData('auth_token', token));
      }

      // read role from Firestore & cache in SharedPreferences
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final prefs = await SharedPreferences.getInstance();

        if (snap.exists) {
          final data = snap.data() ?? {};
          var role = (data['role'] ?? '').toString().toLowerCase().trim();

          if (role == 'personal trainer' || role == 'personaltrainer') {
            role = 'trainer';
          }

          if (role.isNotEmpty) {
            await prefs.setString('userRole', role);
          } else {
            await prefs.remove('userRole');
          }
        } else {
          await prefs.remove('userRole');
        }
      } catch (e) {
        logger.w('Failed to cache userRole after login', error: e);
      }

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

  /* ───── lifecycle ───── */
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /* ───── UI ───── */
  @override
  Widget build(BuildContext context) {
    final showAppleHint = !Platform.isIOS && !Platform.isMacOS;

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
          backgroundColor: _bgTop,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: _textMain),
          title: const Text(
            'Log In',
            style: TextStyle(
              color: _textMain,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: true,
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              const Positioned.fill(child: _LoginBackground()),
              Positioned.fill(
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeaderCard(),
                          const SizedBox(height: 16),
                          _buildLoginCard(showAppleHint: showAppleHint),
                        ],
                      ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
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
            height: 92,
            width: 92,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _raised,
              border: Border.all(
                color: _gold.withValues(alpha: 0.42),
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
            child: Image.asset(
              'assets/Fitly2.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMain,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Log in to continue your Fitly journey.',
            textAlign: TextAlign.center,
            style: TextStyle(
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

  Widget _buildLoginCard({required bool showAppleHint}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  cursorColor: _gold,
                  style: const TextStyle(
                    color: _textMain,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _inputDecoration(
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your email'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  cursorColor: _gold,
                  style: const TextStyle(
                    color: _textMain,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _inputDecoration(
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
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
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your password'
                      : null,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) _login();
                  },
                ),
                const SizedBox(height: 18),
                _buildLoginButton(),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: _gold,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _OrDivider(),
          const SizedBox(height: 16),
          SocialSignInButtons(
            loading: _isLoading,
            onGooglePressed: () => _handleSocialSignIn(
              () => AuthService.googleOneTap(
                createUserDocument: false,
              ),
            ),
            onApplePressed: () => _handleSocialSignIn(
              () => AuthService.appleOneTap(
                createUserDocument: false,
              ),
            ),
          ),
          if (showAppleHint) ...[
            const SizedBox(height: 8),
            const Text(
              'Apple Sign-In available on iOS.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: _textSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
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
          onPressed: _isLoading ? null : _login,
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
                  'Log in',
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

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

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
