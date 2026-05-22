// lib/concierge_inbox_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'concierge_chat_page.dart';

/* ───────────────── Fitly premium colours ───────────────── */

const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _surfaceRaised = Color(0xFF20242C);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);
const Color _success = Color(0xFF4CD17D);

class ConciergeInboxPage extends StatefulWidget {
  const ConciergeInboxPage({super.key});

  @override
  State<ConciergeInboxPage> createState() => _ConciergeInboxPageState();
}

class _ConciergeInboxPageState extends State<ConciergeInboxPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> _isAdmin(String uid) async {
    final snap = await _firestore.collection('admins').doc(uid).get();
    final data = snap.data() ?? <String, dynamic>{};
    return data['active'] == true;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _conciergeConversationsStream(
    String uid,
  ) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .where('isConcierge', isEqualTo: true)
        .snapshots();
  }

  String _stringFrom(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;

      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return fallback;
  }

  Timestamp? _timestampFrom(Map<String, dynamic> data) {
    final candidates = [
      data['updatedAt'],
      data['timestamp'],
      data['createdAt'],
    ];

    for (final item in candidates) {
      if (item is Timestamp) return item;
    }

    return null;
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _customerName(Map<String, dynamic> data, String customerId) {
    final name = _stringFrom(
      data,
      [
        'customerName',
        'customerDisplayName',
        'displayName',
        'name',
      ],
    );

    if (name.isNotEmpty) return name;

    final email = _stringFrom(data, ['customerEmail', 'email']);
    if (email.isNotEmpty) return email.split('@').first;

    if (customerId.isNotEmpty) return 'Customer ${customerId.substring(0, 5)}';

    return 'Customer';
  }

  String _customerIdFromConversation(
    Map<String, dynamic> data,
    String currentUid,
  ) {
    final explicitCustomerId = _stringFrom(data, ['customerId']);
    if (explicitCustomerId.isNotEmpty) return explicitCustomerId;

    final participants = data['participants'];
    if (participants is List) {
      for (final item in participants) {
        final uid = item?.toString() ?? '';
        if (uid.isNotEmpty && uid != currentUid) return uid;
      }
    }

    return '';
  }

  Future<void> _markStatus({
    required String conversationId,
    required String status,
  }) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showSnackBar(
        status == 'closed'
            ? 'Concierge request marked as closed.'
            : 'Concierge request reopened.',
      );
    } catch (e) {
      debugPrint('Could not update concierge request status: $e');

      if (!mounted) return;

      _showSnackBar(
        'Could not update request status.',
        error: true,
      );
    }
  }

  Future<void> _openConversation({
    required String conversationId,
    required String customerId,
    required String currentUid,
  }) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).set({
        'unreadBy': FieldValue.arrayRemove([currentUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Not critical. The chat should still open.
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConciergeChatPage(
          conversationId: conversationId,
          otherUserId: customerId,
          lazyCreate: false,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _surfaceRaised,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: error ? _danger.withValues(alpha: 0.45) : _line,
          ),
        ),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: error ? _danger : _gold,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: _ink,
      body: Center(
        child: CircularProgressIndicator(color: _gold),
      ),
    );
  }

  Widget _buildNoAccess({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: _ink,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Concierge Inbox',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gold.withValues(alpha: 0.11),
                    border: Border.all(
                      color: _gold.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: _gold,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 14.5,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required int openCount, required int unreadCount}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -44,
            top: -46,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SmallLabel(text: 'FITLY ADMIN'),
              const SizedBox(height: 10),
              const Text(
                'Concierge Inbox',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.65,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Customer requests from the Find my trainer flow.',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14.2,
                  height: 1.38,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatPill(
                    label: '$openCount open',
                    icon: Icons.folder_open_rounded,
                    color: _gold,
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    label: '$unreadCount unread',
                    icon: Icons.mark_chat_unread_rounded,
                    color: unreadCount > 0 ? _success : _textMuted,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInbox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            color: _gold,
            size: 42,
          ),
          SizedBox(height: 14),
          Text(
            'No concierge requests yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When a customer submits the Find my trainer form, it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMuted,
              fontSize: 14,
              height: 1.42,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String currentUid,
  }) {
    final data = doc.data();
    final customerId = _customerIdFromConversation(data, currentUid);
    final customerName = _customerName(data, customerId);

    final goal = _stringFrom(
      data,
      ['conciergeGoal', 'goal', 'fitnessGoal'],
      fallback: 'Goal not provided',
    );

    final trainingPreference = _stringFrom(
      data,
      [
        'conciergeTrainingPreference',
        'trainingPreference',
        'trainingType',
      ],
      fallback: 'Training preference not provided',
    );

    final location = _stringFrom(
      data,
      ['conciergeLocation', 'location', 'suburb'],
      fallback: 'Location not provided',
    );

    final budget = _stringFrom(
      data,
      ['conciergeBudget', 'budget'],
      fallback: 'Budget not provided',
    );

    final experience = _stringFrom(
      data,
      ['conciergeExperience', 'experience', 'experienceLevel'],
      fallback: 'Experience not provided',
    );

    final lastMessage = _stringFrom(
      data,
      ['lastMessage'],
      fallback: 'Open chat to view request.',
    );

    final status =
        _stringFrom(data, ['status'], fallback: 'open').toLowerCase();
    final isClosed = status == 'closed';
    final timestamp = _timestampFrom(data);

    final unreadBy = data['unreadBy'];
    final isUnread = unreadBy is List && unreadBy.contains(currentUid);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        if (customerId.isEmpty) {
          _showSnackBar(
            'Could not find the customer for this request.',
            error: true,
          );
          return;
        }

        _openConversation(
          conversationId: doc.id,
          customerId: customerId,
          currentUid: currentUid,
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUnread
                ? _gold.withValues(alpha: 0.50)
                : isClosed
                    ? _line.withValues(alpha: 0.72)
                    : _line,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_gold, Color(0xFF74551E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_search_rounded,
                    color: Colors.black,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: _gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(timestamp),
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(isClosed: isClosed),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.flag_rounded, label: goal),
                _InfoChip(
                  icon: Icons.fitness_center_rounded,
                  label: trainingPreference,
                ),
                _InfoChip(icon: Icons.location_on_rounded, label: location),
                _InfoChip(icon: Icons.payments_rounded, label: budget),
                _InfoChip(icon: Icons.trending_up_rounded, label: experience),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: _ink.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
              ),
              child: Text(
                lastMessage,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    label: 'Open chat',
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: () {
                      if (customerId.isEmpty) {
                        _showSnackBar(
                          'Could not find the customer for this request.',
                          error: true,
                        );
                        return;
                      }

                      _openConversation(
                        conversationId: doc.id,
                        customerId: customerId,
                        currentUid: currentUid,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: isClosed
                      ? _PrimaryButton(
                          label: 'Reopen',
                          icon: Icons.refresh_rounded,
                          onPressed: () => _markStatus(
                            conversationId: doc.id,
                            status: 'open',
                          ),
                        )
                      : _SecondaryButton(
                          label: 'Close',
                          icon: Icons.check_circle_outline_rounded,
                          onPressed: () => _markStatus(
                            conversationId: doc.id,
                            status: 'closed',
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInbox(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _conciergeConversationsStream(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return _InboxError(error: snap.error);
        }

        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _gold),
          );
        }

        final docs = snap.data!.docs.toList();

        docs.sort((a, b) {
          final ta = _timestampFrom(a.data());
          final tb = _timestampFrom(b.data());

          final aDate = ta?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = tb?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);

          return bDate.compareTo(aDate);
        });

        final openCount = docs.where((doc) {
          final status = _stringFrom(
            doc.data(),
            ['status'],
            fallback: 'open',
          ).toLowerCase();

          return status != 'closed';
        }).length;

        final unreadCount = docs.where((doc) {
          final unreadBy = doc.data()['unreadBy'];
          return unreadBy is List && unreadBy.contains(uid);
        }).length;

        return RefreshIndicator(
          color: _gold,
          backgroundColor: _surface,
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 350));
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: docs.isEmpty ? 2 : docs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              if (index == 0) {
                return _buildHeader(
                  openCount: openCount,
                  unreadCount: unreadCount,
                );
              }

              if (docs.isEmpty) {
                return _buildEmptyInbox();
              }

              final doc = docs[index - 1];

              return _buildRequestCard(
                doc: doc,
                currentUid: uid,
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return _buildNoAccess(
        title: 'Login required',
        message: 'Log in with your admin account to view concierge requests.',
        icon: Icons.login_rounded,
      );
    }

    return FutureBuilder<bool>(
      future: _isAdmin(user.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        final isAdmin = snap.data == true;

        if (!isAdmin) {
          return _buildNoAccess(
            title: 'Admin access required',
            message:
                'This inbox is only visible to accounts added to the admins collection.',
            icon: Icons.admin_panel_settings_outlined,
          );
        }

        return Scaffold(
          backgroundColor: _ink,
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle.light,
            backgroundColor: _ink,
            elevation: 0,
            foregroundColor: Colors.white,
            title: const Text(
              'Concierge Inbox',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: _line),
            ),
          ),
          body: _buildInbox(user.uid),
        );
      },
    );
  }
}

/* ───────────────── Small premium widgets ───────────────── */

class _SmallLabel extends StatelessWidget {
  final String text;

  const _SmallLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _gold,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.15,
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: 0.26),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color == _textMuted ? Colors.white : color,
                  fontSize: 12.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isClosed;

  const _StatusPill({required this.isClosed});

  @override
  Widget build(BuildContext context) {
    final color = isClosed ? _textMuted : _success;
    final label = isClosed ? 'Closed' : 'Open';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _surfaceRaised.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _gold, size: 15),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 18, color: Colors.black),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 0,
        minimumSize: const Size(0, 46),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 18, color: Colors.white),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: _line),
        minimumSize: const Size(0, 46),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        backgroundColor: Colors.white.withValues(alpha: 0.045),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }
}

class _InboxError extends StatelessWidget {
  final Object? error;

  const _InboxError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: _danger.withValues(alpha: 0.38),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _danger,
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Could not load inbox',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
