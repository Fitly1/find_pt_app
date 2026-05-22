// lib/messages_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart' as chat;
import 'concierge_chat_page.dart';
import 'bottom_navigation.dart';
import 'bottom_navigation_customers.dart';
import 'trainer_home_page.dart';
import 'marketplace_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _brandColor = Color(0xFFFFA726);
const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _surfaceRaised = Color(0xFF20242C);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String userRole = 'customer';

  String? _conciergeAdminUid;
  String _conciergeName = 'Fitly Concierge';
  bool _conciergeTried = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadConciergeConfig();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
    });
  }

  Future<void> _loadConciergeConfig() async {
    if (_conciergeTried) return;
    _conciergeTried = true;

    try {
      final config = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('fitly')
          .get();

      final data = config.data() ?? <String, dynamic>{};

      final adminUid = (data['conciergeAdminUid'] ?? '').toString().trim();
      final name = (data['conciergeName'] ?? '').toString().trim();

      if (!mounted) return;

      setState(() {
        if (adminUid.isNotEmpty) _conciergeAdminUid = adminUid;
        if (name.isNotEmpty) _conciergeName = name;
      });

      if (adminUid.isNotEmpty) return;
    } catch (_) {}

    // Legacy fallback only. Your new setup uses app_config/fitly.
    try {
      final sys = await FirebaseFirestore.instance
          .collection('system')
          .doc('concierge')
          .get();

      final sysUid = (sys.data() ?? const {})['uid']?.toString().trim();

      if (sysUid != null && sysUid.isNotEmpty) {
        if (!mounted) return;
        setState(() => _conciergeAdminUid = sysUid);
        return;
      }
    } catch (_) {}

    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('isConcierge', isEqualTo: true)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        if (!mounted) return;
        setState(() => _conciergeAdminUid = q.docs.first.id);
      }
    } catch (_) {}
  }

  bool get _isTrainer {
    return userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer';
  }

  Widget _bottomNav() {
    return _isTrainer
        ? const BottomNavigation(currentIndex: 1)
        : const BottomNavigationCustomers(currentIndex: 1);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: _ink,
        body: _NoUserState(),
      );
    }

    final conversationsQuery = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _ink,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => _isTrainer
                    ? const TrainerHomePage()
                    : const MarketplacePage(),
              ),
            );
          },
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _line),
        ),
      ),
      body: RefreshIndicator(
        color: _gold,
        backgroundColor: _surface,
        onRefresh: () async {
          _conciergeTried = false;
          await _loadConciergeConfig();
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: conversationsQuery.snapshots(),
          builder: (context, convSnap) {
            if (convSnap.hasError) {
              return _ErrorState(error: convSnap.error);
            }

            if (!convSnap.hasData) {
              return const _LoadingList();
            }

            final docs = convSnap.data!.docs;

            final visibleDocs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;

              final lastMessage = (data['lastMessage'] ?? '').toString().trim();
              if (lastMessage.isEmpty) return false;

              final deletedFor = (data['deletedFor'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList();

              if (deletedFor.contains(currentUser.uid)) return false;

              return true;
            }).toList();

            if (visibleDocs.isEmpty) {
              return const _EmptyState();
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: visibleDocs.length,
              itemBuilder: (context, index) {
                final conversation = visibleDocs[index];
                final data = conversation.data() as Map<String, dynamic>;

                final lastMessage =
                    (data['lastMessage'] ?? '').toString().trim();

                final participants =
                    (data['participants'] as List<dynamic>? ?? [])
                        .map((e) => e.toString())
                        .where((e) => e.isNotEmpty)
                        .toList();

                final normalOtherUid = participants.firstWhere(
                  (p) => p != currentUser.uid,
                  orElse: () => '',
                );

                if (normalOtherUid.isEmpty && participants.length < 2) {
                  return const SizedBox.shrink();
                }

                final ts = data['timestamp'] as Timestamp? ?? Timestamp.now();
                final formattedTime =
                    DateFormat('MMM d • h:mm a').format(ts.toDate());

                final isUnread = (data['unreadBy'] as List<dynamic>? ?? [])
                    .map((e) => e.toString())
                    .contains(currentUser.uid);

                final isConcierge = _isConciergeThread(data, participants);

                final assignedAdminUid = _stringFrom(
                  data,
                  ['assignedAdminId', 'conciergeAdminUid', 'adminId'],
                  fallback: _conciergeAdminUid ?? '',
                );

                final customerUid = _resolveCustomerUid(
                  conv: data,
                  participants: participants,
                  currentUserId: currentUser.uid,
                  assignedAdminUid: assignedAdminUid,
                );

                final isAdminViewer = isConcierge &&
                    assignedAdminUid.isNotEmpty &&
                    currentUser.uid == assignedAdminUid;

                final otherUid = isConcierge
                    ? (isAdminViewer ? customerUid : assignedAdminUid)
                    : normalOtherUid;

                if (otherUid.isEmpty) return const SizedBox.shrink();

                final shouldFetchUser = !isConcierge || isAdminViewer;

                return FutureBuilder<_UserLite?>(
                  future: shouldFetchUser
                      ? _fetchOtherUserLite(otherUid)
                      : Future<_UserLite?>.value(null),
                  builder: (context, userSnap) {
                    if (shouldFetchUser &&
                        userSnap.connectionState != ConnectionState.done) {
                      return _loadingTile(formattedTime);
                    }

                    final other = userSnap.data;

                    final displayName = _displayNameForConversation(
                      conv: data,
                      isConcierge: isConcierge,
                      isAdminViewer: isAdminViewer,
                      other: other,
                    );

                    final avatar = _avatarForConversation(
                      isConcierge: isConcierge,
                      isAdminViewer: isAdminViewer,
                      other: other,
                      isUnread: isUnread,
                    );

                    return _conversationTile(
                      avatar: avatar,
                      displayName: displayName,
                      formattedTime: formattedTime,
                      lastMessage: lastMessage,
                      isUnread: isUnread,
                      isConcierge: isConcierge,
                      conversationId: conversation.id,
                      otherUid: otherUid,
                      currentUserId: currentUser.uid,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  bool _isConciergeThread(
    Map<String, dynamic> conv,
    List<String> participants,
  ) {
    if ((conv['isConcierge'] == true) ||
        (conv['isConciergeThread'] == true) ||
        (conv['concierge'] == true) ||
        (conv['type']?.toString().toLowerCase() == 'concierge')) {
      return true;
    }

    if (conv.containsKey('conciergeGoal') ||
        conv.containsKey('conciergeBudget') ||
        conv.containsKey('conciergeLocation') ||
        conv.containsKey('assignedAdminId')) {
      return true;
    }

    if (_conciergeAdminUid != null &&
        _conciergeAdminUid!.isNotEmpty &&
        participants.contains(_conciergeAdminUid)) {
      return true;
    }

    return false;
  }

  String _resolveCustomerUid({
    required Map<String, dynamic> conv,
    required List<String> participants,
    required String currentUserId,
    required String assignedAdminUid,
  }) {
    final explicit = _stringFrom(conv, ['customerId']);
    if (explicit.isNotEmpty) return explicit;

    for (final uid in participants) {
      if (uid != assignedAdminUid) return uid;
    }

    for (final uid in participants) {
      if (uid != currentUserId) return uid;
    }

    return '';
  }

  String _displayNameForConversation({
    required Map<String, dynamic> conv,
    required bool isConcierge,
    required bool isAdminViewer,
    required _UserLite? other,
  }) {
    if (isConcierge && !isAdminViewer) {
      return _stringFrom(
        conv,
        ['conciergeName'],
        fallback: _conciergeName,
      );
    }

    if (isConcierge && isAdminViewer) {
      final convName = _stringFrom(
        conv,
        [
          'customerName',
          'customerDisplayName',
          'displayName',
          'name',
        ],
      );

      if (convName.isNotEmpty) return convName;

      final fetchedName = other?.displayName?.trim() ?? '';
      if (fetchedName.isNotEmpty) return fetchedName;

      return 'Customer';
    }

    final fetchedName = other?.displayName?.trim() ?? '';
    if (fetchedName.isNotEmpty) return fetchedName;

    return 'Account unavailable';
  }

  Widget _avatarForConversation({
    required bool isConcierge,
    required bool isAdminViewer,
    required _UserLite? other,
    required bool isUnread,
  }) {
    if (isConcierge && !isAdminViewer) {
      return const _ConciergeAvatar();
    }

    return _UserAvatar(
      url: other?.avatarUrl ?? '',
      isUnread: isUnread,
    );
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

  /* ─────────────────────── small UI helpers ────────────────────────── */

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _gold.withValues(alpha: 0.32),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: _gold,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _loadingTile(String formattedTime) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const _SkeletonCircle(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 130,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formattedTime,
            style: const TextStyle(
              fontSize: 11.5,
              color: _textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _conversationTile({
    required Widget avatar,
    required String displayName,
    required String formattedTime,
    required String lastMessage,
    required bool isUnread,
    required bool isConcierge,
    required String conversationId,
    required String otherUid,
    required String currentUserId,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isUnread ? _gold.withValues(alpha: 0.36) : _line,
        ),
        boxShadow: [
          if (isUnread)
            BoxShadow(
              color: _brandColor.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(22),
              ),
              onTap: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(conversationId)
                      .update({
                    'unreadBy': FieldValue.arrayRemove([currentUserId]),
                  });
                } catch (_) {}

                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) {
                      if (isConcierge) {
                        return ConciergeChatPage(
                          conversationId: conversationId,
                          otherUserId: otherUid,
                          lazyCreate: false,
                        );
                      }

                      return chat.ChatPage(
                        conversationId: conversationId,
                        otherUserId: otherUid,
                      );
                    },
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight:
                                  isUnread ? FontWeight.w900 : FontWeight.w800,
                              letterSpacing: -0.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isUnread ? _gold : _textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isUnread
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : _textMuted,
                                    fontWeight: isUnread
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isConcierge) ...[
                                const SizedBox(width: 8),
                                _tag('Concierge'),
                              ],
                              if (isUnread) ...[
                                const SizedBox(width: 8),
                                const _UnreadDot(),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 54,
            color: _line,
          ),
          IconButton(
            tooltip: 'Remove conversation',
            onPressed: () => _confirmRemoveConversation(
              conversationId: conversationId,
              currentUserId: currentUserId,
            ),
            icon: Icon(
              Icons.delete_outline_rounded,
              color: _danger.withValues(alpha: 0.86),
              size: 21,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /* ─────────────────────────── Data helpers ──────────────────────────── */

  Future<_UserLite?> _fetchOtherUserLite(String uid) async {
    try {
      final t = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(uid)
          .get();

      if (t.exists) {
        final td = t.data() ?? <String, dynamic>{};

        return _UserLite.fromMaps(
          uid: uid,
          data: td,
          preferredDisplayName: td['displayName'],
          firstName: td['firstName'],
          lastName: td['lastName'],
          avatarUrl: td['profileImageUrl'],
          role: td['role'],
        );
      }

      final u =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (u.exists) {
        final ud = u.data() ?? <String, dynamic>{};

        return _UserLite.fromMaps(
          uid: uid,
          data: ud,
          preferredDisplayName: ud['displayName'],
          firstName: ud['firstName'],
          lastName: ud['lastName'],
          avatarUrl: ud['profileImageUrl'],
          role: ud['role'],
        );
      }
    } catch (_) {}

    return null;
  }

  Future<void> _confirmRemoveConversation({
    required String conversationId,
    required String currentUserId,
  }) async {
    final confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.72),
          builder: (dialogCtx) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  color: Colors.transparent,
                  child: Dialog(
                    backgroundColor: _surface,
                    insetPadding: const EdgeInsets.symmetric(horizontal: 28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                      side: const BorderSide(color: _line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _danger.withValues(alpha: 0.13),
                              border: Border.all(
                                color: _danger.withValues(alpha: 0.28),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: _danger,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Remove conversation?',
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
                            'This removes the conversation from your inbox only. It will not delete it for the other person.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 14.5,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              Expanded(
                                child: _SecondaryButton(
                                  label: 'Cancel',
                                  icon: null,
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DangerButton(
                                  label: 'Remove',
                                  icon: Icons.delete_outline_rounded,
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ) ??
        false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .set({
        'deletedFor': FieldValue.arrayUnion([currentUserId]),
        'unreadBy': FieldValue.arrayRemove([currentUserId]),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showPremiumSnackBar('Conversation removed from your inbox');
    } catch (e) {
      if (!mounted) return;

      _showPremiumSnackBar(
        'Could not remove conversation.',
        error: true,
      );
    }
  }

  void _showPremiumSnackBar(String message, {bool error = false}) {
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
}

/* ─────────────────────────── UI bits ──────────────────────────── */

class _NoUserState extends StatelessWidget {
  const _NoUserState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _line),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: _gold,
              ),
              SizedBox(height: 16),
              Text(
                'No user found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please sign in to view your messages.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.11),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  size: 36,
                  color: _gold,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No conversations yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'When you message a trainer, customer, or Fitly Concierge, your conversations will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;

  const _ErrorState({
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _danger.withValues(alpha: 0.4),
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
                'Couldn’t load messages',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemBuilder: (_, __) => Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const _SkeletonCircle(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: 5,
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: _gold,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

class _ConciergeAvatar extends StatelessWidget {
  const _ConciergeAvatar();

  static const double _kSize = 48;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSize,
      height: _kSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_gold, Color(0xFF6F5422)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: Container(
          color: _ink,
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/Fitly2.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text(
                'F',
                style: TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String url;
  final bool isUnread;

  const _UserAvatar({
    required this.url,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = url.isNotEmpty
        ? NetworkImage(url)
        : const AssetImage('assets/default_profile.png') as ImageProvider;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isUnread
                ? const LinearGradient(
                    colors: [_gold, _brandColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: isUnread
                ? null
                : Border.all(
                    color: _line,
                    width: 1.5,
                  ),
          ),
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            backgroundColor: _surfaceRaised,
            backgroundImage: imageProvider,
          ),
        ),
        if (isUnread)
          const Positioned(
            right: -1,
            bottom: -1,
            child: _UnreadDot(),
          ),
      ],
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
          fontSize: 14.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: _line),
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        backgroundColor: Colors.white.withValues(alpha: 0.045),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _DangerButton({
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
          : Icon(icon, size: 18, color: Colors.white),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _danger,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _UserLite {
  final String uid;
  final String? displayName;
  final String? avatarUrl;
  final String? role;
  final bool isConcierge;

  _UserLite({
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.role,
    required this.isConcierge,
  });

  factory _UserLite.fromMaps({
    required String uid,
    required Map<String, dynamic> data,
    String? preferredDisplayName,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? role,
  }) {
    String? name = (preferredDisplayName ?? '').toString().trim();

    if (name.isEmpty) {
      final fn = (firstName ?? '').toString().trim();
      final ln = (lastName ?? '').toString().trim();
      name = '$fn $ln'.trim();
    }

    final r = role?.toString().toLowerCase() ??
        data['role']?.toString().toLowerCase();

    final conciergeFlag = (data['isConcierge'] == true) || (r == 'concierge');

    return _UserLite(
      uid: uid,
      displayName: name,
      avatarUrl: (avatarUrl ?? data['profileImageUrl'] ?? '').toString(),
      role: r,
      isConcierge: conciergeFlag,
    );
  }
}
