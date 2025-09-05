import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bottom_navigation.dart';
import 'trainer_reviews_section.dart';
import 'chat_page.dart';
import 'bottom_navigation_customers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'services/block_service.dart'; // <-- NEW
import 'signup_page.dart';
import 'login_page.dart';

/// colour chips for specialties
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
  List<String> _blocked = []; // <-- NEW
  late String viewerRole;

  // ---------------------------------------------------------------------------
  // INITIALISATION
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    if (widget.showProfileCompleteMessage) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your profile is complete!')),
          );
        },
      );
    }

    _fetchCurrentUserRole();

    // fetch blocked IDs once
    BlockService.instance.blockedIds().then((ids) {
      // <-- NEW
      if (mounted) {
        setState(() => _blocked = ids);
      }
    });

    // ───── NEW: use data passed from Marketplace straight away ─────
    if (widget.trainerData != null && widget.trainerData!.isNotEmpty) {
      trainerProfile = Map<String, dynamic>.from(widget.trainerData!);
    }
    // ───────────────────────────────────────────────────────────────

    // choose which trainer UID to load
    String? uidToFetch =
        widget.trainerData?['uid'] ?? FirebaseAuth.instance.currentUser?.uid;

    if (uidToFetch != null) {
      _fetchTrainerProfileFromUid(uidToFetch);
    }
  }

  // ---------------------------------------------------------------------------
  // HELPER / FETCHERS
  // ---------------------------------------------------------------------------
  String formatRate(dynamic rate) {
    if (rate == null || (rate is num && rate <= 0)) {
      return 'Rate not set';
    }
    final rateStr = rate.toString();
    return rateStr.startsWith('\$') ? '$rateStr/hr' : '\$$rateStr/hr';
  }

  Future<void> _fetchTrainerProfileFromUid(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(uid)
          .get();
      if (snapshot.exists) {
        setState(() {
          trainerProfile = {
            ...snapshot.data() as Map<String, dynamic>,
            'uid': snapshot.id,
          };
        });
      }
    } catch (e) {
      debugPrint('Error fetching trainer profile: $e');
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && (doc.data()?['role'] is String)) {
        setState(() {
          currentUserRole = doc.data()!['role'].toString().toLowerCase();
        });
      }
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }
  }

  Future<double> _fetchAverageRating(String trainerUid) async {
    final snap = await FirebaseFirestore.instance
        .collection('trainer_profiles')
        .doc(trainerUid)
        .collection('reviews')
        .get();
    if (snap.docs.isEmpty) {
      return 0.0;
    }
    double total = 0;
    for (final d in snap.docs) {
      total += (d.data()['rating'] as num).toDouble();
    }
    return total / snap.docs.length;
  }

  Future<void> _messageTrainer(String trainerUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }
    final customerUid = currentUser.uid;

    final convCol = FirebaseFirestore.instance.collection('conversations');

    try {
      QuerySnapshot query =
          await convCol.where('participants', arrayContains: customerUid).get();

      String? conversationId;
      for (var doc in query.docs) {
        final parts =
            (doc.data() as Map<String, dynamic>)['participants'] ?? [];
        if (parts.contains(trainerUid) && parts.contains(customerUid)) {
          conversationId = doc.id;
          break;
        }
      }

      // create new conversation if needed
      conversationId ??= (await convCol.add({
        'participants': [customerUid, trainerUid],
        'lastMessage': '',
        'timestamp': FieldValue.serverTimestamp(),
        'unreadBy': [trainerUid],
      }))
          .id;

      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId!,
            otherUserId: trainerUid,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error messaging trainer: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SUBMIT REVIEW  (contains the NEW average-rating code)
  // ---------------------------------------------------------------------------
  Future<void> _submitReview({
    required int rating,
    required String comment,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || !currentUser.emailVerified) {
      return;
    }

    final trainerUid = trainerProfile['uid'];
    if (trainerUid == null) {
      return;
    }

    // reviewer name
    String reviewerName = 'Anonymous';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final data = userDoc.data();
      if (data != null && data.containsKey('displayName')) {
        reviewerName = data['displayName'];
      }
    } catch (_) {}

    final reviewData = {
      'customerId': currentUser.uid,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
      'notified': false,
    };

    try {
      // 1. add the new review
      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .collection('reviews')
          .add(reviewData);

      // 2. recompute & save the average
      final reviewsSnap = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .collection('reviews')
          .get();

      double total = 0;
      for (final d in reviewsSnap.docs) {
        total += (d.data()['rating'] as num).toDouble();
      }
      final avg =
          reviewsSnap.docs.isEmpty ? 0 : total / reviewsSnap.docs.length;

      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .update({'rating': double.parse(avg.toStringAsFixed(2))});
    } catch (e, st) {
      FirebaseCrashlytics.instance
          .recordError(e, st, reason: 'submit review / save average failed');
    }
  }

