// lib/landing_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'marketplace_page.dart';
import 'role_redirect.dart';

class LandingGate extends StatefulWidget {
  const LandingGate({super.key});
  @override
  State<LandingGate> createState() => _LandingGateState();
}

class _LandingGateState extends State<LandingGate> {
  Widget? _next;

  @override
  void initState() {
    super.initState();
    // Show a visual-only splash immediately while we decide
    _next = const _VisualSplash();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;
    if (user != null && !user.isAnonymous) {
      setState(() => _next = const RoleRedirect());
    } else {
      // GUEST MODE → Marketplace
      setState(() => _next = const MarketplacePage(guestMode: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _next ??
        const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Minimal visual splash (brand color + logo). No navigation here.
class _VisualSplash extends StatelessWidget {
  const _VisualSplash();

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFFFA726);
    return Scaffold(
      backgroundColor: brandOrange,
      body: Center(
        child: Image.asset('assets/Fitly2.png', width: 160),
      ),
    );
  }
}
