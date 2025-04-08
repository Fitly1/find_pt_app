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
  bool _isOtherTrainer =
      false; // true if other user's data was found in trainer_profiles
  bool _hasListing = false; // true if the conversation has a listing attached

  @override
  void initState() {
    super.initState();
    _loadConversationData();
    _markConversationAsRead();
  }

  /// Mark the conversation as read by removing the current user's UID from unreadBy.
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
      debugPrint(
          "Conversation ${widget.conversationId} marked as read for ${currentUser.uid}.");
    } catch (e) {
      debugPrint("Error marking conversation as read: $e");
    }
  }

  /// Fetch conversation doc, determine listing context, find the "other" participant, then fetch their profile.
  Future<void> _loadConversationData() async {
    try {
      final conversationDoc = await FirebaseFirestore.instance
          .collection("conversations")
          .doc(widget.conversationId)
          .get();

      if (!conversationDoc.exists) {
        debugPrint("Conversation ${widget.conversationId} does not exist.");
        return;
      }

      final data = conversationDoc.data() as Map<String, dynamic>;

      // Set listing flag based on presence of a listingId field.
      setState(() {
        _hasListing = data["listingId"] != null &&
            (data["listingId"] as String).isNotEmpty;
      });

      final List<dynamic> participants = data["participants"] ?? [];

      if (participants.isEmpty) {
        debugPrint(
            "No participants found in conversation ${widget.conversationId}.");
        return;
      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) {
        debugPrint("No current user logged in.");
        return;
      }

      // Determine the other user's UID.
      _otherUserId = (participants.first == currentUid)
          ? participants.last
          : participants.first;
      debugPrint("Other user ID: $_otherUserId");

      // Attempt to fetch from trainer_profiles first.
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(_otherUserId)
          .get();

      if (userDoc.exists) {
        _isOtherTrainer = true;
      } else {
        // Fallback to users collection.
        userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(_otherUserId)
            .get();
        _isOtherTrainer = false;
      }

      if (!userDoc.exists) {
        debugPrint("No profile document found for user $_otherUserId.");
        setState(() {
          _otherDisplayName = "Unknown User";
          _otherImageUrl = "";
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      setState(() {
        // Prefer displayName if available; otherwise, build from firstName + lastName.
        _otherDisplayName = userData["displayName"] ??
            ("${userData["firstName"] ?? ""} ${userData["lastName"] ?? ""}")
                .trim();
        _otherImageUrl = userData["profileImageUrl"] ?? "";
      });
      debugPrint("Loaded other user's display name: $_otherDisplayName");
    } catch (e) {
      debugPrint("Error loading conversation data: $e");
    }
  }

  /// Navigate based on listing context and user role.
  void _navigateToOtherProfile() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _otherUserId == null) return;

    // If the other user is a trainer, then current user is a customer.
    if (_isOtherTrainer) {
      // For customers: always go to trainer profile page.
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
      // Otherwise, current user is a personal trainer and the other is a customer.
      if (_hasListing) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MarketplacePage(),
          ),
        );
      } else {
        // No listing exists. Show a pop-up message.
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

  /// Send a new message and update conversation doc.
  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      debugPrint("Attempted to send an empty message.");
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("No current user logged in when sending a message.");
      return;
    }

    debugPrint(
        "Sending message: '$messageText' from user ${currentUser.uid} in conversation ${widget.conversationId}");
    debugPrint("Recipient (_otherUserId): $_otherUserId");

    // ADDING 'recipientId' FIELD HERE
    final messageData = {
      "senderId": currentUser.uid,
      "recipientId": _otherUserId, // <--- NEW FIELD
      "message": messageText,
      "timestamp": FieldValue.serverTimestamp(),
    };

    try {
      // 1. Add the message to the subcollection.
      await FirebaseFirestore.instance
          .collection("conversations")
          .doc(widget.conversationId)
          .collection("messages")
          .add(messageData);

      // 2. Update the conversation doc:
      //    - lastMessage
      //    - timestamp
      //    - add the OTHER user's UID to `unreadBy`
      if (_otherUserId != null && _otherUserId != currentUser.uid) {
        debugPrint(
            "Adding $_otherUserId to unreadBy for conversation ${widget.conversationId}");
        await FirebaseFirestore.instance
            .collection("conversations")
            .doc(widget.conversationId)
            .update({
          "lastMessage": messageText,
          "timestamp": FieldValue.serverTimestamp(),
          "unreadBy": FieldValue.arrayUnion([_otherUserId]),
        });
      } else {
        debugPrint(
            "No valid recipient. Updating doc without unreadBy arrayUnion.");
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

  /// Scroll the message list to the bottom.
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

  @override
  Widget build(BuildContext context) {
    final messagesQuery = FirebaseFirestore.instance
        .collection("conversations")
        .doc(widget.conversationId)
        .collection("messages")
        .orderBy("timestamp", descending: false);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          actions: [
            // Button to navigate to the other participant's profile or listing
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.white),
              onPressed: _navigateToOtherProfile,
            ),
          ],
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
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: _otherImageUrl.isNotEmpty
                          ? NetworkImage(_otherImageUrl)
                          : const AssetImage("assets/default_profile.png")
                              as ImageProvider,
                      onBackgroundImageError: (error, stackTrace) {
                        debugPrint(
                            "Error loading image for user $_otherUserId: $error");
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _otherDisplayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("Error retrieving messages: ${snapshot.error}");
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  debugPrint("Waiting for messages...");
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                debugPrint(
                    "Retrieved ${docs.length} messages for conversation ${widget.conversationId}");
                if (docs.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }
                // Auto-scroll when new messages arrive.
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

                    // Format timestamp
                    String timeString = "";
                    if (ts != null) {
                      final DateTime dt = ts.toDate();
                      timeString = DateFormat("h:mm a").format(dt);
                    } else {
                      debugPrint(
                          "Message ${docs[index].id} missing timestamp.");
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
          // Message input field
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Build a single message bubble with the message text and timestamp.
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

  /// Build the input field and send button.
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
}
