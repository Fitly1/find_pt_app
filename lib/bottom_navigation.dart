// lib/bottom_navigation.dart   (trainer bar)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trainer_dashboard_page.dart';
import 'messages_page.dart';
import 'listings_page.dart';
import 'trainer_home_page.dart';
import 'profile_page.dart' as profile;
import 'welcome_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_provider.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _brandColor = Color(0xFFFFA726);
const Color _surface = Color(0xFF111318);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class BottomNavigation extends ConsumerWidget {
  final int currentIndex;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
  });

  /* ───────── helper that waits for FirebaseAuth ───────── */
  Future<bool> _needsSignIn(int tabIndex) async {
    // tabs that require auth / verification
    if (![1, 3, 4].contains(tabIndex)) return false;

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    if (user == null || user.isAnonymous) return true;

    final isPassword = user.providerData.any((p) => p.providerId == 'password');
    if (isPassword && !user.emailVerified) return true;

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? '';

    if (!(role == 'trainer' || role == 'personal trainer')) return true;

    return false;
  }

  /* ───────── navigation ───────── */
  Future<void> _onItemTapped(BuildContext context, int index) async {
    if (index == currentIndex) return;

    if (await _needsSignIn(index)) {
      if (!context.mounted) return;
      await _showAuthDialog(context);
      return;
    }

    if (!context.mounted) return;

    late final Widget nextPage;

    switch (index) {
      case 0:
        nextPage = const TrainerDashboardPage();
        break;
      case 1:
        nextPage = const MessagesPage();
        break;
      case 2:
        nextPage = const ListingsPage();
        break;
      case 3:
        nextPage = const TrainerHomePage(showProfileCompleteMessage: false);
        break;
      case 4:
        nextPage = const profile.ProfilePage();
        break;
      default:
        nextPage = const TrainerDashboardPage();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextPage),
    );
  }

  BottomNavigationBarItem _item({
    required int index,
    required IconData icon,
    required String label,
    bool showDot = false,
  }) {
    return BottomNavigationBarItem(
      icon: _PremiumNavIcon(
        icon: icon,
        selected: currentIndex == index,
        showDot: showDot,
      ),
      label: label,
    );
  }

  Stream<int> _unreadMessagesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return Stream<int>.value(0);
    }

    return FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      var unreadCount = 0;

      for (final doc in snap.docs) {
        final data = doc.data();

        final lastMessage = (data['lastMessage'] ?? '').toString().trim();
        if (lastMessage.isEmpty) continue;

        final deletedFor = (data['deletedFor'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

        if (deletedFor.contains(uid)) continue;

        final unreadBy = (data['unreadBy'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

        if (unreadBy.contains(uid)) {
          unreadCount++;
        }
      }

      return unreadCount;
    });
  }

  /* ───────── UI ───────── */
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notificationProvider);

    return StreamBuilder<int>(
      stream: _unreadMessagesStream(),
      builder: (context, unreadSnap) {
        final hasUnreadMessages = (unreadSnap.data ?? 0) > 0;

        return Container(
          decoration: BoxDecoration(
            color: _surface,
            border: const Border(
              top: BorderSide(color: _line),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (i) => _onItemTapped(context, i),
                type: BottomNavigationBarType.fixed,
                backgroundColor: _surface,
                elevation: 0,
                selectedItemColor: _gold,
                unselectedItemColor: _textMuted,
                selectedFontSize: 11.5,
                unselectedFontSize: 11.5,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
                items: [
                  _item(
                    index: 0,
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                  ),
                  _item(
                    index: 1,
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Messages',
                    showDot: hasUnreadMessages,
                  ),
                  _item(
                    index: 2,
                    icon: Icons.format_list_bulleted_rounded,
                    label: 'Listings',
                  ),
                  _item(
                    index: 3,
                    icon: Icons.home_work_outlined,
                    label: 'Home',
                    showDot: notes.newReviews > 0,
                  ),
                  _item(
                    index: 4,
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /* ───────── premium auth dialog ───────── */
  Future<void> _showAuthDialog(BuildContext ctx) async {
    if (!ctx.mounted) return;

    await showDialog(
      context: ctx,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogCtx) {
        final insets = MediaQuery.of(dialogCtx).viewInsets;

        return AnimatedPadding(
          padding:
              insets + const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Dialog(
                  backgroundColor: _surface,
                  insetPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                    side: const BorderSide(color: _line),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -50,
                        top: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _gold.withValues(alpha: 0.10),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -70,
                        bottom: -70,
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _brandColor.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [_gold, Color(0xFF7A5A20)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _gold.withValues(alpha: 0.18),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.black,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Sign in required',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Please sign in with a trainer account to access this section.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 14.5,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(dialogCtx).pop();

                                  if (!ctx.mounted) return;

                                  Navigator.pushReplacement(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (_) => const WelcomePage(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.black,
                                  size: 19,
                                ),
                                label: const Text(
                                  'Continue',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _gold,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  minimumSize: const Size(0, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: _textMuted,
                                ),
                                child: const Text(
                                  'Not now',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ───────────────── Premium nav icon ───────────────── */

class _PremiumNavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool showDot;

  const _PremiumNavIcon({
    required this.icon,
    required this.selected,
    required this.showDot,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 48,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected ? _gold.withValues(alpha: 0.14) : Colors.transparent,
        border: Border.all(
          color: selected ? _gold.withValues(alpha: 0.35) : Colors.transparent,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            size: selected ? 23 : 22,
            color: selected ? _gold : _textMuted,
          ),
          if (showDot)
            Positioned(
              right: 9,
              top: 6,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _danger,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
