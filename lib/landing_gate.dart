// lib/landing_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'splashpage.dart';
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
    _decide();
  }

  Future<void> _decide() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRunBefore = prefs.getBool('hasRunBefore') ?? false;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && !user.isAnonymous) {
      setState(() => _next = const RoleRedirect());
      return;
    }

    if (!hasRunBefore) {
      await prefs.setBool('hasRunBefore', true);
      setState(() => _next = const SplashPage());
    } else {
      setState(() => _next = const MarketplacePage(guestMode: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    if (next == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return next;
  }
}
