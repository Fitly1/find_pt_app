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

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  MessagesPageState createState() => MessagesPageState();
}

class MessagesPageState extends State<MessagesPage> {
  String userRole = 'customer';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString('userRole')?.toLowerCase() ?? 'customer';
    });
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
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFFFA726),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () {
            final isTrainer =
                userRole == 'trainer' || userRole == 'personal trainer';
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
      body: StreamBuilder<QuerySnapshot>(
        stream: conversationsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final conversation = docs[index];
              final data = conversation.data() as Map<String, dynamic>;

              final lastMessage = (data['lastMessage'] ?? '').toString().trim();
              if (lastMessage.isEmpty) return const SizedBox.shrink();

              final participants = data['participants'] as List<dynamic>? ?? [];
              final otherUid = participants
                  .firstWhere((p) => p != currentUser.uid, orElse: () => null);
              if (otherUid == null) return const SizedBox.shrink();

              final ts = data['timestamp'] as Timestamp? ?? Timestamp.now();
              final formattedTime = DateFormat('h:mm a').format(ts.toDate());
              final isUnread = (data['unreadBy'] as List<dynamic>? ?? [])
                  .contains(currentUser.uid);

              return FutureBuilder<Map<String, dynamic>?>(
                future: _fetchOtherUser(otherUid),
                builder: (context, userSnap) {
                  /* ───────── Account deleted / loading state ───────── */
                  if (!userSnap.hasData || userSnap.data == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 100),
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            title: const Text(
                              'Account deleted',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w500),
                            ),
                            subtitle: const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'This user no longer exists.',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black54),
                              ),
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formattedTime,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _confirmDeleteConversation(
                                      context, conversation.id),
                                  child: const Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  /* ───────── Normal tile when user exists ───────── */
                  final u = userSnap.data!;
                  final displayName =
                      '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                              .trim()
                              .isNotEmpty
                          ? '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                          : 'Unknown';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 110),
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),

                          // ───────── title + unread dot ─────────
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(left: 4),
                                  decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle),
                                ),
                            ],
                          ),

                          // ───────── message preview ─────────
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color:
                                    isUnread ? Colors.black87 : Colors.black54,
                              ),
                            ),
                          ),

                          // ───────── trailing ─────────
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formattedTime,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _confirmDeleteConversation(
                                    context, conversation.id),
                                child: const Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                              ),
                            ],
                          ),

                          // ───────── tap -> chat ─────────
                          onTap: () {
                            FirebaseFirestore.instance
                                .collection('conversations')
                                .doc(conversation.id)
                                .update({
                              'unreadBy':
                                  FieldValue.arrayRemove([currentUser.uid])
                            });

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => chat.ChatPage(
                                  conversationId: conversation.id,
                                  otherUserId: otherUid as String,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(color: Colors.black, child: _bottomNav()),
    );
  }

  /* ─────────────────────────── Helpers ──────────────────────────── */

  Future<Map<String, dynamic>?> _fetchOtherUser(String uid) async {
    final trainer = await FirebaseFirestore.instance
        .collection('trainer_profiles')
        .doc(uid)
        .get();
    if (trainer.exists) return trainer.data() as Map<String, dynamic>;

    final user =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (user.exists) return user.data() as Map<String, dynamic>;

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
              Navigator.pop(ctx);

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

              // Safety check for the context after async work
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
