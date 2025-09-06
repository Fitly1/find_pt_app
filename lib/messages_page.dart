// lib/messages_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart' as chat;
import 'bottom_navigation.dart';
import 'bottom_navigation_customers.dart';
import 'trainer_home_page.dart';
import 'marketplace_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _brand = Color(0xFFFFA726);

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String userRole = 'customer';

  /// Cached concierge uid (loaded once from Firestore)
  String? _conciergeUid;
  bool _conciergeTried = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadConciergeUid();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
    });
  }

  Future<void> _loadConciergeUid() async {
    if (_conciergeTried) return;
    _conciergeTried = true;
    try {
      // Preferred: system/concierge { uid: "..." }
      final sys = await FirebaseFirestore.instance
          .collection('system')
          .doc('concierge')
          .get();
      final sysUid = (sys.data() ?? const {})['uid']?.toString();
      if (sysUid != null && sysUid.isNotEmpty) {
        if (!mounted) return;
        setState(() => _conciergeUid = sysUid);
        return;
      }
    } catch (_) {}

    try {
      // Fallback: users where isConcierge == true
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('isConcierge', isEqualTo: true)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        if (!mounted) return;
        setState(() => _conciergeUid = q.docs.first.id);
      }
    } catch (_) {}
  }

  Widget _bottomNav() {
    final isTrainer = userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer';
    return isTrainer
        ? const BottomNavigation(currentIndex: 1)
        : const BottomNavigationCustomers(currentIndex: 1);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('No user found')),
      );
    }

    final conversationsQuery = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: _brand,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26, color: Colors.white),
          onPressed: () {
            final isTrainer = userRole == 'trainer' ||
                userRole == 'personal trainer' ||
                userRole == 'personaltrainer';
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => isTrainer
                    ? const TrainerHomePage()
                    : const MarketplacePage(),
              ),
            );
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: conversationsQuery.snapshots(),
          builder: (context, convSnap) {
            if (convSnap.hasError) {
              return Center(child: Text('Error: ${convSnap.error}'));
            }
            if (!convSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = convSnap.data!.docs;
            if (docs.isEmpty) {
              return const _EmptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final conversation = docs[index];
                final data = conversation.data() as Map<String, dynamic>;
                final lastMessage =
                    (data['lastMessage'] ?? '').toString().trim();
                if (lastMessage.isEmpty) return const SizedBox.shrink();

                final participants =
                    (data['participants'] as List<dynamic>? ?? [])
                        .map((e) => e.toString())
                        .toList();
                final otherUid = participants.firstWhere(
                  (p) => p != currentUser.uid,
                  orElse: () => '',
                );
                if (otherUid.isEmpty) return const SizedBox.shrink();

                final ts = data['timestamp'] as Timestamp? ?? Timestamp.now();
                final formattedTime =
                    DateFormat('MMM d • h:mm a').format(ts.toDate());
                final isUnread = (data['unreadBy'] as List<dynamic>? ?? [])
                    .map((e) => e.toString())
                    .contains(currentUser.uid);

                return FutureBuilder<_UserLite?>(
                  future: _fetchOtherUserLite(otherUid),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState != ConnectionState.done) {
                      return _loadingTile(formattedTime);
                    }

                    final other = userSnap.data;
                    final isConcierge =
                        _isConciergeThread(data, otherUid, other);
                    final displayName = isConcierge
                        ? 'Fitly Concierge'
                        : (other?.displayName?.trim().isNotEmpty == true
                            ? other!.displayName!.trim()
                            : 'Unknown');

                    final avatarUrl = other?.avatarUrl ?? '';
                    final avatar = isConcierge
                        ? const _ConciergeAvatar()
                        : _UserAvatar(url: avatarUrl, isUnread: isUnread);

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
      bottomNavigationBar: Container(color: Colors.black, child: _bottomNav()),
    );
  }

  bool _isConciergeThread(
      Map<String, dynamic> conv, String otherUid, _UserLite? other) {
    if ((conv['isConciergeThread'] == true) ||
        (conv['concierge'] == true) ||
        (conv['type']?.toString().toLowerCase() == 'concierge')) {
      return true;
    }
    if (_conciergeUid != null && _conciergeUid == otherUid) return true;
    if (other?.isConcierge == true) return true;
    return false;
  }

  /* ─────────────────────── small UI helpers ────────────────────────── */

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(25, 118, 210, 0.12), // soft blue pill
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1976D2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1565C0),
        ),
      ),
    );
  }

  /* ─────────────────────── tile builders ────────────────────────── */

  Widget _loadingTile(String formattedTime) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 92),
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              leading: const _SkeletonCircle(),
              title: Container(
                  height: 14, width: 120, color: Colors.grey.shade300),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(height: 12, color: Colors.grey.shade200),
              ),
              trailing: Text(
                formattedTime,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ),
      );

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 92),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversationId)
                  .update({
                'unreadBy': FieldValue.arrayRemove([currentUserId])
              });

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => chat.ChatPage(
                    conversationId: conversationId,
                    otherUserId: otherUid,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + time
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Preview + unread dot + concierge badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isUnread
                                      ? Colors.black87
                                      : Colors.black54,
                                  fontWeight: isUnread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
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
                  const SizedBox(width: 6),
                  // Delete button
                  InkWell(
                    onTap: () =>
                        _confirmDeleteConversation(context, conversationId),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.delete_outline,
                          color: Colors.red, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /* ─────────────────────────── Data helpers ──────────────────────────── */

  Future<_UserLite?> _fetchOtherUserLite(String uid) async {
    try {
      // Prefer trainer_profiles for trainers
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

      // Fall back to users
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

  void _confirmDeleteConversation(BuildContext ctx, String conversationId) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Conversation'),
        content:
            const Text('Are you sure you want to delete this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(ctx); // close dialog first

              // Delete all messages
              final msgs = FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversationId)
                  .collection('messages');
              final snap = await msgs.get();
              for (var d in snap.docs) {
                await d.reference.delete();
              }

              // Delete the conversation document
              await FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversationId)
                  .delete();

              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Conversation deleted')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────────── UI bits ──────────────────────────── */

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.forum_outlined, size: 64, color: Colors.black26),
          SizedBox(height: 10),
          Text('No conversations yet',
              style: TextStyle(fontSize: 16, color: Colors.black54)),
        ],
      ),
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
        color: Colors.grey.shade300,
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
      decoration:
          const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
    );
  }
}

// Replace your existing _ConciergeAvatar with this:
class _ConciergeAvatar extends StatelessWidget {
  const _ConciergeAvatar();

  static const double _kSize = 46;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSize,
      height: _kSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1976D2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // ensures the image is circular
      child: Image.asset(
        'assets/Fitly2.png',
        fit: BoxFit.cover, // fills the circle cleanly
        errorBuilder: (_, __, ___) => const Center(
          child: Text('F', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String url;
  final bool isUnread;
  const _UserAvatar({required this.url, required this.isUnread});

  @override
  Widget build(BuildContext context) {
    final image = (url.isNotEmpty)
        ? CircleAvatar(radius: 23, backgroundImage: NetworkImage(url))
        : const CircleAvatar(
            radius: 23,
            backgroundColor: Color(0xFFE0E0E0),
            child: Icon(Icons.person, color: Colors.white));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        image,
        if (isUnread)
          const Positioned(
            right: -2,
            bottom: -2,
            child: _UnreadDot(),
          ),
      ],
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
        (data['role']?.toString().toLowerCase());
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
