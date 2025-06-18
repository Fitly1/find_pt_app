import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart' as chat; // Make sure the path is correct
import 'profile_page.dart'; // Update path if needed

/// This color corresponds to (255, 255, 167, 38) in ARGB/Hex (#FFA726).
const kAppBarColor = Color(0xFFFFA726);

/// Map each specialty to a specific color
final Map<String, Color> specialtyColorMap = {
  'Strength Training': Colors.blue,
  'Recovery': Colors.green,
  'Yoga': Colors.purple,
  'Group Training': Colors.orange,
  'Pilates': Colors.pink,
  'Cardio': Colors.red,
  'HIIT': Colors.teal,
  'Endurance': Colors.amber,
  'Aerobics': Colors.cyan,
  'CrossFit': Colors.lime,
  'Dance Fitness': Colors.indigo,
  'Martial Arts': Colors.brown,
  'Weight Loss': Colors.lightGreen,
  'Pre/Post Pregnancy': Colors.deepPurple,
  'Other': Colors.grey,
};

class ListingDetailPage extends StatefulWidget {
  final Map<String, dynamic> listingData;
  final String listingId;

  const ListingDetailPage({
    super.key,
    required this.listingData,
    required this.listingId,
  });

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  bool? _isTrainer; // null = still loading, true/false once role fetched
  bool? _isTrainerActive; // null = not checked, true/false once fetched

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  /* ───────────────────────────────────────── User role helpers ─────────── */

  /// Checks if the current logged-in user has a trainer role.
  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isTrainer = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() => _isTrainer = false);
        return;
      }

      final data = doc.data();
      final role = data?['role']?.toString().toLowerCase() ?? 'customer';
      final isTrainerNow = (role == 'trainer');

      setState(() => _isTrainer = isTrainerNow);

      // If the user is a trainer, also check if they're active.
      if (isTrainerNow) {
        _checkTrainerActiveStatus();
      } else {
        setState(() => _isTrainerActive = false);
      }
    } catch (e) {
      debugPrint("Error fetching user role: $e");
      setState(() => _isTrainer = false);
    }
  }

  /// Checks if the current trainer is active (`isActive == true`).
  Future<void> _checkTrainerActiveStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isTrainerActive = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() => _isTrainerActive = false);
        return;
      }

      final data = doc.data();
      final bool active = data?['isActive'] ?? false;
      setState(() => _isTrainerActive = active);
    } catch (e) {
      debugPrint("Error fetching trainer active status: $e");
      setState(() => _isTrainerActive = false);
    }
  }

  /* ───────────────────────────────────────── Messaging logic ───────────── */

  /// Creates or retrieves a conversation, then opens ChatPage.
  Future<void> _contactCustomer(String customerId) async {
    // If trainer is inactive, show paywall dialog.
    if (_isTrainerActive == false) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Membership Required"),
          content: const Text(
            "Activate your subscription to contact customers.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: const Text("Activate Now"),
            ),
          ],
        ),
      );
      return;
    }

    // Trainer is active; proceed.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final trainerUid = currentUser.uid;

    final conversations =
        FirebaseFirestore.instance.collection("conversations");

    try {
      // Look for an existing conversation.
      QuerySnapshot query = await conversations
          .where("participants", arrayContains: trainerUid)
          .get();

      String? conversationId;
      for (var doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final participants = (data["participants"] as List<dynamic>);
        if (participants.contains(customerId) &&
            participants.contains(trainerUid)) {
          conversationId = doc.id;
          break;
        }
      }

      // Create conversation if none found.
      if (conversationId == null) {
        DocumentReference newConv = await conversations.add({
          "participants": [trainerUid, customerId],
          "lastMessage": "",
          "timestamp": FieldValue.serverTimestamp(),
          "unreadBy": [customerId],
        });
        conversationId = newConv.id;
      }

      if (!mounted) return;

      // ─── Navigation call with the REQUIRED otherUserId argument ─────────
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => chat.ChatPage(
            conversationId: conversationId!,
            otherUserId: customerId, // ← pass the correct customer UID here
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error contacting customer: $e");
    }
  }

  /* ─────────────────────────────────────────── UI ──────────────────────── */

  @override
  Widget build(BuildContext context) {
    final listingData = widget.listingData;

    // Firestore fields
    final String title = listingData["title"] ?? "No title";
    final String description = listingData["description"] ?? "";
    final String location = listingData["location"] ?? "";
    final List<dynamic> specialtiesList =
        (listingData["specialties"] as List<dynamic>?) ?? [];
    final String trainingMethod =
        listingData["trainingMethod"] ?? "Not specified";

    final Timestamp? createdAtTs = listingData["createdAt"] as Timestamp?;
    final Timestamp? ts = createdAtTs ?? listingData["timestamp"] as Timestamp?;
    final String formattedTime = (ts != null)
        ? DateFormat('dd MMM yyyy').format(ts.toDate())
        : "Unknown date";

    final String customerUid = listingData["userId"] ?? "";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: kAppBarColor,
        elevation: 0,
      ),
      body: (_isTrainer == null)
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Curved orange background
                Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    color: kAppBarColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      Card(
                        margin: const EdgeInsets.only(bottom: 24),
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Description
                              _buildDetailRow(
                                icon: Icons.description,
                                label: "Description",
                                value: description,
                              ),
                              const SizedBox(height: 16),

                              // Location
                              _buildDetailRow(
                                icon: Icons.location_on,
                                label: "Location",
                                value: location,
                              ),
                              const SizedBox(height: 16),

                              // Specialties
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.list_alt,
                                      size: 26, color: kAppBarColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Specialties:",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        _buildSpecialtyChips(specialtiesList),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Training Method
                              _buildDetailRow(
                                icon: Icons.fitness_center,
                                label: "Training Method",
                                value: trainingMethod,
                              ),
                              const SizedBox(height: 16),

                              // Posted date
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 22, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Posted on: $formattedTime",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Contact button (trainers only)
                              if (_isTrainer == true) ...[
                                if (_isTrainerActive == null)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.message,
                                          size: 28, color: Colors.white),
                                      label: const Text(
                                        "Contact Customer",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kAppBarColor,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _contactCustomer(customerUid),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /* ───────────────────────────────────── helper widgets ────────────────── */

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 26, color: kAppBarColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 20, color: Colors.black87),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds color-coded chips for specialties.
  Widget _buildSpecialtyChips(List<dynamic> specialties) {
    if (specialties.isEmpty) {
      return const Text(
        "Not specified",
        style: TextStyle(fontSize: 18),
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: specialties.map((specialty) {
        final name = specialty.toString();
        final color = specialtyColorMap[name] ?? Colors.grey;
        return Chip(
          label: Text(name,
              style: const TextStyle(color: Colors.white, fontSize: 18)),
          backgroundColor: color,
        );
      }).toList(),
    );
  }
}
