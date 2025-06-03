import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bottom_navigation.dart';
import 'trainer_reviews_section.dart';
import 'chat_page.dart';
import 'bottom_navigation_customers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

final Map<String, Color> categoryColors = {
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

const kBrandOrange = Color(0xFFFFA726);

class TrainerHomePage extends StatefulWidget {
  final bool showProfileCompleteMessage;
  final Map<String, dynamic>? trainerData;
  final bool viewAsCustomer;

  const TrainerHomePage({
    super.key,
    this.showProfileCompleteMessage = false,
    this.trainerData,
    this.viewAsCustomer = false,
  });

  @override
  TrainerHomePageState createState() => TrainerHomePageState();
}

class TrainerHomePageState extends State<TrainerHomePage> {
  Map<String, dynamic> trainerProfile = {};
  String? currentUserRole; // "trainer" or "customer"

  @override
  void initState() {
    super.initState();
    if (widget.showProfileCompleteMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Your profile is complete!")));
      });
    }
    _fetchCurrentUserRole();
    String? uidToFetch;
    if (widget.trainerData != null && widget.trainerData!["uid"] != null) {
      uidToFetch = widget.trainerData!["uid"];
      debugPrint("TrainerHomePage received trainerData with uid: $uidToFetch");
    } else {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        uidToFetch = currentUser.uid;
        debugPrint(
            "No trainerData provided, falling back to current user's UID: $uidToFetch");
      } else {
        debugPrint("No current user found.");
      }
    }
    if (uidToFetch != null) {
      _fetchTrainerProfileFromUid(uidToFetch);
    } else {
      debugPrint("TrainerHomePage: No UID available to fetch trainer profile.");
    }
  }

  String formatRate(dynamic rate) {
    if (rate == null || (rate is num && rate <= 0)) {
      return "Rate not set";
    }
    final rateStr = rate.toString();
    if (rateStr.startsWith("\$")) {
      return "$rateStr/hr";
    }
    return "\$$rateStr/hr";
  }

  Future<void> _fetchTrainerProfileFromUid(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(uid)
          .get();
      if (snapshot.exists) {
        setState(() {
          trainerProfile = {
            ...snapshot.data() as Map<String, dynamic>,
            "uid": snapshot.id
          };
        });
        debugPrint("Fetched trainer profile: ${trainerProfile.toString()}");
      } else {
        debugPrint("Trainer profile does not exist for UID: $uid");
      }
    } catch (e) {
      debugPrint("Error fetching trainer profile: $e");
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data["role"] is String) {
          setState(() {
            currentUserRole = data["role"].toString().toLowerCase();
          });
          debugPrint("Fetched current user role: $currentUserRole");
        }
      }
    } catch (e) {
      debugPrint("Error fetching user role: $e");
    }
  }

  Future<double> _fetchAverageRating(String trainerUid) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection("trainer_profiles")
        .doc(trainerUid)
        .collection("reviews")
        .get();
    if (querySnapshot.docs.isEmpty) return 0.0;
    double total = 0.0;
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final rating = (data["rating"] as num?)?.toDouble() ?? 0.0;
      total += rating;
    }
    return total / querySnapshot.docs.length;
  }

  Future<void> _messageTrainer(String trainerUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("No user logged in.");
      return;
    }
    final customerUid = currentUser.uid;
    final conversationsCollection =
        FirebaseFirestore.instance.collection("conversations");

    debugPrint("Message button pressed for trainer UID: $trainerUid");

    try {
      QuerySnapshot query = await conversationsCollection
          .where("participants", arrayContains: customerUid)
          .get();
      String? conversationId;
      for (var doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> participants = data["participants"] ?? [];
        if (participants.contains(trainerUid) &&
            participants.contains(customerUid)) {
          conversationId = doc.id;
          debugPrint("Found existing conversation ID: $conversationId");
          break;
        }
      }
      if (conversationId == null) {
        DocumentReference newConvRef = await conversationsCollection.add({
          "participants": [customerUid, trainerUid],
          "lastMessage": "",
          "timestamp": FieldValue.serverTimestamp(),
          "unreadBy": [trainerUid],
        });
        conversationId = newConvRef.id;
        debugPrint("Created new conversation: $conversationId");
      } else {
        debugPrint("Using existing conversation: $conversationId");
      }
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatPage(conversationId: conversationId!)),
        );
      });
    } catch (e) {
      debugPrint("Error messaging trainer: $e");
    }
  }

  Future<void> _submitReview(
      {required int rating, required String comment}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint("No user logged in—cannot submit review.");
      return;
    }
    if (!currentUser.emailVerified) {
      debugPrint("User email is not verified—cannot submit review.");
      return;
    }
    final trainerUid = trainerProfile["uid"];
    if (trainerUid == null) {
      debugPrint("No trainer UID found—cannot submit review.");
      return;
    }
    String reviewerName = "Anonymous";
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();
      if (userData != null && userData.containsKey("displayName")) {
        reviewerName = userData["displayName"];
      }
    } catch (e) {
      debugPrint("Error fetching user displayName: $e");
    }
    final reviewData = {
      'customerId': currentUser.uid,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
      'notified': false,
    };
    try {
      final docRef = await FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(trainerUid)
          .collection("reviews")
          .add(reviewData);
      debugPrint("Review submitted successfully: ${docRef.id}");
    } catch (e) {
      debugPrint("Error submitting review: $e");
    }
  }

  // Report dialog
  void _showReportDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Report Trainer"),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Reason for reporting"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              final user = FirebaseAuth.instance.currentUser;
              final tid = trainerProfile['uid'];
              if (user == null || tid == null) return;
              await FirebaseFirestore.instance.collection('reports').add({
                'reportedBy': user.uid,
                'reportedItemId': tid,
                'reportedType': 'trainer',
                'reason': reason,
                'timestamp': FieldValue.serverTimestamp(),
              });
              final count = (await FirebaseFirestore.instance
                      .collection('reports')
                      .where('reportedItemId', isEqualTo: tid)
                      .where('reportedType', isEqualTo: 'trainer')
                      .get())
                  .docs
                  .length;
              await FirebaseFirestore.instance
                  .collection('trainer_profiles')
                  .doc(tid)
                  .set({'reportCount': count, if (count >= 3) 'flagged': true},
                      SetOptions(merge: true));
              if (!mounted) return;
              messenger.showSnackBar(
                  const SnackBar(content: Text("Trainer reported.")));
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Map<String, String> _parseLocation(String? location) {
    if (location == null || location.isEmpty) {
      return {"suburb": "", "state": "", "postcode": ""};
    }
    String suburb = "";
    String state = "";
    String postcode = "";
    final leftParen = location.indexOf("(");
    final rightParen = location.indexOf(")");
    if (leftParen != -1 && rightParen != -1 && rightParen > leftParen) {
      postcode = location.substring(leftParen + 1, rightParen).trim();
      final beforeParen = location.substring(0, leftParen).trim();
      final parts = beforeParen.split(",");
      if (parts.length >= 2) {
        suburb = parts[0].trim();
        state = parts[1].trim();
      } else {
        suburb = beforeParen;
      }
    } else {
      suburb = location;
    }
    return {"suburb": suburb, "state": state, "postcode": postcode};
  }

  Widget _buildReviewNotificationBanner(String trainerUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(trainerUid)
          .collection("reviews")
          .where("notified", isEqualTo: false)
          .orderBy("timestamp", descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final reviewDoc = snapshot.data!.docs.first;
        final reviewData = reviewDoc.data() as Map<String, dynamic>;
        final reviewerName = reviewData["reviewerName"] ?? "A customer";
        return GestureDetector(
          onTap: () async {
            await reviewDoc.reference.update({"notified": true});
            if (!mounted) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("$reviewerName left a review.")));
            });
          },
          child: Container(
            width: double.infinity,
            color: Colors.greenAccent,
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "New review from $reviewerName. Tap here.",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    if (widget.viewAsCustomer) return const SizedBox.shrink();
    if (currentUserRole != null &&
        currentUserRole!.toLowerCase() == "trainer") {
      return const BottomNavigation(currentIndex: 3);
    } else {
      return const BottomNavigationCustomers(currentIndex: 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("No user found")));
    }
    if (currentUserRole == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String displayName =
        trainerProfile["displayName"] ?? currentUser.displayName ?? "Trainer";
    final parsedLocation = _parseLocation(trainerProfile["location"]);
    final suburb = parsedLocation["suburb"]!;
    final state = parsedLocation["state"]!;
    final postcode = parsedLocation["postcode"]!;
    final trainerUid = trainerProfile["uid"] ?? currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        // Back button hidden ONLY when this is a real trainer
        // viewing their own dashboard (not view-as-customer).
        automaticallyImplyLeading:
            !(currentUserRole == "trainer" && !widget.viewAsCustomer),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(displayName, style: const TextStyle(color: Colors.white)),
        backgroundColor: kBrandOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.white),
            tooltip: 'Report Trainer',
            onPressed: _showReportDialog,
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.only(bottom: kBottomNavigationBarHeight + 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (currentUserRole!.toLowerCase() == "trainer")
              _buildReviewNotificationBanner(trainerUid),
            Card(
              margin: const EdgeInsets.all(16.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      topRight: Radius.circular(16.0),
                    ),
                    child: (trainerProfile["profileImageUrl"] != null &&
                            trainerProfile["profileImageUrl"]
                                .toString()
                                .isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: trainerProfile["profileImageUrl"],
                            height: 400,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) {
                              FirebaseCrashlytics.instance.recordError(
                                error,
                                StackTrace.current,
                                reason: 'Profile image failed to load',
                              );
                              return Image.asset(
                                'assets/default_profile.png',
                                height: 400,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              );
                            },
                          )
                        : Image.asset(
                            'assets/default_profile.png',
                            height: 400,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        FutureBuilder<double>(
                          future: _fetchAverageRating(trainerUid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                  height: 24,
                                  child: Center(
                                      child: CircularProgressIndicator()));
                            }
                            if (snapshot.hasError) {
                              return const Text("Error loading rating");
                            }
                            final avgRating = snapshot.data ?? 0.0;
                            return Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(avgRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.bold)),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(formatRate(trainerProfile["rate"] ?? 0),
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 20),
                        if (trainerProfile["experience"] != null &&
                            trainerProfile["experience"]
                                .toString()
                                .trim()
                                .isNotEmpty)
                          RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                    text: "Experience: ",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black)),
                                TextSpan(
                                    text:
                                        trainerProfile["experience"].toString(),
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.normal,
                                        color: Colors.black)),
                              ],
                            ),
                          )
                        else
                          const Text("Experience not set",
                              style: TextStyle(fontSize: 20)),
                        const SizedBox(height: 20),
                        const Text("Bio:",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            trainerProfile["description"] ??
                                "No description available.",
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 20),
                        const Text("Location:",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        if (suburb.isEmpty && state.isEmpty && postcode.isEmpty)
                          const Text("No location provided.",
                              style: TextStyle(fontSize: 20))
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Suburb: $suburb",
                                  style: const TextStyle(fontSize: 20)),
                              if (state.isNotEmpty)
                                Text("State: $state",
                                    style: const TextStyle(fontSize: 20)),
                              if (postcode.isNotEmpty)
                                Text("Postcode: $postcode",
                                    style: const TextStyle(fontSize: 20)),
                            ],
                          ),
                        const SizedBox(height: 20),
                        if (trainerProfile["specialties"] != null &&
                            (trainerProfile["specialties"] as List).isNotEmpty)
                          Wrap(
                            spacing: 8.0,
                            children:
                                (trainerProfile["specialties"] as List<dynamic>)
                                    .map((s) {
                              final Color color =
                                  categoryColors[s] ?? Colors.grey;
                              return Chip(
                                label: Text(s.toString(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16)),
                                backgroundColor: color,
                              );
                            }).toList(),
                          )
                        else
                          const Text("No specialties selected",
                              style: TextStyle(
                                  fontStyle: FontStyle.italic, fontSize: 16)),
                        const SizedBox(height: 16),
                        if (trainerProfile["trainingMethods"] != null &&
                            (trainerProfile["trainingMethods"] as List)
                                .isNotEmpty)
                          Wrap(
                            spacing: 8.0,
                            children: (trainerProfile["trainingMethods"]
                                    as List<dynamic>)
                                .map((method) {
                              return Chip(
                                label: Text(method.toString()),
                                backgroundColor: Colors.lightBlueAccent,
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  if (trainerProfile["workImageUrls"] != null &&
                      (trainerProfile["workImageUrls"] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Trainer Portfolio",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: (trainerProfile["workImageUrls"] as List)
                                .length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemBuilder: (context, index) {
                              String imageUrl =
                                  trainerProfile["workImageUrls"][index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => FullScreenImage(
                                            imageUrl: imageUrl)),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) {
                                      return Image.asset(
                                        'assets/default_profile.png',
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text("No work images available.",
                          style: TextStyle(
                              fontSize: 16, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
            if (trainerProfile["uid"] != null &&
                trainerProfile["uid"] != currentUser.uid &&
                currentUserRole != null &&
                currentUserRole!.toLowerCase() == "customer")
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.message),
                  label: const Text("Message Trainer"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 24),
                    textStyle: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final trainerUid = trainerProfile["uid"];
                    if (trainerUid != null) {
                      debugPrint(
                          "Message button pressed for trainer UID: $trainerUid");
                      _messageTrainer(trainerUid);
                    } else {
                      debugPrint("Trainer UID not found in trainerProfile.");
                    }
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TrainerReviewsSection(
                trainerUid: trainerUid,
                allowReview: FirebaseAuth.instance.currentUser!.emailVerified,
              ),
            ),
            if (widget.viewAsCustomer)
              FirebaseAuth.instance.currentUser!.emailVerified
                  ? Padding(
                      padding: const EdgeInsets.all(22.0),
                      child: ReviewForm(
                        onSubmit: (int rating, String comment) async {
                          if (rating <= 0 || comment.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Please provide a rating and a review comment.")));
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          await _submitReview(rating: rating, comment: comment);
                          if (!mounted) return;
                          messenger.showSnackBar(const SnackBar(
                              content: Text("Review submitted!")));
                          setState(() {}); // refresh page if needed
                        },
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text("Please verify your email to leave a review.",
                          style:
                              TextStyle(color: Colors.red[700], fontSize: 16)),
                    ),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.viewAsCustomer ? null : _buildBottomNavigation(),
    );
  }
}

class ReviewForm extends StatefulWidget {
  final Future<void> Function(int rating, String comment) onSubmit;

  const ReviewForm({super.key, required this.onSubmit});

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  int _selectedRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Submit Your Review",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return IconButton(
              icon: Icon(
                Icons.star,
                color: _selectedRating >= starIndex
                    ? const Color.fromRGBO(255, 193, 7, 1)
                    : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _selectedRating = starIndex;
                });
              },
            );
          }),
        ),
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(
              labelText: "Your review", border: OutlineInputBorder()),
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (_selectedRating <= 0 ||
                      _commentController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "Please provide a rating and a review comment.")));
                    return;
                  }
                  setState(() => _isSubmitting = true);
                  await widget.onSubmit(
                      _selectedRating, _commentController.text);
                  if (!mounted) return;
                  setState(() {
                    _selectedRating = 5;
                    _commentController.clear();
                    _isSubmitting = false;
                  });
                },
          child: _isSubmitting
              ? const CircularProgressIndicator()
              : const Text("Submit Review"),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Trainer Portfolio"),
          backgroundColor: kBrandOrange),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            errorWidget: (context, url, error) {
              return Image.asset('assets/default_profile.png',
                  fit: BoxFit.contain);
            },
          ),
        ),
      ),
    );
  }
}
