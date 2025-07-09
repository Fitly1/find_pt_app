// lib/ui/social_signin_buttons.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.loading,
    required this.onGooglePressed,
    required this.onApplePressed,
  });

  final bool loading;
  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─────────── Google ───────────
        ElevatedButton(
          onPressed:
              (loading || onGooglePressed == null) ? null : onGooglePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.grey),
            ),
          ),
          child: loading && onGooglePressed != null
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/google_logo.png', height: 24),
                    const SizedBox(width: 12),
                    const Text('Continue with Google'),
                  ],
                ),
        ),

        // ─────────── Apple (iOS / macOS) ───────────
        if (Platform.isIOS || Platform.isMacOS) ...[
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              // The official Apple button
              AbsorbPointer(
                absorbing: loading || onApplePressed == null,
                child: SignInWithAppleButton(
                  onPressed: onApplePressed ?? () {},
                  style: SignInWithAppleButtonStyle.black,
                  height: 48,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Loading spinner overlay
              if (loading && onApplePressed != null)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}