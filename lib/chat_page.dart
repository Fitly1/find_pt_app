// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'marketplace_page.dart';
import 'trainer_home_page.dart';
import 'services/block_service.dart';

class ChatPage extends StatefulWidget {
  /// Firestore document id you plan to use for this conversation
  final String conversationId;

  /// uid of the other participant
  final String otherUserId;

  /// If true, DO NOT read/create the conversation until the first send.
  final bool lazyCreate;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    this.lazyCreate = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ───────────────────────────────── controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // input state
  bool _canSend = false;

  // ───────────────────────────────── other participant
  late final String _otherUserId;
  String _otherDisplayName = "Loading...";
  String _otherImageUrl = "";
  bool _isOtherTrainer = false;
  bool _hasListing = false;

  // ───────────────────────────────── block state
  bool _iBlockedThem = false;
  bool _theyBlockedMe = false;

  // When true we attach the messages StreamBuilder.
  // In lazy mode this becomes true after the first successful send
  // OR when the conversation appears (from console reply, etc).
  bool _conversationLive = false;

  // live update for block status & conversation existence
  StreamSubscription<DocumentSnapshot>? _blockSub;
  StreamSubscription<DocumentSnapshot>? _convWatchSub;

  @override
  void initState() {
    super.initState();
    _otherUserId = widget.otherUserId;
    _conversationLive = !widget.lazyCreate;

    // watch input to enable/disable send button
    _messageController.addListener(() {
      final next = _messageController.text.trim().isNotEmpty;
      if (next != _canSend) {
        setState(() => _canSend = next);
      }
    });

    _loadParticipantData(); // safe even in lazy mode

    if (!widget.lazyCreate) {
      _markConversationAsRead(); // only if we expect the convo to exist
      _loadConversationExtras(); // listing flag, etc.
    } else {
      // In lazy mode: watch for the conversation being created elsewhere
      final convRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId);

      _convWatchSub = convRef.snapshots().listen((snap) {
        if (!mounted) return;
        if (snap.exists && !_conversationLive) {
          _conversationLive = true;

          // best effort: pick up listing flag if present
          final data = snap.data() ?? const <String, dynamic>{};
          _hasListing = (data['listingId'] is String) &&
              (data['listingId'] as String).isNotEmpty;

          setState(() {});
          _markConversationAsRead();
          _scrollToBottom();
        }
      });
    }

    _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    _iBlockedThem = await BlockService.instance.iBlocked(_otherUserId);
    _theyBlockedMe = await BlockService.instance.blockedMe(_otherUserId);

    _blockSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_otherUserId)
        .collection('blocked')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((doc) {
      _theyBlockedMe = doc.exists;
      if (mounted) setState(() {});
    });

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_conversationLive) {
      _maybeDeleteEmptyConversation();
    }
    _messageController.removeListener(() {});
    _messageController.dispose();
    _scrollController.dispose();
    _blockSub?.cancel();
    _convWatchSub?.cancel();
    super.dispose();
  }

  // ───────────────────────────────── helpers
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
      // ignore if it doesn't exist yet
    }
  }

  Future<void> _maybeDeleteEmptyConversation() async {
    final ref = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);

    try {
      final doc = await ref.get();
      if (!doc.exists) return;

      final msgs = await ref.collection('messages').limit(1).get();
      if (msgs.docs.isEmpty) {
        await ref.delete();
      }
    } catch (_) {
      // ignore permission / existence issues
    }
  }

  // Only reads profile docs (safe in lazy mode).
  Future<void> _loadParticipantData() async {
    try {
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
      debugPrint('Error loading user data: $e');
    }
  }

  // Only attempt conversation-specific extra reads when not lazy
  Future<void> _loadConversationExtras() async {
    try {
      final convSnap = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();
      if (convSnap.exists) {
        final data = convSnap.data() as Map<String, dynamic>;
        _hasListing = data['listingId'] != null &&
            (data['listingId'] as String).isNotEmpty;
      }
    } catch (_) {
      // ignore
    }
  }

  // ───────────────────────────────── send message
  Future<void> _sendMessage() async {
    if (_iBlockedThem) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('You blocked this user')));
      return;
    }
    if (_theyBlockedMe) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user has blocked you')));
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final myUid = me.uid;
    final otherUid = _otherUserId;

    final now = FieldValue.serverTimestamp();
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);
    final msgsRef = convRef.collection('messages');

    // 1) Try to UPDATE existing convo (do NOT include `participants`)
    try {
      await convRef.update({
        'lastMessage': text,
        'timestamp': now,
        if (otherUid != myUid) 'unreadBy': FieldValue.arrayUnion([otherUid]),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        // 2) CREATE if missing (include `participants` once)
        final parts = (myUid.compareTo(otherUid) < 0)
            ? [myUid, otherUid]
            : [otherUid, myUid];
        await convRef.set({
          'participants': parts,
          'lastMessage': text,
          'timestamp': now,
          'unreadBy': otherUid != myUid ? [otherUid] : [],
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't start chat: ${e.message}")),
        );
        return;
      }
    }

    // 3) Write the message
    try {
      final senderToken = await FirebaseMessaging.instance.getToken();
      await msgsRef.add({
        'senderId': myUid,
        'recipientId': otherUid,
        'message': text,
        'timestamp': now,
        'senderDeviceToken': senderToken,
        'senderName': me.displayName ?? '',
      });

      _messageController.clear(); // will also disable send button via listener
      _scrollToBottom();

      // If we opened in lazy mode, start listening after first send
      if (widget.lazyCreate && !_conversationLive) {
        setState(() => _conversationLive = true);
        _markConversationAsRead(); // we’re now in the thread
      }
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: ${e.message}')),
      );
    }
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

  // ───────────────────────────────── report dialog
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

  // ───────────────────────────────── AppBar
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
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
            gradient:
                LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFFA726)]),
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
                    fontWeight: FontWeight.bold),
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
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'block') {
                await BlockService.instance.block(_otherUserId);
                _iBlockedThem = true;
                if (mounted) setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked')));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'block', child: Text('Block user')),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────── UI
  @override
  Widget build(BuildContext context) {
    // blocked overrides
    if (_iBlockedThem) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text('You blocked this user.')),
      );
    }
    if (_theyBlockedMe) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(
            child: Text('Chat unavailable: you have been blocked.')),
      );
    }

    // Lazy mode: don’t attach a Firestore listener until the first send
    // or until our watcher sees the conversation exists.
    if (!_conversationLive) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            const Expanded(
              child: Center(
                child: Text(
                  'Say hi 👋 — your conversation will start after you send.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            _buildInputBar(),
          ],
        ),
      );
    }

    final msgsQuery = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
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
          _buildInputBar(),
        ],
      ),
    );
  }

  // ───────────────────────────────── widget helpers
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
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  // ~5 lines max height; adjust if you want more
                  maxHeight: 160,
                ),
                child: Scrollbar(
                  child: TextField(
                    controller: _messageController,
                    keyboardType: TextInputType.multiline,
                    textInputAction:
                        TextInputAction.newline, // RETURN = newline
                    minLines: 1,
                    maxLines: null, // <-- allows wrapping / vertical growth
                    expands: false, // <-- IMPORTANT: don't set this to true
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Type a message…',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(
                Icons.send,
                color: _canSend ? Colors.blueAccent : Colors.grey,
              ),
              onPressed: _canSend ? _sendMessage : null,
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────── profile nav
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
