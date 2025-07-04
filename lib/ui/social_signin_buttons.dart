import 'dart:io' show Platform;

import 'package:flutter/material.dart';

class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.loading,
    required this.onGooglePressed,
    required this.onApplePressed,
  });

  /* Whether a sign-in operation is currently running */
  final bool loading;

  /* Callbacks supplied by the parent widget */
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─────────── Google ───────────
        ElevatedButton(
          onPressed: loading ? null : onGooglePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.grey),
            ),
          ),
          child: loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.black),
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

        // ─────────── Apple (iOS / macOS) ─────
        if (Platform.isIOS || Platform.isMacOS) ...[
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: loading ? null : onApplePressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text('Continue with Apple'),
          ),
        ],
      ],
    );
  }
}
