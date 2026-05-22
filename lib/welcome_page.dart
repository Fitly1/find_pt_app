import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'signup_page.dart';
import 'marketplace_page.dart';
import 'login_page.dart';

/// CTA / welcome screen (not the visual splash)
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const Color _bgTop = Color(0xFF07080A);
  static const Color _bgBottom = Color(0xFF0B0D10);
  static const Color _card = Color(0xFF111318);
  static const Color _raised = Color(0xFF20242C);
  static const Color _border = Color(0xFF303540);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

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
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(
                child: _BackgroundGlow(),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeroCard(context),
                          const SizedBox(height: 24),
                          _buildActionCard(context),
                          const SizedBox(height: 18),
                          _buildLoginButton(context),
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

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 154,
            width: 154,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _raised,
              border: Border.all(
                color: _gold.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.16),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Image.asset(
              'assets/Fitly2.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Welcome to Fitly',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMain,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Find the right personal trainer without the guesswork.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _PrimaryFitlyButton(
            text: 'I’m a Trainer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SignupPage(
                    preselectedRole: 'trainer',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SecondaryFitlyButton(
            text: 'I’m Looking for a Trainer',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MarketplacePage(
                    guestMode: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: _textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _textMuted,
          ),
          children: [
            TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Log in',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryFitlyButton extends StatelessWidget {
  const _PrimaryFitlyButton({
    required this.text,
    required this.onPressed,
  });

  final String text;
  final VoidCallback onPressed;

  static const Color _gold = Color(0xFFE7B95C);
  static const Color _goldDeep = Color(0xFFC98E2B);
  static const Color _buttonText = Color(0xFF121212);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gold, _goldDeep],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.22),
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
            foregroundColor: _buttonText,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
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
  });

  final String text;
  final VoidCallback onPressed;

  static const Color _raised = Color(0xFF20242C);
  static const Color _border = Color(0xFF343A46);
  static const Color _textMain = Color(0xFFF5F6F8);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _raised,
          foregroundColor: _textMain,
          side: BorderSide(
            color: _border.withValues(alpha: 0.95),
            width: 1.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
            color: _textMain,
          ),
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

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
          top: -130,
          right: -110,
          child: Container(
            height: 280,
            width: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.13),
            ),
          ),
        ),
        Positioned(
          bottom: -160,
          left: -130,
          child: Container(
            height: 320,
            width: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.08),
            ),
          ),
        ),
      ],
    );
  }
}
