import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart' as chat; // Use alias for ChatPage
import 'bottom_navigation.dart'; // Trainer navigation
import 'bottom_navigation_customers.dart'; // Customer navigation
import 'trainer_home_page.dart';
import 'marketplace_page.dart'; // For customer back navigation
import 'package:intl/intl.dart'; // For formatted time
import 'package:shared_preferences/shared_preferences.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  MessagesPageState createState() => MessagesPageState();
}

class MessagesPageState extends State<MessagesPage> {
  String userRole = 'customer'; // Default role is customer

  @override
  void initState() {
    super.initState();
    loadUserRole();
  }

  Future<void> loadUserRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userRole = prefs.getString("userRole")?.toLowerCase() ?? 'customer';
    });
    debugPrint("MessagesPage: Loaded user role: $userRole");
  }

  /// Returns the appropriate bottom navigation widget based on the user's role.
  Widget _buildBottomNavigation() {
    bool isTrainer = (userRole == 'trainer' ||
        userRole == 'personal trainer' ||
        userRole == 'personaltrainer');

    return isTrainer
        ? const BottomNavigation(currentIndex: 1)
        : const BottomNavigationCustomers(currentIndex: 1);
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("No user found in MessagesPage.");
      return const Scaffold(
        body: Center(child: Text("No user found")),
      );
    }

    final conversationsQuery = FirebaseFirestore.instance
        .collection("conversations")
        .where("participants", arrayContains: currentUser.uid)
        .orderBy("timestamp", descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Messages",
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFFA726), // Brand orange
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28, color: Colors.white),
          onPressed: () {
            bool isTrainer =
                userRole == 'trainer' || userRole == 'personal trainer';
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => isTrainer
                      ? const TrainerHomePage()
                      : const MarketplacePage()),
            );
          },
        ),
      ),
      backgroundColor: Colors.white, // Overall white background
      body: StreamBuilder<QuerySnapshot>(
        stream: conversationsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("Error retrieving conversations: ${snapshot.error}");
            return Center(
              child: Text("Error: ${snapshot.error}",
                  style: const TextStyle(fontSize: 18)),
            );
          }
          if (!snapshot.hasData) {
            debugPrint("Waiting for conversation data...");
            return const Center(child: CircularProgressIndicator());
          }

          final conversationDocs = snapshot.data!.docs;
          if (conversationDocs.isEmpty) {
            debugPrint("No conversations found for user ${currentUser.uid}");
            return const Center(
                child: Text("No conversations yet.",
                    style: TextStyle(fontSize: 18)));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversationDocs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final conversation = conversationDocs[index];
              final data = conversation.data() as Map<String, dynamic>;

              final participants = data["participants"];
              if (participants == null || participants is! List) {
                debugPrint(
                    "Conversation ${conversation.id} has invalid 'participants': $participants");
                return const SizedBox.shrink();
              }

              // Identify the OTHER participant's UID.
              final otherUid = participants.firstWhere(
                (p) => p != currentUser.uid,
                orElse: () => null,
              );

              if (otherUid == null) {
                debugPrint(
                    "Could not find another participant in conversation ${conversation.id}");
                return const SizedBox.shrink();
              }

              final lastMessage = data["lastMessage"] ?? "";
              final dynamic tsValue = data["timestamp"];
              final Timestamp ts =
                  (tsValue is Timestamp) ? tsValue : Timestamp.now();
              final DateTime time = ts.toDate();
              final formattedTime = DateFormat('h:mm a').format(time);

              // Unread indicator logic.
              final unreadData = data["unreadBy"];
              final List<dynamic> unreadList =
                  (unreadData is List) ? unreadData : [];
              final bool isUnread = unreadList.contains(currentUser.uid);

              // Fetch the other participant's data from either "trainer_profiles" or "users"
              return FutureBuilder<Map<String, dynamic>?>(
                future: _fetchOtherUserData(otherUid),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(title: Text("Loading..."));
                  }
                  if (userSnapshot.hasError) {
                    debugPrint(
                        "Error fetching other user doc: ${userSnapshot.error}");
                    return const ListTile(title: Text("Unknown"));
                  }

                  final otherUserData = userSnapshot.data;
                  final String firstName = otherUserData?["firstName"] ?? "";
                  final String lastName = otherUserData?["lastName"] ?? "";
                  final String displayName = ("$firstName $lastName").trim();
                  final nameToShow =
                      displayName.isNotEmpty ? displayName : "Unknown";

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                nameToShow,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: Colors.black87,
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
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            lastMessage,
                            style: TextStyle(
                              fontSize: 18,
                              color: isUnread ? Colors.black87 : Colors.black54,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: Text(
                          formattedTime,
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        onTap: () {
                          FirebaseFirestore.instance
                              .collection("conversations")
                              .doc(conversation.id)
                              .update({
                            "unreadBy":
                                FieldValue.arrayRemove([currentUser.uid])
                          }).then((_) {
                            debugPrint(
                                "Conversation ${conversation.id} marked as read for ${currentUser.uid}");
                          }).catchError((error) {
                            debugPrint(
                                "Error marking conversation as read: $error");
                          });
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => chat.ChatPage(
                                  conversationId: conversation.id),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black, // Black container for bottom nav
        child: _buildBottomNavigation(),
      ),
    );
  }

  /// Attempts to fetch the other user's data from "trainer_profiles" first, then falls back to "users".
  Future<Map<String, dynamic>?> _fetchOtherUserData(String otherUid) async {
    final trainerDoc = await FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(otherUid)
        .get();
    if (trainerDoc.exists) {
      return trainerDoc.data() as Map<String, dynamic>;
    }
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(otherUid)
        .get();
    if (userDoc.exists) {
      return userDoc.data() as Map<String, dynamic>;
    }
    return null;
  }
}
