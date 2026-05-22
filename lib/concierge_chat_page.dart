// lib/concierge_chat_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/* ───────────────── Fitly premium colours ───────────────── */

const Color _ink = Color(0xFF07080A);
const Color _surface = Color(0xFF111318);
const Color _surfaceRaised = Color(0xFF20242C);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _textMuted = Color(0xFFA6ADB8);
const Color _danger = Color(0xFFE25252);

class ConciergeChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final bool lazyCreate;

  const ConciergeChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    this.lazyCreate = false,
  });

  @override
  State<ConciergeChatPage> createState() => _ConciergeChatPageState();
}

class _ConciergeChatPageState extends State<ConciergeChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _conversationSub;

  bool _canSend = false;
  bool _loadingConversation = true;
  bool _conversationLive = false;
  bool _isAdminViewer = false;
  bool _isConciergeView = true;

  String _chatPeerUid = '';
  String _customerId = '';
  String _assignedAdminId = '';

  String _appBarTitle = 'Fitly Concierge';
  String _appBarSubtitle = 'We’ll help you find the right trainer.';
  String _customerName = 'Customer';
  String _customerImageUrl = '';

  String _conciergeName = 'Fitly Concierge';
  String _conciergeAvatarUrl = '';

  String _goal = '';
  String _location = '';
  String _budget = '';

  @override
  void initState() {
    super.initState();

    _chatPeerUid = widget.otherUserId;
    _conversationLive = !widget.lazyCreate;

    _messageController.addListener(_handleMessageChanged);

    _listenToConversation();
    _markConversationAsRead();
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _conversationSub?.cancel();
    super.dispose();
  }

  void _handleMessageChanged() {
    if (!mounted) return;

    final next = _messageController.text.trim().isNotEmpty;
    if (next != _canSend) {
      setState(() => _canSend = next);
    }
  }

  void _listenToConversation() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => _loadingConversation = false);
      return;
    }

    final convRef = _firestore.collection('conversations').doc(
          widget.conversationId,
        );

    _conversationSub = convRef.snapshots().listen(
      (snap) async {
        if (!mounted) return;

        if (!snap.exists) {
          setState(() {
            _loadingConversation = false;
            _conversationLive = !widget.lazyCreate;
            _chatPeerUid = widget.otherUserId;
            _isAdminViewer = false;
            _isConciergeView = true;
            _appBarTitle = _conciergeName;
            _appBarSubtitle = 'We’ll help you find the right trainer.';
          });
          return;
        }

        final data = snap.data() ?? <String, dynamic>{};
        await _applyConversationData(data, user.uid);

        if (!mounted) return;

        setState(() {
          _loadingConversation = false;
          _conversationLive = true;
        });

        _markConversationAsRead();
        _scrollToBottom();
      },
      onError: (e) {
        debugPrint('Concierge conversation listen error: $e');

        if (!mounted) return;

        setState(() => _loadingConversation = false);
      },
    );
  }

  Future<void> _applyConversationData(
    Map<String, dynamic> data,
    String currentUid,
  ) async {
    final adminActive = await _isCurrentUserAdmin(currentUid);

    final participants = data['participants'];
    final participantUids = participants is List
        ? participants
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    _assignedAdminId = _stringFrom(
      data,
      ['assignedAdminId', 'conciergeAdminUid', 'adminId'],
    );

    _customerId = _stringFrom(data, ['customerId']);

    if (_customerId.isEmpty) {
      for (final uid in participantUids) {
        if (uid != currentUid && uid != _assignedAdminId) {
          _customerId = uid;
          break;
        }
      }
    }

    if (_assignedAdminId.isEmpty) {
      for (final uid in participantUids) {
        if (uid != _customerId) {
          _assignedAdminId = uid;
          break;
        }
      }
    }

    _conciergeName = _stringFrom(
      data,
      ['conciergeName'],
      fallback: 'Fitly Concierge',
    );

    _conciergeAvatarUrl = _stringFrom(data, ['conciergeAvatarUrl']);

    _goal = _stringFrom(
      data,
      ['conciergeGoal', 'goal', 'fitnessGoal'],
    );

    _location = _stringFrom(
      data,
      ['conciergeLocation', 'location', 'suburb'],
    );

    _budget = _stringFrom(
      data,
      ['conciergeBudget', 'budget'],
    );

    _customerName = _stringFrom(
      data,
      ['customerName', 'customerDisplayName'],
      fallback: 'Customer',
    );

    final adminByAssignment =
        _assignedAdminId.isNotEmpty && currentUid == _assignedAdminId;
    final adminByParticipants = adminActive &&
        _customerId.isNotEmpty &&
        currentUid != _customerId &&
        participantUids.contains(currentUid);

    _isAdminViewer = adminByAssignment || adminByParticipants;

    if (_isAdminViewer) {
      _isConciergeView = false;
      _chatPeerUid = _customerId.isNotEmpty ? _customerId : widget.otherUserId;

      await _loadCustomerPublicData(_chatPeerUid);

      _appBarTitle = _customerName;
      _appBarSubtitle = _buildAdminSubtitle();
    } else {
      _isConciergeView = true;
      _chatPeerUid =
          _assignedAdminId.isNotEmpty ? _assignedAdminId : widget.otherUserId;

      _appBarTitle = _conciergeName;
      _appBarSubtitle = 'We’ll help you find the right trainer.';
    }
  }

  Future<bool> _isCurrentUserAdmin(String uid) async {
    try {
      final snap = await _firestore.collection('admins').doc(uid).get();
      final data = snap.data() ?? <String, dynamic>{};
      return data['active'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadCustomerPublicData(String customerUid) async {
    if (customerUid.isEmpty) return;

    try {
      final snap = await _firestore.collection('users').doc(customerUid).get();

      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};

      final displayName = _stringFrom(data, ['displayName']);
      final firstName = _stringFrom(data, ['firstName']);
      final lastName = _stringFrom(data, ['lastName']);
      final fallbackName = '$firstName $lastName'.trim();

      final nextName = displayName.isNotEmpty
          ? displayName
          : fallbackName.isNotEmpty
              ? fallbackName
              : _customerName;

      _customerName = nextName.isNotEmpty ? nextName : 'Customer';

      _customerImageUrl = _stringFrom(
        data,
        [
          'profileImageUrl',
          'photoURL',
          'photoUrl',
          'avatarUrl',
        ],
      );
    } catch (e) {
      debugPrint('Could not load customer public data: $e');
    }
  }

  String _buildAdminSubtitle() {
    final parts = <String>[
      if (_goal.isNotEmpty) _goal,
      if (_location.isNotEmpty) _location,
      if (_budget.isNotEmpty) _budget,
    ];

    if (parts.isEmpty) return 'Concierge request';
    return parts.join(' • ');
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

  Future<void> _markConversationAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .set({
        'unreadBy': FieldValue.arrayRemove([currentUser.uid]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    if (_chatPeerUid.isEmpty || _chatPeerUid == me.uid) {
      _showPremiumSnackBar(
        'Could not find the other person in this chat.',
        error: true,
      );
      return;
    }

    final myUid = me.uid;
    final otherUid = _chatPeerUid;
    final now = FieldValue.serverTimestamp();

    final convRef = _firestore.collection('conversations').doc(
          widget.conversationId,
        );

    final msgsRef = convRef.collection('messages');

    try {
      final existing = await convRef.get();

      if (!existing.exists) {
        final parts = (myUid.compareTo(otherUid) < 0)
            ? [myUid, otherUid]
            : [otherUid, myUid];

        await convRef.set({
          'participants': parts,
          'isConcierge': true,
          'assignedAdminId': _isAdminViewer ? myUid : otherUid,
          'customerId': _isAdminViewer ? otherUid : myUid,
          'conciergeName': _conciergeName,
          'conciergeAvatarUrl': _conciergeAvatarUrl,
          'lastMessage': text,
          'timestamp': now,
          'updatedAt': now,
          'createdAt': now,
          'status': 'open',
          'unreadBy': [otherUid],
        });
      } else {
        await convRef.set({
          'lastMessage': text,
          'timestamp': now,
          'updatedAt': now,
          'status': 'open',
          'unreadBy': FieldValue.arrayUnion([otherUid]),
        }, SetOptions(merge: true));
      }

      final senderToken = await FirebaseMessaging.instance.getToken();

      await msgsRef.add({
        'senderId': myUid,
        'recipientId': otherUid,
        'message': text,
        'timestamp': now,
        'senderDeviceToken': senderToken,
        'senderName':
            _isAdminViewer ? _conciergeName : (me.displayName ?? _customerName),
        'senderType': _isAdminViewer ? 'concierge' : 'customer',
        'displayName': _isAdminViewer ? _conciergeName : _customerName,
      });

      _messageController.clear();
      _scrollToBottom();

      if (widget.lazyCreate && !_conversationLive && mounted) {
        setState(() => _conversationLive = true);
      }
    } on FirebaseException catch (e) {
      debugPrint('Concierge send failed: ${e.code} ${e.message}');

      _showPremiumSnackBar(
        e.message == null ? 'Message failed to send.' : 'Send failed.',
        error: true,
      );
    } catch (e) {
      debugPrint('Concierge send failed: $e');

      _showPremiumSnackBar(
        'Message failed to send.',
        error: true,
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      toolbarHeight: 76,
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
          _ConciergeAppBarAvatar(
            isConcierge: _isConciergeView,
            networkImageUrl:
                _isConciergeView ? _conciergeAvatarUrl : _customerImageUrl,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appBarTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                if (_appBarSubtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _appBarSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!_isAdminViewer)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.26),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: _gold,
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Fitly',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _line),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: _ink,
      body: Center(
        child: CircularProgressIndicator(color: _gold),
      ),
    );
  }

  Widget _buildMissingLoginState() {
    return Scaffold(
      backgroundColor: _ink,
      appBar: _buildAppBar(),
      body: const _CenteredStateCard(
        icon: Icons.login_rounded,
        title: 'Login required',
        message: 'Log in to continue chatting with Fitly Concierge.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return _buildMissingLoginState();
    }

    if (_loadingConversation) {
      return _buildLoadingState();
    }

    if (!_conversationLive) {
      return Scaffold(
        backgroundColor: _ink,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(
              child: _StartConciergeState(
                isAdminViewer: _isAdminViewer,
              ),
            ),
            _buildInputBar(),
          ],
        ),
      );
    }

    final msgsQuery = _firestore
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
          if (!_isAdminViewer) const _CustomerTrustBanner(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    final data = docs[i].data();

                    final text = (data['message'] ?? '').toString();
                    final senderId = (data['senderId'] ?? '').toString();
                    final senderType = (data['senderType'] ?? '').toString();

                    final isMe =
                        senderId == FirebaseAuth.instance.currentUser?.uid;

                    final isConciergeMessage = senderType == 'concierge' ||
                        senderId == _assignedAdminId;

                    final ts = data['timestamp'] as Timestamp?;
                    final timeStr = ts == null
                        ? ''
                        : DateFormat('h:mm a').format(ts.toDate());

                    return _buildBubble(
                      message: text,
                      isMe: isMe,
                      time: timeStr,
                      showConciergeLabel:
                          !_isAdminViewer && !isMe && isConciergeMessage,
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
    required bool showConciergeLabel,
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
          if (showConciergeLabel) ...[
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: _gold,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _conciergeName,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 12.3,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
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
                constraints: const BoxConstraints(maxHeight: 160),
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
                    hintText: _isAdminViewer
                        ? 'Reply as Fitly Concierge…'
                        : 'Type a message…',
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

class _ConciergeAppBarAvatar extends StatelessWidget {
  final bool isConcierge;
  final String networkImageUrl;

  const _ConciergeAppBarAvatar({
    required this.isConcierge,
    required this.networkImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final ImageProvider fallback = isConcierge
        ? const AssetImage('assets/Fitly2.png')
        : const AssetImage('assets/default_profile.png');

    final ImageProvider provider =
        networkImageUrl.isNotEmpty ? NetworkImage(networkImageUrl) : fallback;

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
        backgroundImage: provider,
        child: isConcierge && networkImageUrl.isEmpty
            ? ClipOval(
                child: Container(
                  color: _ink,
                  padding: const EdgeInsets.all(7),
                  child: Image.asset(
                    'assets/Fitly2.png',
                    fit: BoxFit.contain,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _CustomerTrustBanner extends StatelessWidget {
  const _CustomerTrustBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _surface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _gold.withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: _gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Fitly will review your request and help connect you with a suitable trainer.',
              style: TextStyle(
                color: _textMuted,
                fontSize: 12.8,
                height: 1.32,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartConciergeState extends StatelessWidget {
  final bool isAdminViewer;

  const _StartConciergeState({
    required this.isAdminViewer,
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
                child: Icon(
                  isAdminViewer
                      ? Icons.support_agent_rounded
                      : Icons.waving_hand_rounded,
                  color: _gold,
                  size: 35,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isAdminViewer
                    ? 'Reply as Fitly Concierge'
                    : 'Message Fitly Concierge',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAdminViewer
                    ? 'Your replies will appear to the customer as Fitly Concierge.'
                    : 'Send any extra details about the trainer you are looking for.',
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

class _CenteredStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CenteredStateCard({
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
                color: _gold,
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
