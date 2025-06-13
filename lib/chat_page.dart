import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'marketplace_page.dart';
import 'trainer_home_page.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;

  const ChatPage({super.key, required this.conversationId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _otherUserId;
  String _otherDisplayName = "Loading...";
  String _otherImageUrl = "";
  bool _isOtherTrainer = false;
  bool _hasListing = false;

  @override
  void initState() {
    super.initState();
    _loadConversationData();
    _markConversationAsRead();
  }

  Future<void> _markConversationAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection("conversations")
          .doc(widget.conversationId)
          .update({
        "unreadBy": FieldValue.arrayRemove([currentUser.uid])
      });
    } catch (e) {
      debugPrint("Error marking conversation as read: $e");
    }
  }

  Future<void> _loadConversationData() async {
    try {
      final conversationDoc = await FirebaseFirestore.instance
          .collection("conversations")
          .doc(widget.conversationId)
          .get();

      if (!conversationDoc.exists) return;

      final data = conversationDoc.data() as Map<String, dynamic>;

      setState(() {
        _hasListing = data["listingId"] != null &&
            (data["listingId"] as String).isNotEmpty;
      });

      final List<dynamic> participants = data["participants"] ?? [];
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      _otherUserId = (participants.first == currentUid)
          ? participants.last
          : participants.first;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(_otherUserId)
          .get();

      if (userDoc.exists) {
        _isOtherTrainer = true;
      } else {
        userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(_otherUserId)
            .get();
        _isOtherTrainer = false;
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
        _otherDisplayName = userData["displayName"] ??
            ("${userData["firstName"] ?? ""} ${userData["lastName"] ?? ""}")
                .trim();
        _otherImageUrl = userData["profileImageUrl"] ?? "";
      });
    } catch (e) {
      debugPrint("Error loading conversation data: $e");
    }
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final messageData = {
      "senderId": currentUser.uid,
      "recipientId": _otherUserId,
      "message": messageText,
      "timestamp": FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection("conversations")
          .doc(widget.conversationId)
          .collection("messages")
          .add(messageData);

      // Update last message
      if (_otherUserId != null && _otherUserId != currentUser.uid) {
        await FirebaseFirestore.instance
            .collection("conversations")
            .doc(widget.conversationId)
            .update({
          "lastMessage": messageText,
          "timestamp": FieldValue.serverTimestamp(),
          "unreadBy": FieldValue.arrayUnion([_otherUserId]),
        });
      } else {
        await FirebaseFirestore.instance
            .collection("conversations")
            .doc(widget.conversationId)
            .update({
          "lastMessage": messageText,
          "timestamp": FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
    }

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

  void _showReportDialog() {
    final TextEditingController reasonController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report User"),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Why are you reporting this user?",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            child: const Text("Submit"),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              Navigator.of(context).pop();

              final currentUser = FirebaseAuth.instance.currentUser;
              if (_otherUserId == null || currentUser == null) return;

              await FirebaseFirestore.instance.collection('reports').add({
                'reportedBy': currentUser.uid,
                'reportedItemId': _otherUserId,
                'reportedType': _isOtherTrainer ? 'trainer' : 'customer',
                'reason': reason,
                'timestamp': FieldValue.serverTimestamp(),
              });

              final reportSnapshot = await FirebaseFirestore.instance
                  .collection('reports')
                  .where('reportedItemId', isEqualTo: _otherUserId)
                  .where('reportedType',
                      isEqualTo: _isOtherTrainer ? 'trainer' : 'customer')
                  .get();

              final reportCount = reportSnapshot.docs.length;
              final targetCollection =
                  _isOtherTrainer ? 'trainer_profiles' : 'users';

              await FirebaseFirestore.instance
                  .collection(targetCollection)
                  .doc(_otherUserId)
                  .set({
                'reportCount': reportCount,
                if (reportCount >= 3) 'flagged': true,
              }, SetOptions(merge: true));

              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text("User reported.")),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesQuery = FirebaseFirestore.instance
        .collection("conversations")
        .doc(widget.conversationId)
        .collection("messages")
        .orderBy("timestamp", descending: false);

    return Scaffold(
      // ---------- HEADER ----------
      appBar: PreferredSize(
        // trim vertical space: toolbar height + a few pixels
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleSpacing: 0,
          // native back arrow now lives in the leading slot
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          leadingWidth: 40, // narrower than default 56
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 255, 167, 38),
                  Color.fromARGB(255, 255, 167, 38)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: _otherImageUrl.isNotEmpty
                    ? NetworkImage(_otherImageUrl)
                    : const AssetImage("assets/default_profile.png")
                        as ImageProvider,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _otherDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22, // bumped back up
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
      // ---------- END HEADER ----------
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String messageText = data["message"] ?? "";
                    final String senderId = data["senderId"] ?? "";
                    final Timestamp? ts = data["timestamp"];
                    final bool isMe =
                        senderId == FirebaseAuth.instance.currentUser?.uid;

                    String timeString = "";
                    if (ts != null) {
                      final DateTime dt = ts.toDate();
                      timeString = DateFormat("h:mm a").format(dt);
                    }

                    return _buildMessageBubble(
                      messageText: messageText,
                      isMe: isMe,
                      time: timeString,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String messageText,
    required bool isMe,
    required String time,
  }) {
    final BorderRadius bubbleRadius = BorderRadius.only(
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
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            decoration: BoxDecoration(
              color: isMe ? Colors.blueAccent : Colors.grey[200],
              borderRadius: bubbleRadius,
            ),
            child: Text(
              messageText,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ),
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
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
                hintText: "Type something...",
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

  void _navigateToOtherProfile() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _otherUserId == null) return;

    if (_isOtherTrainer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrainerHomePage(
            trainerData: {
              "uid": _otherUserId,
              "displayName": _otherDisplayName,
              "profileImageUrl": _otherImageUrl,
            },
            viewAsCustomer: true,
          ),
        ),
      );
    } else {
      if (_hasListing) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MarketplacePage(),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("No Listing Found"),
              content: const Text(
                  "Customer didn't create a listing. Chat to clarify their training needs?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      }
    }
  }
}