// ---------------------------------------------------------------------------
// REPORT DIALOG
// ---------------------------------------------------------------------------
  void _showReportDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // <-- use ctx instead of _
        title: const Text('Report Trainer'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason for reporting'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              Navigator.pop(ctx);

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final tid = trainerProfile['uid'];

              await FirebaseFirestore.instance.collection('reports').add({
                'reportedBy': user.uid,
                'reportedItemId': tid,
                'reportedType': 'trainer',
                'reason': reason,
                'timestamp': FieldValue.serverTimestamp(),
              });

              // update report counter
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
                  .set({
                'reportCount': count,
                if (count >= 3) 'flagged': true,
              }, SetOptions(merge: true));

              if (!ctx.mounted) return; // guard dialog context
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Trainer reported.')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOCATION PARSE
  // ---------------------------------------------------------------------------
  Map<String, String> _parseLocation(String? loc) {
    if (loc == null || loc.isEmpty) {
      return {'suburb': '', 'state': '', 'postcode': ''};
    }
    String suburb = '', state = '', postcode = '';
    final lp = loc.indexOf('('), rp = loc.indexOf(')');
    if (lp != -1 && rp != -1 && rp > lp) {
      postcode = loc.substring(lp + 1, rp).trim();
      final before = loc.substring(0, lp).trim();
      final parts = before.split(',');
      if (parts.length >= 2) {
        suburb = parts[0].trim();
        state = parts[1].trim();
      } else {
        suburb = before;
      }
    } else {
      suburb = loc;
    }
    return {'suburb': suburb, 'state': state, 'postcode': postcode};
  }

  // ---------------------------------------------------------------------------
  // BANNER FOR NEW REVIEWS
  // ---------------------------------------------------------------------------
  Widget _buildReviewNotificationBanner(String trainerUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .collection('reviews')
          .where('notified', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final reviewDoc = snap.data!.docs.first;
        final reviewer =
            (reviewDoc.data() as Map<String, dynamic>)['reviewerName'] ??
                'A customer';
        return GestureDetector(
          onTap: () async {
            await reviewDoc.reference.update({'notified': true});
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$reviewer left a review.')),
            );
          },
          child: Container(
            width: double.infinity,
            color: Colors.greenAccent,
            padding: const EdgeInsets.all(8),
            child: Text(
              'New review from $reviewer. Tap here.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM NAVIGATION PICKER
  // ---------------------------------------------------------------------------
  Widget _buildBottomNavigation() {
    if (widget.viewAsCustomer) return const SizedBox.shrink();
    return (viewerRole == 'trainer')
        ? const BottomNavigation(currentIndex: 3)
        : const BottomNavigationCustomers(currentIndex: 3);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (trainerProfile.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    viewerRole = currentUserRole ?? 'customer';

    final trainerUid = trainerProfile['uid'] ?? currentUser?.uid;

    // If this trainer is blocked, show a simple “blocked” screen
    if (_blocked.contains(trainerUid)) {
      // <-- NEW
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: kBrandOrange,
          title: const Text('Trainer blocked'),
        ),
        body: const Center(
          child: Text('You have blocked this trainer.'),
        ),
      );
    }

    final displayName =
        trainerProfile['displayName'] ?? currentUser?.displayName ?? 'Trainer';
    final parsedLoc = _parseLocation(trainerProfile['location']);
    final suburb = parsedLoc['suburb']!,
        state = parsedLoc['state']!,
        postcode = parsedLoc['postcode']!;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            !(viewerRole == 'trainer' && !widget.viewAsCustomer),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          displayName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: kBrandOrange,
        actions: [
          IconButton(
            tooltip: 'Report Trainer',
            icon: const Icon(Icons.flag_outlined, color: Colors.white),
            onPressed: _showReportDialog,
          ),
          if (trainerUid != currentUser?.uid) // <-- NEW
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'block') {
                  // async work
                  await BlockService.instance.block(trainerUid);

                  // First guard (State context—needed before setState)
                  if (!mounted) return;
                  setState(() => _blocked.add(trainerUid));

                  // Second guard (same BuildContext you’ll use next)
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trainer blocked')),
                  );
                  Navigator.of(context).pop(); // go back to previous screen
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'block',
                  child: Text('Block trainer'),
                ),
              ],
            ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: kBottomNavigationBarHeight + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (viewerRole == 'trainer')
              _buildReviewNotificationBanner(trainerUid),

            // ----------------------------------------------------------------
            // PROFILE CARD
            // ----------------------------------------------------------------
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // avatar/banner
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: (trainerProfile['profileImageUrl'] != null &&
                            (trainerProfile['profileImageUrl'] as String)
                                .isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: trainerProfile['profileImageUrl'],
                            height: 400,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Image.asset(
                              'assets/default_profile.png',
                              height: 400,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            'assets/default_profile.png',
                            height: 400,
                            fit: BoxFit.cover,
                          ),
                  ),
                  // details
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<double>(
                          future: _fetchAverageRating(trainerUid),
                          builder: (_, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 24,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final rating = snap.data ?? 0.0;
                            return Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          formatRate(trainerProfile['rate']),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 20),
                        // experience
                        if ((trainerProfile['experience'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 20, color: Colors.black),
                              children: [
                                const TextSpan(
                                  text: 'Experience: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: trainerProfile['experience'].toString(),
                                ),
                              ],
                            ),
                          )
                        else
                          const Text(
                            'Experience not set',
                            style: TextStyle(fontSize: 20),
                          ),
                        const SizedBox(height: 20),
                        // bio
                        const Text(
                          'Bio:',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trainerProfile['description'] ??
                              'No description available.',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 20),
                        // location
                        const Text(
                          'Location:',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (suburb.isEmpty && state.isEmpty && postcode.isEmpty)
                          const Text(
                            'No location provided.',
                            style: TextStyle(fontSize: 20),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Suburb: $suburb',
                                style: const TextStyle(fontSize: 20),
                              ),
                              if (state.isNotEmpty)
                                Text('State: $state',
                                    style: const TextStyle(fontSize: 20)),
                              if (postcode.isNotEmpty)
                                Text('Postcode: $postcode',
                                    style: const TextStyle(fontSize: 20)),
                            ],
                          ),
                        const SizedBox(height: 20),
                        // specialties chips
                        if (trainerProfile['specialties'] != null &&
                            (trainerProfile['specialties'] as List).isNotEmpty)
                          Wrap(
                            spacing: 8,
                            children:
                                (trainerProfile['specialties'] as List<dynamic>)
                                    .map((s) {
                              final color = categoryColors[s] ?? Colors.grey;
                              return Chip(
                                label: Text(
                                  s.toString(),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                                backgroundColor: color,
                              );
                            }).toList(),
                          )
                        else
                          const Text(
                            'No specialties selected',
                            style: TextStyle(
                                fontSize: 16, fontStyle: FontStyle.italic),
                          ),
                        const SizedBox(height: 16),
                        // training methods
                        if (trainerProfile['trainingMethods'] != null &&
                            (trainerProfile['trainingMethods'] as List)
                                .isNotEmpty)
                          Wrap(
                            spacing: 8,
                            children:
                                (trainerProfile['trainingMethods'] as List)
                                    .map(
                                      (m) => Chip(
                                        label: Text(m.toString()),
                                        backgroundColor: Colors.lightBlueAccent,
                                      ),
                                    )
                                    .toList(),
                          ),
                      ],
                    ),
                  ),
                  // portfolio images
                  if (trainerProfile['workImageUrls'] != null &&
                      (trainerProfile['workImageUrls'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trainer Portfolio',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: (trainerProfile['workImageUrls'] as List)
                                .length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemBuilder: (_, i) {
                              final url = trainerProfile['workImageUrls'][i];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FullScreenImage(imageUrl: url),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Image.asset(
                                      'assets/default_profile.png',
                                      fit: BoxFit.cover,
                                    ),
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
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'No work images available.',
                        style: TextStyle(
                            fontSize: 16, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),

// ----------------------------------------------------------------
// MESSAGE TRAINER BUTTON  (only when viewing as customer/guest)
// ----------------------------------------------------------------
            if (trainerProfile['uid'] != null &&
                trainerProfile['uid'] != currentUser?.uid &&
                viewerRole == 'customer')
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.message),
                  label: const Text('Message Trainer'),
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
                    final user = FirebaseAuth.instance.currentUser;

                    // Not signed-in → send to sign-up (customer role locked)
                    if (user == null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SignupPage(preselectedRole: 'customer'),
                        ),
                      );
                      return;
                    }

                    // Signed-in customer → open / create chat
                    _messageTrainer(trainerProfile['uid']);
                  },
                ),
              ),

            // ----------------------------------------------------------------
            // REVIEWS SECTION
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TrainerReviewsSection(
                trainerUid: trainerUid,
                allowReview:
                    FirebaseAuth.instance.currentUser?.emailVerified ?? false,
              ),
            ),

            // ----------------------------------------------------------------
            // REVIEW FORM (only when user is looking as customer)
            // ----------------------------------------------------------------
            if (widget.viewAsCustomer)
              (FirebaseAuth.instance.currentUser?.emailVerified ?? false)
                  ? Padding(
                      padding: const EdgeInsets.all(22),
                      child: ReviewForm(
                        onSubmit: (int rating, String comment) async {
                          if (rating <= 0 || comment.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please provide a rating and a review comment.'),
                              ),
                            );
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          await _submitReview(rating: rating, comment: comment);
                          if (!mounted) {
                            return;
                          }
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Review submitted!')));
                          setState(() {});
                        },
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign up or Log in to leave a review.',
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: kBrandOrange),
                            onPressed: () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) {
                                // guest → ask to log in
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()),
                                );
                                return;
                              }
                              await user.sendEmailVerification();

                              // guard the SAME BuildContext that will be used
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Verification e-mail sent. Check your inbox.'),
                              ));
                            },
                            child: const Text('Sign Up / Log In'),
                          ),
                        ],
                      ),
                    ),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.viewAsCustomer ? null : _buildBottomNavigation(),
    );
  }
}

// -----------------------------------------------------------------------------
// REVIEW FORM WIDGET
// -----------------------------------------------------------------------------
class ReviewForm extends StatefulWidget {
  final Future<void> Function(int rating, String comment) onSubmit;
  const ReviewForm({super.key, required this.onSubmit});

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  int _selectedRating = 5;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Submit Your Review',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final idx = index + 1;
            return IconButton(
              icon: Icon(
                Icons.star,
                color: _selectedRating >= idx
                    ? const Color(0xFFFFC107)
                    : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _selectedRating = idx;
                });
              },
            );
          }),
        ),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Your review',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (_selectedRating <= 0 ||
                      _commentCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Please provide a rating and a review comment.'),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _isSubmitting = true;
                  });
                  await widget.onSubmit(
                      _selectedRating, _commentCtrl.text.trim());
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _selectedRating = 5;
                    _commentCtrl.clear();
                    _isSubmitting = false;
                  });
                },
          child: _isSubmitting
              ? const CircularProgressIndicator()
              : const Text('Submit Review'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// FULL SCREEN IMAGE
// -----------------------------------------------------------------------------
class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Portfolio'),
        backgroundColor: kBrandOrange,
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) =>
                Image.asset('assets/default_profile.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
