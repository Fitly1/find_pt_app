// lib/bottom_navigation_customers.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'signup_page.dart';
import 'login_page.dart';
import 'marketplace_page.dart';
import 'messages_page.dart';
import 'listings_page.dart';
import 'edit_listings_page.dart';
import 'customer_profile_page.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _brandColor = Color(0xFFFFA726);
const Color _surface = Color(0xFF111318);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class BottomNavigationCustomers extends StatelessWidget {
  final int currentIndex;

  const BottomNavigationCustomers({
    super.key,
    required this.currentIndex,
  });

  // ---------- Auth gate ----------
  Future<bool> _needsSignIn(int tabIndex) async {
    // Tabs that require auth: Messages(1), Edit Listings(3), Profile(4)
    if (![1, 3, 4].contains(tabIndex)) return false;

    final auth = FirebaseAuth.instance;
    final u = auth.currentUser;

    if (u != null) {
      final isPassword = u.providerData.any((p) => p.providerId == 'password');
      if (u.isAnonymous) return true;
      if (isPassword && !u.emailVerified) return true;
      return false;
    }

    try {
      final next = await auth
          .authStateChanges()
          .first
          .timeout(const Duration(milliseconds: 250));

      if (next == null || next.isAnonymous) return true;

      final isPassword =
          next.providerData.any((p) => p.providerId == 'password');

      if (isPassword && !next.emailVerified) return true;

      return false;
    } catch (_) {
      return true;
    }
  }

  // ---------- Premium sign-up sheet ----------
  Future<void> _showSignUpSheet(BuildContext ctx) async {
    if (!ctx.mounted) return;

    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.of(sheetCtx).viewInsets.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad + 12),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -48,
                    top: -48,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 22),
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
                            Icons.lock_open_rounded,
                            color: Colors.black,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Sign in to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create an account to message trainers, manage your profile, and unlock the full Fitly experience.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 14.5,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: _SheetPrimaryButton(
                            label: 'Sign up as Customer',
                            icon: Icons.person_outline_rounded,
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              if (!ctx.mounted) return;

                              Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => const SignupPage(
                                    preselectedRole: 'customer',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: _SheetSecondaryButton(
                            label: 'Sign up as Trainer',
                            icon: Icons.fitness_center_rounded,
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              if (!ctx.mounted) return;

                              Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => const SignupPage(
                                    preselectedRole: 'trainer',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SheetTextButton(
                                label: 'Log in',
                                onPressed: () {
                                  Navigator.pop(sheetCtx);
                                  if (!ctx.mounted) return;

                                  Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 18,
                              color: _line,
                            ),
                            Expanded(
                              child: _SheetTextButton(
                                label: 'Not now',
                                muted: true,
                                onPressed: () => Navigator.pop(sheetCtx),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Navigation ----------
  Future<void> _onItemTapped(BuildContext context, int index) async {
    if (index == currentIndex) return;

    if (await _needsSignIn(index)) {
      if (!context.mounted) return;
      await _showSignUpSheet(context);
      return;
    }

    if (!context.mounted) return;

    Widget nextPage;

    switch (index) {
      case 0:
        nextPage = const MarketplacePage();
        break;
      case 1:
        nextPage = const MessagesPage();
        break;
      case 2:
        nextPage = const ListingsPage();
        break;
      case 3:
        nextPage = const EditListingsPage();
        break;
      case 4:
        nextPage = const CustomerProfilePage();
        break;
      default:
        nextPage = const MarketplacePage();
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

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
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
                    icon: Icons.storefront_rounded,
                    label: 'Market',
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
                    icon: Icons.edit_note_rounded,
                    label: 'Edit',
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

/* ───────────────── Premium sheet buttons ───────────────── */

class _SheetPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SheetPrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.black, size: 19),
      label: Text(
        label,
        style: const TextStyle(
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
    );
  }
}

class _SheetSecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SheetSecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 19),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.045),
        side: const BorderSide(color: _line),
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _SheetTextButton extends StatelessWidget {
  final String label;
  final bool muted;
  final VoidCallback onPressed;

  const _SheetTextButton({
    required this.label,
    required this.onPressed,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: muted ? _textMuted : _gold,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: muted ? _textMuted : _gold,
        ),
      ),
    );
  }
}
