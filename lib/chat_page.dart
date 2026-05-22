// lib/chat_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'marketplace_page.dart';
import 'trainer_home_page.dart';
import 'services/block_service.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _surfaceRaised = Color(0xFF20242C);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _canSend = false;

  late final String _otherUserId;
  String _otherDisplayName = 'Loading...';
  String _otherImageUrl = '';
  bool _isOtherTrainer = false;
  bool _hasListing = false;

  bool _iBlockedThem = false;
  bool _theyBlockedMe = false;

  bool _conversationLive = false;

  StreamSubscription<DocumentSnapshot>? _blockSub;
  StreamSubscription<DocumentSnapshot>? _convWatchSub;

  @override
  void initState() {
    super.initState();

    _otherUserId = widget.otherUserId;
    _conversationLive = !widget.lazyCreate;

    _messageController.addListener(_handleMessageChanged);

    _loadParticipantData();

    if (!widget.lazyCreate) {
      _markConversationAsRead();
      _loadConversationExtras();
    } else {
      final convRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId);

      _convWatchSub = convRef.snapshots().listen((snap) {
        if (!mounted) return;

        if (snap.exists && !_conversationLive) {
          _conversationLive = true;

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

  void _handleMessageChanged() {
    if (!mounted) return;

    final next = _messageController.text.trim().isNotEmpty;

    if (next != _canSend) {
      setState(() => _canSend = next);
    }
  }

  @override
  void dispose() {
    if (_conversationLive) {
      _maybeDeleteEmptyConversation();
    }

    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _blockSub?.cancel();
    _convWatchSub?.cancel();

    super.dispose();
  }

  Future<void> _checkBlockStatus() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    _iBlockedThem = await BlockService.instance.iBlocked(_otherUserId);
    _theyBlockedMe = await BlockService.instance.blockedMe(_otherUserId);

    _blockSub = FirebaseFirestore.instance
        .collection('users')
        .doc(_otherUserId)
        .collection('blocked')
        .doc(me.uid)
        .snapshots()
        .listen((doc) {
      _theyBlockedMe = doc.exists;
      if (mounted) setState(() {});
    });

    if (mounted) setState(() {});
  }

  Future<void> _markConversationAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'unreadBy': FieldValue.arrayRemove([currentUser.uid]),
      });
    } catch (_) {}
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
    } catch (_) {}
  }

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
        if (!mounted) return;

        setState(() {
          _otherDisplayName = 'Unknown User';
          _otherImageUrl = '';
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      final displayName = (userData['displayName'] ?? '').toString().trim();
      final firstName = (userData['firstName'] ?? '').toString().trim();
      final lastName = (userData['lastName'] ?? '').toString().trim();

      final fallbackName = '$firstName $lastName'.trim();

      if (!mounted) return;

      setState(() {
        _otherDisplayName = displayName.isNotEmpty
            ? displayName
            : fallbackName.isNotEmpty
                ? fallbackName
                : 'Unknown User';

        _otherImageUrl = (userData['profileImageUrl'] ?? '').toString();
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

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
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    if (_iBlockedThem) {
      _showPremiumSnackBar('You blocked this user.', error: true);
      return;
    }

    if (_theyBlockedMe) {
      _showPremiumSnackBar('This user has blocked you.', error: true);
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

    try {
      await convRef.update({
        'lastMessage': text,
        'timestamp': now,
        if (otherUid != myUid) 'unreadBy': FieldValue.arrayUnion([otherUid]),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
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
        _showPremiumSnackBar(
          "Couldn't start chat. Please try again.",
          error: true,
        );
        return;
      }
    }

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

      _messageController.clear();
      _scrollToBottom();

      if (widget.lazyCreate && !_conversationLive) {
        setState(() => _conversationLive = true);
        _markConversationAsRead();
      }
    } on FirebaseException catch (e) {
      _showPremiumSnackBar(
        e.message == null ? 'Message failed to send.' : 'Send failed.',
        error: true,
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showReportDialog() async {
    final reasonCtrl = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogCtx) {
        return AnimatedPadding(
          padding: MediaQuery.of(dialogCtx).viewInsets +
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                  child: SingleChildScrollView(
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
                            Icons.flag_outlined,
                            color: _danger,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Report user?',
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
                          'Tell us what happened. Fitly will review the report.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: reasonCtrl,
                          maxLines: 4,
                          cursorColor: _gold,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.35,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Why are you reporting this user?',
                            hintStyle: const TextStyle(
                              color: _textMuted,
                              fontSize: 15.5,
                            ),
                            filled: true,
                            fillColor: _ink,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: _line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: _gold,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: _SecondaryButton(
                                label: 'Cancel',
                                icon: null,
                                onPressed: () => Navigator.pop(dialogCtx, null),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DangerButton(
                                label: 'Submit',
                                icon: Icons.flag_outlined,
                                onPressed: () {
                                  final value = reasonCtrl.text.trim();
                                  if (value.isEmpty) return;
                                  Navigator.pop(dialogCtx, value);
                                },
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
          ),
        );
      },
    );

    reasonCtrl.dispose();

    if (reason == null || reason.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedBy': currentUser.uid,
        'reportedItemId': _otherUserId,
        'reportedType': _isOtherTrainer ? 'trainer' : 'customer',
        'reason': reason.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      final countSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('reportedItemId', isEqualTo: _otherUserId)
          .where(
            'reportedType',
            isEqualTo: _isOtherTrainer ? 'trainer' : 'customer',
          )
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

      _showPremiumSnackBar('User reported');
    } catch (_) {
      if (!mounted) return;

      _showPremiumSnackBar(
        'Could not submit report.',
        error: true,
      );
    }
  }

  Future<void> _blockUser() async {
    await BlockService.instance.block(_otherUserId);

    _iBlockedThem = true;

    if (mounted) setState(() {});

    _showPremiumSnackBar('User blocked');
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      elevation: 0,
      backgroundColor: _ink,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          _AppBarAvatar(imageUrl: _otherImageUrl),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              _otherDisplayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.flag_outlined,
            color: Colors.white,
            size: 23,
          ),
          tooltip: 'Report user',
          onPressed: _showReportDialog,
        ),
        IconButton(
          icon: const Icon(
            Icons.account_circle_outlined,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'View profile',
          onPressed: _navigateToOtherProfile,
        ),
        PopupMenuButton<String>(
          color: _surfaceRaised,
          elevation: 8,
          icon: const Icon(
            Icons.more_vert_rounded,
            color: Colors.white,
          ),
          onSelected: (val) async {
            if (val == 'block') {
              await _blockUser();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: const [
                  Icon(
                    Icons.block_rounded,
                    color: _danger,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Block user',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _line),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_iBlockedThem) {
      return Scaffold(
        backgroundColor: _ink,
        appBar: _buildAppBar(),
        body: const _BlockedState(
          icon: Icons.block_rounded,
          title: 'You blocked this user',
          message: 'You can’t send messages in this conversation.',
        ),
      );
    }

    if (_theyBlockedMe) {
      return Scaffold(
        backgroundColor: _ink,
        appBar: _buildAppBar(),
        body: const _BlockedState(
          icon: Icons.lock_outline_rounded,
          title: 'Chat unavailable',
          message: 'You can’t message this user right now.',
        ),
      );
    }

    if (!_conversationLive) {
      return Scaffold(
        backgroundColor: _ink,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            const Expanded(
              child: _StartChatState(),
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
      backgroundColor: _ink,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: msgsQuery.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorState(error: snap.error);
                }

                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _gold),
                  );
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return const _EmptyChatState();
                }

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;

                    final text = (data['message'] ?? '').toString();
                    final senderId = (data['senderId'] ?? '').toString();

                    final isMe =
                        senderId == FirebaseAuth.instance.currentUser?.uid;

                    final ts = data['timestamp'] as Timestamp?;
                    final timeStr = ts == null
                        ? ''
                        : DateFormat('h:mm a').format(ts.toDate());

                    return _buildBubble(
                      message: text,
                      isMe: isMe,
                      time: timeStr,
                    );
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

  Widget _buildBubble({
    required String message,
    required bool isMe,
    required String time,
  }) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 5),
      bottomRight: Radius.circular(isMe ? 5 : 18),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            decoration: BoxDecoration(
              color: isMe ? _gold : _surfaceRaised,
              borderRadius: radius,
              border: Border.all(
                color: isMe
                    ? _gold.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.black : Colors.white,
                fontSize: 16.5,
                height: 1.32,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 6, right: 6),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isMe
                      ? _gold.withValues(alpha: 0.85)
                      : _textMuted.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
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
        decoration: const BoxDecoration(
          color: _surface,
          border: Border(
            top: BorderSide(color: _line),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 160,
                ),
                child: TextField(
                  controller: _messageController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: null,
                  expands: false,
                  cursorColor: _gold,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: const TextStyle(
                      color: _textMuted,
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: _ink,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: _line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: _gold,
                        width: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _canSend ? _gold : _surfaceRaised,
                border: Border.all(
                  color: _canSend
                      ? _gold.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  if (_canSend)
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _canSend ? Colors.black : _textMuted,
                  size: 22,
                ),
                onPressed: _canSend ? _sendMessage : null,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        _showNoListingDialog();
      }
    }
  }

  Future<void> _showNoListingDialog() async {
    await showDialog<void>(
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
                          color: _gold.withValues(alpha: 0.11),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: _gold,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'No listing found',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This customer has not created a listing. You can keep chatting to understand their training needs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: _SecondaryButton(
                          label: 'OK',
                          icon: null,
                          onPressed: () => Navigator.pop(dialogCtx),
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
                  fontSize: 14.5,
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

/* ───────────────── UI widgets ───────────────── */

class _AppBarAvatar extends StatelessWidget {
  final String imageUrl;

  const _AppBarAvatar({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = imageUrl.isNotEmpty
        ? NetworkImage(imageUrl)
        : const AssetImage('assets/default_profile.png') as ImageProvider;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_gold, Color(0xFF6F5422)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: CircleAvatar(
        backgroundColor: _surfaceRaised,
        backgroundImage: imageProvider,
      ),
    );
  }
}

class _StartChatState extends StatelessWidget {
  const _StartChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
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
                  Icons.waving_hand_rounded,
                  color: _gold,
                  size: 35,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Start the conversation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send a message and your chat will begin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 15.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No messages yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BlockedState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _BlockedState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: _danger,
                size: 46,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 15.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
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
                  fontSize: 14,
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
          fontSize: 15,
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
          fontSize: 15,
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
