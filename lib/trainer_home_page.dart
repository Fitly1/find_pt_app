// lib/trainer_home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'bottom_navigation.dart';
import 'bottom_navigation_customers.dart';
import 'trainer_reviews_section.dart';
import 'chat_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'services/block_service.dart';
import 'signup_page.dart';
import 'login_page.dart';
import 'feature_flags.dart'; // <- for isTrainerPaymentsEnabled

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

/// Top-level helper class for rating (kept outside any widget class)
class _RatingInfo {
  final double? avg; // null => no ratings yet
  final int count;
  const _RatingInfo(this.avg, this.count);
}

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
  Map<String, dynamic> _trainerProfile = {};
  String? _currentUserRole; // "trainer" or "customer"
  List<String> _blocked = [];

  // ---------------- Rating helpers ----------------
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<_RatingInfo> _fetchRatingFromReviews(String trainerUid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .collection('reviews')
          .get();

      final count = snap.docs.length;
      if (count == 0) return const _RatingInfo(null, 0);

      double total = 0.0;
      for (final d in snap.docs) {
        total += (_toDouble(d.data()['rating']) ?? 0.0);
      }
      return _RatingInfo(total / count, count);
    } catch (e, st) {
      FirebaseCrashlytics.instance
          .recordError(e, st, reason: 'trainer_home: fetch reviews failed');
      return const _RatingInfo(null, 0);
    }
  }

  Future<_RatingInfo> _resolveRating(Map<String, dynamic> p) async {
    // Prefer embedded values if present
    final embeddedAvg = _toDouble(p['avgRating'] ?? p['rating']);
    final embeddedCount =
        _toInt(p['ratingCount'] ?? p['reviewsCount'] ?? p['numReviews']);
    if (embeddedAvg != null && embeddedCount > 0) {
      return _RatingInfo(embeddedAvg, embeddedCount);
    }
    final uid = p['uid']?.toString();
    if (uid == null || uid.isEmpty) return const _RatingInfo(null, 0);
    return _fetchRatingFromReviews(uid);
  }

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    if (widget.showProfileCompleteMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your profile is complete!')),
        );
      });
    }

    _fetchCurrentUserRole();

    BlockService.instance.blockedIds().then((ids) {
      if (mounted) setState(() => _blocked = ids);
    });

    // Use passed-in data immediately if present
    if (widget.trainerData != null && widget.trainerData!.isNotEmpty) {
      _trainerProfile = Map<String, dynamic>.from(widget.trainerData!);
    }

    // Decide which uid to fetch
    String? uidToFetch = widget.trainerData?['uid']?.toString() ??
        FirebaseAuth.instance.currentUser?.uid;

    if (uidToFetch != null && uidToFetch.isNotEmpty) {
      _fetchTrainerProfileFromUid(uidToFetch);
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = (doc.data()?['role'] as String?)?.toLowerCase();
      if (mounted) setState(() => _currentUserRole = role);
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }
  }

  Future<void> _fetchTrainerProfileFromUid(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(uid)
          .get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _trainerProfile = {...data, 'uid': snapshot.id};
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching trainer profile: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------
  String formatRate(dynamic rate) {
    if (rate == null) return 'Rate not set';
    final n = _toDouble(rate);
    if (n == null || n <= 0) return 'Rate not set';
    final s = n.toStringAsFixed(n % 1 == 0 ? 0 : 2);
    return '\$$s/hr';
  }

  Future<void> _messageTrainer(String trainerUid) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final convCol = FirebaseFirestore.instance.collection('conversations');
    try {
      final q =
          await convCol.where('participants', arrayContains: me.uid).get();

      String? conversationId;
      for (var doc in q.docs) {
        final parts =
            (doc.data()['participants'] as List?)?.cast<String>() ?? [];
        if (parts.contains(trainerUid) && parts.contains(me.uid)) {
          conversationId = doc.id;
          break;
        }
      }

      conversationId ??= (await convCol.add({
        'participants': [me.uid, trainerUid],
        'lastMessage': '',
        'timestamp': FieldValue.serverTimestamp(),
        'unreadBy': [trainerUid],
      }))
          .id;

      if (!mounted) return;
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

  // Submit review
  Future<void> _submitReview({
    required int rating,
    required String comment,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || !(me.emailVerified)) return;

    final trainerUid = _trainerProfile['uid']?.toString();
    if (trainerUid == null || trainerUid.isEmpty) return;

    String reviewerName = 'Anonymous';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .get();
      final data = userDoc.data();
      final dn = data?['displayName'] as String?;
      if (dn != null && dn.trim().isNotEmpty) reviewerName = dn;
    } catch (_) {}

    final reviewData = {
      'customerId': me.uid,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
      'notified': false,
    };

    try {
      // add
      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .collection('reviews')
          .add(reviewData);

      // recompute avg and store to 'rating' (legacy field)
      final reviewsSnap = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .collection('reviews')
          .get();

      if (reviewsSnap.docs.isEmpty) return;

      double total = 0;
      for (final d in reviewsSnap.docs) {
        total += (_toDouble(d.data()['rating']) ?? 0.0);
      }
      final avg = total / reviewsSnap.docs.length;

      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .set({'rating': double.parse(avg.toStringAsFixed(2))},
              SetOptions(merge: true));
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'submit review / save average failed',
      );
    }
  }

  // Report dialog (parameterized: no reference to state fields)
  void _showReportDialog(String trainerUid) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return AnimatedPadding(
          padding:
              insets + const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Report Trainer',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonController,
                          maxLines: 4,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: 'Reason for reporting',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final reason = reasonController.text.trim();
                                  Navigator.pop(ctx); // close dialog first
                                  if (reason.isEmpty) return;

                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) return;

                                  await FirebaseFirestore.instance
                                      .collection('reports')
                                      .add({
                                    'reportedBy': user.uid,
                                    'reportedItemId': trainerUid,
                                    'reportedType': 'trainer',
                                    'reason': reason,
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });

                                  // update report count
                                  final count = (await FirebaseFirestore
                                          .instance
                                          .collection('reports')
                                          .where('reportedItemId',
                                              isEqualTo: trainerUid)
                                          .where('reportedType',
                                              isEqualTo: 'trainer')
                                          .get())
                                      .docs
                                      .length;

                                  await FirebaseFirestore.instance
                                      .collection('trainer_profiles')
                                      .doc(trainerUid)
                                      .set({
                                    'reportCount': count,
                                    if (count >= 3) 'flagged': true,
                                  }, SetOptions(merge: true));

                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Trainer reported.')),
                                  );
                                },
                                child: const Text('Submit'),
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
  }

  // Review notification banner (owner only)
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
            final bannerMessenger = ScaffoldMessenger.of(ctx); // capture
            await reviewDoc.reference.update({'notified': true});
            if (!ctx.mounted) return;
            bannerMessenger.showSnackBar(
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

  Widget _buildBottomNavigation(String viewerRole) {
    if (widget.viewAsCustomer) return const SizedBox.shrink();
    return (viewerRole == 'trainer')
        ? const BottomNavigation(currentIndex: 3)
        : const BottomNavigationCustomers(currentIndex: 3);
  }

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
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Resolve viewer & trainer safely (no crashy null checks)
    final viewer = FirebaseAuth.instance.currentUser;
    final viewerUid = viewer?.uid;

    final String trainerUid = (widget.trainerData?['uid']?.toString() ??
            _trainerProfile['uid']?.toString() ??
            viewerUid) ??
        '';

    if (trainerUid.isEmpty) {
      return Scaffold(
        appBar:
            AppBar(title: const Text('Trainer'), backgroundColor: kBrandOrange),
        body: const Center(child: Text('Trainer not found. Please try again.')),
      );
    }

    final viewerRole = (_currentUserRole ?? 'customer');
    final isOwner = viewerUid == trainerUid;

    // Blocked?
    if (_blocked.contains(trainerUid)) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: kBrandOrange,
          title: const Text('Trainer blocked'),
        ),
        body: const Center(child: Text('You have blocked this trainer.')),
      );
    }

    // While profile loads, keep a pleasant skeleton
    if (_trainerProfile.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final displayName = (_trainerProfile['displayName'] ??
            '${_trainerProfile['firstName'] ?? ''} ${_trainerProfile['lastName'] ?? ''}')
        .toString()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    final imgUrl = (_trainerProfile['profileImageUrl'] ?? '').toString();
    final parsedLoc = _parseLocation(_trainerProfile['location']?.toString());
    final suburb = parsedLoc['suburb']!;
    final state = parsedLoc['state']!;
    final postcode = parsedLoc['postcode']!;
    final rateText = formatRate(_trainerProfile['rate']);

    // NEW: status badge text (membership vs profile) using isTrainerPaymentsEnabled
    final bool membershipActive =
        (_trainerProfile['isActive'] ?? true) == true; // default active
    final String statusLabel = isTrainerPaymentsEnabled
        ? 'Membership: ${membershipActive ? 'Active' : 'Inactive'}'
        : 'Profile: ${membershipActive ? 'Active' : 'Hidden'}';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            !(viewerRole == 'trainer' && !widget.viewAsCustomer),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(displayName.isEmpty ? 'Trainer' : displayName,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: kBrandOrange,
        actions: [
          if (!isOwner)
            IconButton(
              tooltip: 'Report Trainer',
              icon: const Icon(Icons.flag_outlined, color: Colors.white),
              onPressed: () => _showReportDialog(trainerUid),
            ),
          if (!isOwner)
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'block') {
                  // capture BEFORE any await
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  await BlockService.instance.block(trainerUid);
                  if (!mounted) return;
                  setState(() => _blocked.add(trainerUid));

                  messenger.showSnackBar(
                      const SnackBar(content: Text('Trainer blocked')));
                  navigator.pop();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                    value: 'block', child: Text('Block trainer')),
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

            // ---------------- Header Card ----------------
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Solid backdrop so "letterboxing" looks intentional
                    Container(color: Colors.black),

                    // Image (full image, no crop)
                    SizedBox(
                      height: 260,
                      width: double.infinity,
                      child: imgUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.contain, // show entire image
                              alignment: Alignment.center,
                              errorWidget: (_, __, ___) => Image.asset(
                                'assets/default_profile.png',
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                              ),
                            )
                          : Image.asset(
                              'assets/default_profile.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            ),
                    ),

                    // Gradient overlay to keep text readable
                    Positioned.fill(
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.fromRGBO(0, 0, 0, 0.00),
                              Color.fromRGBO(0, 0, 0, 0.54),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // NEW: profile/membership status badge (owner only)
                    if (isOwner)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                    // Name + rating + rate
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName.isEmpty ? 'Trainer' : displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    shadows: [
                                      Shadow(blurRadius: 2, color: Colors.black)
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    FutureBuilder<_RatingInfo>(
                                      future: _resolveRating(_trainerProfile),
                                      builder: (_, snap) {
                                        final r = snap.data ??
                                            const _RatingInfo(null, 0);
                                        final has =
                                            r.avg != null && r.count > 0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color.fromRGBO(
                                                255, 255, 255, 0.9),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star_rounded,
                                                  size: 16,
                                                  color: Colors.amber),
                                              const SizedBox(width: 4),
                                              Text(
                                                has
                                                    ? '${r.avg!.toStringAsFixed(1)} (${r.count})'
                                                    : 'New',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color.fromRGBO(
                                            255, 255, 255, 0.9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        rateText,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---------------- Details Card ----------------
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (suburb.isNotEmpty ||
                        state.isNotEmpty ||
                        postcode.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              [
                                if (suburb.isNotEmpty) suburb,
                                if (state.isNotEmpty) state,
                                if (postcode.isNotEmpty) postcode,
                              ].join(', '),
                              style: const TextStyle(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: const [
                          Icon(Icons.location_off_outlined, size: 18),
                          SizedBox(width: 6),
                          Text('No location provided.',
                              style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Specialties
                    const Text('Specialties',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (_trainerProfile['specialties'] is List &&
                        (_trainerProfile['specialties'] as List).isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_trainerProfile['specialties'] as List)
                            .take(12)
                            .map((s) {
                          final spec = s.toString();
                          final color = categoryColors[spec] ?? Colors.grey;
                          return Chip(
                            label: Text(spec,
                                style: const TextStyle(color: Colors.white)),
                            backgroundColor: color,
                          );
                        }).toList(),
                      )
                    else
                      const Text('No specialties selected',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),

                    // Training methods
                    if (_trainerProfile['trainingMethods'] is List &&
                        (_trainerProfile['trainingMethods'] as List)
                            .isNotEmpty) ...[
                      const Text('Training methods',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_trainerProfile['trainingMethods'] as List)
                            .map((m) => Chip(
                                  label: Text(m.toString()),
                                  backgroundColor: Colors.blue.shade50,
                                  side: BorderSide(color: Colors.blue.shade200),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Experience
                    const Text('Experience',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      (_trainerProfile['experience'] ?? 'Not set').toString(),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    const Text('About',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      (_trainerProfile['description'] ??
                              'No description available.')
                          .toString(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------------- Portfolio ----------------
            if (_trainerProfile['workImageUrls'] is List &&
                (_trainerProfile['workImageUrls'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trainer portfolio',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount:
                          (_trainerProfile['workImageUrls'] as List).length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (_, i) {
                        final url =
                            _trainerProfile['workImageUrls'][i].toString();
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenImage(imageUrl: url),
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
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('No work images available.',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 16),

            // ---------------- Message button (customer/guest only) ----------------
            if (!isOwner && viewerRole == 'customer')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.message),
                  label: const Text('Message trainer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final me = FirebaseAuth.instance.currentUser;
                    if (me == null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SignupPage(preselectedRole: 'customer'),
                        ),
                      );
                      return;
                    }
                    _messageTrainer(trainerUid);
                  },
                ),
              ),
            const SizedBox(height: 16),

            // ---------------- Reviews ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TrainerReviewsSection(
                trainerUid: trainerUid,
                allowReview:
                    FirebaseAuth.instance.currentUser?.emailVerified ?? false,
              ),
            ),
            const SizedBox(height: 8),

            // ---------------- Review Form (customer view only) ----------------
            if (widget.viewAsCustomer)
              (FirebaseAuth.instance.currentUser?.emailVerified ?? false)
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: ReviewForm(
                        onSubmit: (int rating, String comment) async {
                          if (rating <= 0 || comment.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please provide a rating and a review comment.')),
                            );
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          await _submitReview(rating: rating, comment: comment);
                          if (!mounted) return;
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
                            'Sign up or log in to leave a review.',
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: kBrandOrange),
                            onPressed: () async {
                              final me = FirebaseAuth.instance.currentUser;
                              if (me == null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()),
                                );
                                return;
                              }
                              // capture messenger before await
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await me.sendEmailVerification();
                                messenger.showSnackBar(const SnackBar(
                                  content: Text(
                                      'Verification e-mail sent. Check your inbox.'),
                                ));
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Could not send verification email: $e')),
                                );
                              }
                            },
                            child: const Text('Sign up / Log in'),
                          ),
                        ],
                      ),
                    ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar:
          widget.viewAsCustomer ? null : _buildBottomNavigation(viewerRole),
    );
  }
}

// -----------------------------------------------------------------------------
// REVIEW FORM
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
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Submit your review',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final idx = i + 1;
            return IconButton(
              icon: Icon(
                Icons.star,
                color: _selectedRating >= idx
                    ? const Color(0xFFFFC107)
                    : Colors.grey,
              ),
              onPressed: () => setState(() => _selectedRating = idx),
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
                              'Please provide a rating and a review comment.')),
                    );
                    return;
                  }
                  setState(() => _isSubmitting = true);
                  await widget.onSubmit(
                      _selectedRating, _commentCtrl.text.trim());
                  if (!mounted) return;
                  setState(() {
                    _selectedRating = 5;
                    _commentCtrl.clear();
                    _isSubmitting = false;
                  });
                },
          child: _isSubmitting
              ? const CircularProgressIndicator()
              : const Text('Submit'),
        ),
      ],
    );
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
          title: const Text('Trainer portfolio'),
          backgroundColor: kBrandOrange),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) =>
                Image.asset('assets/default_profile.png', fit: BoxFit.fitWidth),
          ),
        ),
      ),
    );
  }
}
