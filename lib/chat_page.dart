import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'marketplace_page.dart';
import 'trainer_home_page.dart';

class ChatPage extends StatefulWidget {
  /// Firestore document id you plan to use for this conversation
  final String conversationId;

  /// uid of the other participant (needed when the conversation doc
  /// doesn’t exist yet so we can still render header info)
  final String otherUserId;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // other participant
  late final String _otherUserId; // filled in initState
  String _otherDisplayName = "Loading...";
  String _otherImageUrl = "";
  bool _isOtherTrainer = false;
  bool _hasListing = false;

  // ────────────────────────────────────────────
  // LIFECYCLE
  // ────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _otherUserId = widget.otherUserId;

    _loadConversationData();
    _markConversationAsRead(); // safe even if doc doesn’t exist yet
  }

  @override
  void dispose() {
    _maybeDeleteEmptyConversation(); // optional cleanup
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────
  // FIRESTORE HELPERS
  // ────────────────────────────────────────────
  Future<void> _markConversationAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'unreadBy': FieldValue.arrayRemove([currentUser.uid])
      });
    } catch (_) {
      // conversation document isn’t there yet → nothing to do
    }
  }

  Future<void> _maybeDeleteEmptyConversation() async {
    final ref = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);

    final doc = await ref.get();
    if (!doc.exists) return;

    final msgs = await ref.collection('messages').limit(1).get();
    if (msgs.docs.isEmpty) {
      await ref.delete();
    }
  }

  Future<void> _loadConversationData() async {
    try {
      // 1. Try to read existing conversation (purely for listing flag)
      final convSnap = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();
      if (convSnap.exists) {
        final data = convSnap.data() as Map<String, dynamic>;
        _hasListing = data['listingId'] != null &&
            (data['listingId'] as String).isNotEmpty;
      }

      // 2. Load OTHER user’s profile (trainer_profiles first)
      var userDoc = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(_otherUserId)
          .get();
      _isOtherTrainer = userDoc.exists;
      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_otherUserId)
            .get();
      }

      if (!userDoc.exists) {
        setState(() {
          _otherDisplayName = "Unknown User";
          _otherImageUrl = "";
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      setState(() {
        _otherDisplayName = userData['displayName'] ??
            ('${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}')
                .trim();
        _otherImageUrl = userData['profileImageUrl'] ?? '';
      });
    } catch (e) {
      debugPrint('Error loading conversation data: $e');
    }
  }

  // ────────────────────────────────────────────
  // SEND MESSAGE   (lazy create / update)
  // ────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final now = FieldValue.serverTimestamp();
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);
    final msgsRef = convRef.collection('messages');

    // 1. Add the chat message
    await msgsRef.add({
      'senderId': currentUser.uid,
      'recipientId': _otherUserId,
      'message': text,
      'timestamp': now,
    });

    // 2. Create OR update conversation atomically
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(convRef);

      if (!snap.exists) {
        tx.set(convRef, {
          'participants': [currentUser.uid, _otherUserId],
          'lastMessage': text,
          'timestamp': now,
          'unreadBy': _otherUserId != currentUser.uid ? [_otherUserId] : [],
        });
      } else {
        tx.update(convRef, {
          'lastMessage': text,
          'timestamp': now,
          if (_otherUserId != currentUser.uid)
            'unreadBy': FieldValue.arrayUnion([_otherUserId])
        });
      }
    });

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ────────────────────────────────────────────
  // REPORT USER DIALOG
  // ────────────────────────────────────────────
  void _showReportDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report User'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Why are you reporting?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(context);

              final currentUser = FirebaseAuth.instance.currentUser!;
              await FirebaseFirestore.instance.collection('reports').add({
                'reportedBy': currentUser.uid,
                'reportedItemId': _otherUserId,
                'reportedType': _isOtherTrainer ? 'trainer' : 'customer',
                'reason': reason,
                'timestamp': FieldValue.serverTimestamp(),
              });

              // update report count / flagged
              final countSnap = await FirebaseFirestore.instance
                  .collection('reports')
                  .where('reportedItemId', isEqualTo: _otherUserId)
                  .where('reportedType',
                      isEqualTo: _isOtherTrainer ? 'trainer' : 'customer')
                  .get();

              final targetCol = _isOtherTrainer ? 'trainer_profiles' : 'users';
              await FirebaseFirestore.instance
                  .collection(targetCol)
                  .doc(_otherUserId)
                  .set({
                'reportCount': countSnap.docs.length,
                if (countSnap.docs.length >= 3) 'flagged': true,
              }, SetOptions(merge: true));

              if (!mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('User reported')));
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final msgsQuery = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      // ---------------- HEADER ----------------
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFA726), Color(0xFFFFA726)],
              ),
            ),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: _otherImageUrl.isNotEmpty
                    ? NetworkImage(_otherImageUrl)
                    : const AssetImage('assets/default_profile.png')
                        as ImageProvider,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _otherDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.flag, color: Colors.white),
              tooltip: 'Report User',
              onPressed: _showReportDialog,
            ),
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.white),
              tooltip: 'View profile',
              onPressed: _navigateToOtherProfile,
            ),
          ],
        ),
      ),
      // ---------------- BODY ----------------
      body: SafeArea(
        child: Column(
          children: [
            // message list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: msgsQuery.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No messages yet.'));
                  }

                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final text = data['message'] ?? '';
                      final senderId = data['senderId'] ?? '';
                      final isMe =
                          senderId == FirebaseAuth.instance.currentUser?.uid;
                      final ts = data['timestamp'] as Timestamp?;
                      final timeStr = ts == null
                          ? ''
                          : DateFormat('h:mm a').format(ts.toDate());

                      return _buildBubble(
                          message: text, isMe: isMe, time: timeStr);
                    },
                  );
                },
              ),
            ),

            // typing bar
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom,
              ),
              child: _buildInputBar(),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // WIDGET HELPERS
  // ────────────────────────────────────────────
  Widget _buildBubble(
      {required String message, required bool isMe, required String time}) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 0),
      bottomRight: Radius.circular(isMe ? 0 : 16),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: isMe ? Colors.blueAccent : Colors.grey[200],
              borderRadius: radius,
            ),
            child: Text(
              message,
              style: TextStyle(
                  color: isMe ? Colors.white : Colors.black, fontSize: 16),
            ),
          ),
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                time,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Type something...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blueAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // PROFILE NAV
  // ────────────────────────────────────────────
  void _navigateToOtherProfile() {
    if (_otherUserId.isEmpty) return;

    if (_isOtherTrainer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrainerHomePage(
            trainerData: {
              'uid': _otherUserId,
              'displayName': _otherDisplayName,
              'profileImageUrl': _otherImageUrl,
            },
            viewAsCustomer: true,
          ),
        ),
      );
    } else {
      if (_hasListing) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MarketplacePage()),
        );
      } else {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('No Listing Found'),
            content: const Text(
                "Customer didn't create a listing. Chat to clarify their training needs?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}
