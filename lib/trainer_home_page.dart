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
import 'trainer_quiz_page.dart';
import 'feature_flags.dart';
import 'services/fitly_match_engine.dart';

/// Colour chips for specialties.
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

/* ───────────────── Fitly premium colours ───────────────── */
const Color _fitlyInk = Color(0xFF07080A);
const Color _fitlyInkAlt = Color(0xFF0B0D10);
const Color _fitlySurface = Color(0xFF111318);
const Color _fitlySurfaceAlt = Color(0xFF171B22);
const Color _fitlySurfaceRaised = Color(0xFF20242C);
const Color _fitlyLine = Color(0xFF303540);
const Color _fitlyLineAlt = Color(0xFF3A414F);
const Color _fitlyGold = Color(0xFFE7B95C);
const Color _fitlyMuted = Color(0xFFA6ADB8);
const Color _fitlyText = Color(0xFFF5F6F8);
const Color _fitlySubtleText = Color(0xFFD6DAE1);
const Color _fitlyDanger = Color(0xFFE05A5A);
const Color _fitlySuccess = Color(0xFF4CD17D);

/// Top-level helper class for rating.
class _RatingInfo {
  final double? avg;
  final int count;
  const _RatingInfo(this.avg, this.count);
}

class _TrainerIdentityView {
  final String key;
  final String title;
  final String tagline;
  final String shortMeaning;
  final String coachingPromise;
  final String idealClient;
  final String assetPath;
  final Color accent;
  final IconData fallbackIcon;

  const _TrainerIdentityView({
    required this.key,
    required this.title,
    required this.tagline,
    required this.shortMeaning,
    required this.coachingPromise,
    required this.idealClient,
    required this.assetPath,
    required this.accent,
    required this.fallbackIcon,
  });
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
  Map<String, dynamic>? _viewerUserData;
  bool _viewerUserDataLoaded = false;
  String? _currentUserRole;
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

    if (widget.trainerData != null && widget.trainerData!.isNotEmpty) {
      _trainerProfile = Map<String, dynamic>.from(widget.trainerData!);
    }

    final uidToFetch = widget.trainerData?['uid']?.toString() ??
        FirebaseAuth.instance.currentUser?.uid;

    if (uidToFetch != null && uidToFetch.isNotEmpty) {
      _fetchTrainerProfileFromUid(uidToFetch);
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _viewerUserDataLoaded = true);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};
      final role = (data['role'] as String?)?.toLowerCase();

      if (mounted) {
        setState(() {
          _currentUserRole = role;
          _viewerUserData = {...data, 'uid': doc.id};
          _viewerUserDataLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user role: $e');

      if (mounted) {
        setState(() => _viewerUserDataLoaded = true);
      }
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

  bool _profileIsVisibleWhenPaywallOff(Map<String, dynamic> data) {
    if (data['profileHidden'] == true ||
        data['isHidden'] == true ||
        data['hidden'] == true) {
      return false;
    }

    if (data['profileVisible'] == false ||
        data['isVisible'] == false ||
        data['visible'] == false) {
      return false;
    }

    return true;
  }

  Future<void> _messageTrainer(String trainerUid) async {
    final me = FirebaseAuth.instance.currentUser;

    if (me == null) return;

    final convCol = FirebaseFirestore.instance.collection('conversations');

    try {
      final q =
          await convCol.where('participants', arrayContains: me.uid).get();

      String? conversationId;
      for (final doc in q.docs) {
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
      await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .collection('reviews')
          .add(reviewData);

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
          .set(
        {
          'rating': double.parse(avg.toStringAsFixed(2)),
          'ratingCount': reviewsSnap.docs.length,
        },
        SetOptions(merge: true),
      );
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'submit review / save average failed',
      );
    }
  }

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
                  backgroundColor: _fitlySurfaceAlt,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: _fitlyLine),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _fitlyDanger.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _fitlyDanger.withValues(alpha: 0.34),
                            ),
                          ),
                          child: const Icon(
                            Icons.flag_outlined,
                            color: _fitlyDanger,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Report Trainer',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _fitlyText,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tell us what happened. This helps keep Fitly safe.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _fitlyMuted,
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: reasonController,
                          maxLines: 4,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: _fitlyText),
                          cursorColor: _fitlyGold,
                          decoration: InputDecoration(
                            hintText: 'Reason for reporting',
                            hintStyle: const TextStyle(color: _fitlyMuted),
                            filled: true,
                            fillColor: _fitlySurfaceRaised,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: _fitlyLine),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: _fitlyGold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _fitlySubtleText,
                                  side: const BorderSide(color: _fitlyLineAlt),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _fitlyDanger,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: () async {
                                  final reason = reasonController.text.trim();
                                  Navigator.pop(ctx);

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

                                  final count =
                                      (await FirebaseFirestore.instance
                                              .collection('reports')
                                              .where(
                                                'reportedItemId',
                                                isEqualTo: trainerUid,
                                              )
                                              .where(
                                                'reportedType',
                                                isEqualTo: 'trainer',
                                              )
                                              .get())
                                          .docs
                                          .length;

                                  await FirebaseFirestore.instance
                                      .collection('trainer_profiles')
                                      .doc(trainerUid)
                                      .set(
                                    {
                                      'reportCount': count,
                                      if (count >= 3) 'flagged': true,
                                    },
                                    SetOptions(merge: true),
                                  );

                                  if (!mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Trainer reported.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              final bannerMessenger = ScaffoldMessenger.of(ctx);
              await reviewDoc.reference.update({'notified': true});
              if (!ctx.mounted) return;

              bannerMessenger.showSnackBar(
                SnackBar(
                  content: Text('$reviewer left a review.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _fitlySuccess.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _fitlySuccess.withValues(alpha: 0.28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.reviews_rounded,
                    color: _fitlySuccess,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'New review from $reviewer. Tap to mark as seen.',
                      style: const TextStyle(
                        color: _fitlyText,
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openTrainerIdentityQuiz() {
    final uid = _trainerProfile['uid']?.toString();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrainerQuizPage()),
    ).then((_) {
      if (!mounted) return;
      if (uid != null && uid.isNotEmpty) {
        _fetchTrainerProfileFromUid(uid);
      }
    });
  }

  _TrainerIdentityView? _trainerIdentityFromProfile(
    Map<String, dynamic> profile,
  ) {
    final rawIdentity = profile['trainerFitnessIdentityV1'];

    Map<String, dynamic> data = {};
    if (rawIdentity is Map) {
      data = Map<String, dynamic>.from(rawIdentity);
    }

    final key = _normaliseTrainerIdentityKey(
      data['archetypeId'] ??
          data['key'] ??
          profile['trainerIdentity'] ??
          profile['trainerBadge'],
    );

    if (key.isEmpty) return null;

    return _TrainerIdentityView(
      key: key,
      title: _nonEmptyString(data['archetypeName'] ?? data['title']) ??
          _trainerTitleForKey(key),
      tagline: _nonEmptyString(data['tagline']) ?? _trainerTaglineForKey(key),
      shortMeaning: _nonEmptyString(data['shortMeaning']) ??
          _trainerShortMeaningForKey(key),
      coachingPromise: _nonEmptyString(data['coachingPromise']) ??
          _trainerCoachingPromiseForKey(key),
      idealClient: _nonEmptyString(data['idealClient']) ??
          _trainerIdealClientForKey(key),
      assetPath: _nonEmptyString(data['badgeAsset'] ?? data['assetPath']) ??
          'assets/badges/trainers/$key.png',
      accent: _trainerAccentForKey(key),
      fallbackIcon: _trainerFallbackIconForKey(key),
    );
  }

  String? _nonEmptyString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _normaliseTrainerIdentityKey(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    if (raw.isEmpty) return '';

    final cleaned = raw
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    if (cleaned.startsWith('the_')) return cleaned;
    return 'the_$cleaned';
  }

  String _trainerTitleForKey(String key) {
    switch (key) {
      case 'the_guide':
        return 'The Guide';
      case 'the_builder':
        return 'The Builder';
      case 'the_sculptor':
        return 'The Sculptor';
      case 'the_challenger':
        return 'The Challenger';
      case 'the_anchor':
        return 'The Anchor';
      default:
        return 'Coaching Identity';
    }
  }

  String _trainerTaglineForKey(String key) {
    switch (key) {
      case 'the_guide':
        return 'Start without judgement.';
      case 'the_builder':
        return 'Build consistency and capability.';
      case 'the_sculptor':
        return 'Shape visible change.';
      case 'the_challenger':
        return 'Push the next level.';
      case 'the_anchor':
        return 'Make fitness fit real life.';
      default:
        return 'Your coaching identity.';
    }
  }

  String _trainerShortMeaningForKey(String key) {
    switch (key) {
      case 'the_guide':
        return 'Coaches through patience, encouragement, confidence-building, and safe first steps.';
      case 'the_builder':
        return 'Coaches through structure, check-ins, progression, and repeatable systems.';
      case 'the_sculptor':
        return 'Coaches through body composition, physique goals, targeted habits, and visible progress.';
      case 'the_challenger':
        return 'Coaches through intensity, direct feedback, high standards, and performance-focused progression.';
      case 'the_anchor':
        return 'Coaches through calm structure, realistic planning, lifestyle flexibility, and sustainable consistency.';
      default:
        return 'This badge helps Fitly explain what working with this trainer feels like.';
    }
  }

  String _trainerCoachingPromiseForKey(String key) {
    switch (key) {
      case 'the_guide':
        return 'Helps clients feel comfortable, capable, and supported from the beginning.';
      case 'the_builder':
        return 'Turns scattered effort into a clear plan, routine, and measurable progress.';
      case 'the_sculptor':
        return 'Helps clients chase body confidence without turning progress into obsession.';
      case 'the_challenger':
        return 'Raises the standard for driven clients and pushes them with purpose.';
      case 'the_anchor':
        return 'Keeps clients grounded when work, stress, energy, or life gets messy.';
      default:
        return 'Helps clients understand the trainer’s coaching style before they reach out.';
    }
  }

  String _trainerIdealClientForKey(String key) {
    switch (key) {
      case 'the_guide':
        return 'Beginners, restart clients, low-confidence clients, and people who need reassurance before intensity.';
      case 'the_builder':
        return 'Inconsistent clients, routine-builders, strength beginners, and people who need accountability.';
      case 'the_sculptor':
        return 'Clients focused on fat loss, body shape, photos, clothing confidence, and visible transformation.';
      case 'the_challenger':
        return 'Competitive, performance-driven, high-intensity clients who respond well to pressure.';
      case 'the_anchor':
        return 'Busy, stressed, inconsistent, burned-out, or lifestyle-constrained clients.';
      default:
        return 'Best-fit client details will appear once the trainer completes the coaching identity quiz.';
    }
  }

  Color _trainerAccentForKey(String key) {
    switch (key) {
      case 'the_guide':
        return const Color(0xFFC89A54);
      case 'the_builder':
        return const Color(0xFF536FA8);
      case 'the_sculptor':
        return const Color(0xFFC8B7A0);
      case 'the_challenger':
        return const Color(0xFFB64A42);
      case 'the_anchor':
        return const Color(0xFF4FAFA3);
      default:
        return _fitlyGold;
    }
  }

  IconData _trainerFallbackIconForKey(String key) {
    switch (key) {
      case 'the_guide':
        return Icons.explore_rounded;
      case 'the_builder':
        return Icons.account_tree_rounded;
      case 'the_sculptor':
        return Icons.auto_awesome_rounded;
      case 'the_challenger':
        return Icons.local_fire_department_rounded;
      case 'the_anchor':
        return Icons.anchor_rounded;
      default:
        return Icons.workspace_premium_rounded;
    }
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

    String suburb = '';
    String state = '';
    String postcode = '';

    final lp = loc.indexOf('(');
    final rp = loc.indexOf(')');

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
    final viewer = FirebaseAuth.instance.currentUser;
    final viewerUid = viewer?.uid;

    final trainerUid = (widget.trainerData?['uid']?.toString() ??
            _trainerProfile['uid']?.toString() ??
            viewerUid) ??
        '';

    if (trainerUid.isEmpty) {
      return _premiumErrorScaffold(
        title: 'Trainer not found',
        message: 'This trainer profile could not be loaded. Please try again.',
      );
    }

    final viewerRole = (_currentUserRole ?? 'customer');
    final isOwner = viewerUid == trainerUid;

    if (_blocked.contains(trainerUid)) {
      return _premiumErrorScaffold(
        title: 'Trainer blocked',
        message: 'You have blocked this trainer.',
      );
    }

    if (_trainerProfile.isEmpty) {
      return const Scaffold(
        backgroundColor: _fitlyInk,
        body: Center(
          child: CircularProgressIndicator(color: _fitlyGold),
        ),
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
    final locationText = [
      if (suburb.isNotEmpty) suburb,
      if (state.isNotEmpty) state,
      if (postcode.isNotEmpty) postcode,
    ].join(', ');

    final bool statusIsActive = isTrainerPaymentsEnabled
        ? ((_trainerProfile['isActive'] ?? false) == true)
        : _profileIsVisibleWhenPaywallOff(_trainerProfile);

    final String statusLabel = isTrainerPaymentsEnabled
        ? 'Membership: ${statusIsActive ? 'Active' : 'Inactive'}'
        : 'Profile: ${statusIsActive ? 'Active' : 'Hidden'}';

    return Scaffold(
      backgroundColor: _fitlyInk,
      appBar: AppBar(
        automaticallyImplyLeading:
            !(viewerRole == 'trainer' && !widget.viewAsCustomer),
        iconTheme: const IconThemeData(color: _fitlyText),
        title: Text(
          displayName.isEmpty ? 'Trainer' : displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _fitlyText,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: _fitlyInk,
        elevation: 0,
        surfaceTintColor: _fitlyInk,
        actions: [
          if (!isOwner)
            IconButton(
              tooltip: 'Report Trainer',
              icon: const Icon(Icons.flag_outlined, color: _fitlyMuted),
              onPressed: () => _showReportDialog(trainerUid),
            ),
          if (!isOwner)
            PopupMenuButton<String>(
              color: _fitlySurfaceAlt,
              iconColor: _fitlyMuted,
              onSelected: (val) async {
                if (val == 'block') {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  await BlockService.instance.block(trainerUid);

                  if (!mounted) return;

                  setState(() => _blocked.add(trainerUid));

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Trainer blocked'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  navigator.pop();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'block',
                  child: Text(
                    'Block trainer',
                    style: TextStyle(color: _fitlyText),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_fitlyInk, _fitlyInkAlt],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.only(bottom: kBottomNavigationBarHeight + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (viewerRole == 'trainer')
                _buildReviewNotificationBanner(trainerUid),
              _buildHeroCard(
                displayName: displayName.isEmpty ? 'Trainer' : displayName,
                imgUrl: imgUrl,
                rateText: rateText,
                locationText: locationText,
                statusLabel: statusLabel,
                statusIsActive: statusIsActive,
                isOwner: isOwner,
              ),
              _buildCompatibilitySection(
                isOwner: isOwner,
                viewerRole: viewerRole,
              ),
              _buildCoachingIdentitySection(isOwner: isOwner),
              _buildProfileDetailsCard(
                locationText: locationText,
              ),
              const SizedBox(height: 16),
              _buildPortfolioSection(),
              const SizedBox(height: 16),
              if (!isOwner && viewerRole == 'customer')
                _buildMessageButton(trainerUid),
              if (!isOwner && viewerRole == 'customer')
                const SizedBox(height: 16),
              _buildReviewsSection(trainerUid),
              if (widget.viewAsCustomer) ...[
                const SizedBox(height: 16),
                _buildReviewFormSection(),
              ],
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          widget.viewAsCustomer ? null : _buildBottomNavigation(viewerRole),
    );
  }

  Scaffold _premiumErrorScaffold({
    required String title,
    required String message,
  }) {
    return Scaffold(
      backgroundColor: _fitlyInk,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _fitlyInk,
        foregroundColor: _fitlyText,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _premiumCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: _fitlyGold,
                  size: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _fitlyText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _fitlyMuted,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required String displayName,
    required String imgUrl,
    required String rateText,
    required String locationText,
    required String statusLabel,
    required bool statusIsActive,
    required bool isOwner,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 360,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _fitlySurface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _fitlyLine),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            imgUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imgUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorWidget: (_, __, ___) => Image.asset(
                      'assets/default_profile.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  )
                : Image.asset(
                    'assets/default_profile.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromRGBO(7, 8, 10, 0.04),
                    Color.fromRGBO(7, 8, 10, 0.28),
                    Color.fromRGBO(7, 8, 10, 0.94),
                  ],
                ),
              ),
            ),
            if (isOwner)
              Positioned(
                top: 14,
                right: 14,
                child: _statusPill(
                  label: statusLabel,
                  active: statusIsActive,
                ),
              ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _fitlyText,
                      fontSize: 31,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      shadows: [
                        Shadow(blurRadius: 8, color: Colors.black),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (locationText.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: _fitlyMuted,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _fitlySubtleText,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FutureBuilder<_RatingInfo>(
                        future: _resolveRating(_trainerProfile),
                        builder: (_, snap) {
                          final r = snap.data ?? const _RatingInfo(null, 0);
                          final has = r.avg != null && r.count > 0;

                          return _heroMetricPill(
                            icon: Icons.star_rounded,
                            label: has
                                ? '${r.avg!.toStringAsFixed(1)} (${r.count})'
                                : 'New trainer',
                            iconColor: _fitlyGold,
                          );
                        },
                      ),
                      _heroMetricPill(
                        icon: Icons.payments_rounded,
                        label: rateText,
                        iconColor: _fitlyGold,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required bool active,
  }) {
    final color = active ? _fitlySuccess : _fitlyDanger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.5,
            height: 7.5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: _fitlyText,
              fontSize: 12.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetricPill({
    required IconData icon,
    required String label,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _fitlyText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilitySection({
    required bool isOwner,
    required String viewerRole,
  }) {
    if (isOwner || viewerRole != 'customer') {
      return const SizedBox.shrink();
    }

    if (!_viewerUserDataLoaded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _premiumCard(
          borderColor: _fitlyGold.withValues(alpha: 0.22),
          child: const Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: _fitlyGold,
                  strokeWidth: 2.2,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Checking your trainer match...',
                  style: TextStyle(
                    color: _fitlyMuted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final match = FitlyMatchEngine.calculate(
      customerUserData: _viewerUserData,
      trainerProfileData: _trainerProfile,
    );

    // Early-stage Fitly rule:
    // - If the customer has not done the quiz, show a positive quiz prompt.
    // - If the trainer has not done the quiz, hide this section from customers.
    // This avoids making trainer profiles look unfinished.
    if (!match.available &&
        match.unavailableReason ==
            FitlyMatchUnavailableReason.trainerQuizMissing) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: _buildCompatibilityCard(match),
    );
  }

  Widget _buildCompatibilityCard(FitlyMatchResult match) {
    if (!match.available) {
      return _premiumCard(
        borderColor: _fitlyGold.withValues(alpha: 0.22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBox(
              icon: Icons.insights_rounded,
              color: _fitlyGold,
              size: 48,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PremiumLabel(text: 'TRAINER MATCH'),
                  const SizedBox(height: 7),
                  Text(
                    match.title,
                    style: const TextStyle(
                      color: _fitlyText,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    match.message,
                    style: const TextStyle(
                      color: _fitlyMuted,
                      fontSize: 13.2,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final scoreColor = _matchScoreColor(match.score);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _fitlySurfaceAlt,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scoreColor.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PremiumLabel(
            text: 'TRAINER MATCH',
            color: scoreColor,
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _MatchScoreRing(
                score: match.score,
                color: scoreColor,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.label,
                      style: const TextStyle(
                        color: _fitlyText,
                        fontSize: 20,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      match.message,
                      style: const TextStyle(
                        color: _fitlyMuted,
                        fontSize: 13.2,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (match.reasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            _premiumDivider(),
            const SizedBox(height: 12),
            ...match.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: scoreColor,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: _fitlySubtleText,
                          fontSize: 13.2,
                          height: 1.32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _matchScoreColor(int score) {
    if (score >= 85) return _fitlySuccess;
    if (score >= 75) return _fitlyGold;
    if (score >= 65) return const Color(0xFF7FB7FF);
    if (score >= 55) return const Color(0xFFC8B7A0);
    return _fitlyDanger;
  }

  Widget _buildCoachingIdentitySection({required bool isOwner}) {
    final identity = _trainerIdentityFromProfile(_trainerProfile);

    if (identity == null) {
      if (!isOwner) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _buildCoachingIdentityPromptCard(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: _buildCoachingIdentityUnlockedCard(
        identity: identity,
        isOwner: isOwner,
      ),
    );
  }

  Widget _buildCoachingIdentityPromptCard() {
    return _premiumCard(
      borderColor: _fitlyGold.withValues(alpha: 0.28),
      child: Row(
        children: [
          _iconBox(
            icon: Icons.workspace_premium_rounded,
            color: _fitlyGold,
            size: 54,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PremiumLabel(text: 'COACHING IDENTITY'),
                SizedBox(height: 7),
                Text(
                  'Unlock your trainer badge',
                  style: TextStyle(
                    color: _fitlyText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Show customers your coaching style and best-fit client type.',
                  style: TextStyle(
                    color: _fitlyMuted,
                    fontSize: 13.2,
                    height: 1.32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _fitlyGold,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: _openTrainerIdentityQuiz,
            child: const Text(
              'Start',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachingIdentityUnlockedCard({
    required _TrainerIdentityView identity,
    required bool isOwner,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: identity.accent.withValues(alpha: 0.34)),
        gradient: LinearGradient(
          colors: [
            identity.accent.withValues(alpha: 0.20),
            _fitlySurface,
            _fitlyInk,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: identity.accent.withValues(alpha: 0.13),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -78,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: identity.accent.withValues(alpha: 0.13),
              ),
            ),
          ),
          Positioned(
            left: -100,
            bottom: -118,
            child: Container(
              width: 235,
              height: 235,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _fitlyGold.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _PremiumLabel(
                    text: 'COACHING IDENTITY',
                    color: identity.accent,
                  ),
                ),
                const SizedBox(height: 16),
                _CoachingIdentityBadge(identity: identity),
                const SizedBox(height: 17),
                Text(
                  identity.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _fitlyText,
                    fontSize: 31,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  identity.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: identity.accent,
                    fontSize: 15.5,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoBox(
                  title: 'Coaching style',
                  text: identity.shortMeaning,
                  accent: identity.accent,
                ),
                const SizedBox(height: 10),
                _InfoBox(
                  title: 'Promise',
                  text: identity.coachingPromise,
                  accent: identity.accent,
                ),
                const SizedBox(height: 10),
                _InfoBox(
                  title: 'Best-fit clients',
                  text: identity.idealClient,
                  accent: identity.accent,
                ),
                if (isOwner) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openTrainerIdentityQuiz,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: identity.accent,
                        size: 18,
                      ),
                      label: Text(
                        'Retake Coaching Quiz',
                        style: TextStyle(
                          color: identity.accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: identity.accent.withValues(alpha: 0.35),
                        ),
                        backgroundColor: Colors.black.withValues(alpha: 0.16),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsCard({
    required String locationText,
  }) {
    final specialties = _trainerProfile['specialties'];
    final methods = _trainerProfile['trainingMethods'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _premiumCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PremiumLabel(text: 'TRAINER DETAILS'),
            const SizedBox(height: 14),
            _detailLine(
              icon: locationText.isEmpty
                  ? Icons.location_off_outlined
                  : Icons.location_on_outlined,
              title: 'Location',
              value:
                  locationText.isEmpty ? 'No location provided' : locationText,
            ),
            const SizedBox(height: 18),
            _premiumDivider(),
            const SizedBox(height: 16),
            _sectionTitle('Specialties'),
            const SizedBox(height: 10),
            if (specialties is List && specialties.isNotEmpty)
              _premiumChipWrap(
                items: specialties.take(12).map((s) => s.toString()).toList(),
                useCategoryColors: true,
              )
            else
              const _EmptyInlineText(text: 'No specialties selected'),
            if (methods is List && methods.isNotEmpty) ...[
              const SizedBox(height: 18),
              _premiumDivider(),
              const SizedBox(height: 16),
              _sectionTitle('Training methods'),
              const SizedBox(height: 10),
              _premiumChipWrap(
                items: methods.map((m) => m.toString()).toList(),
                useCategoryColors: false,
              ),
            ],
            const SizedBox(height: 18),
            _premiumDivider(),
            const SizedBox(height: 16),
            _sectionTitle('Experience'),
            const SizedBox(height: 8),
            Text(
              (_trainerProfile['experience'] ?? 'Not set').toString(),
              style: const TextStyle(
                color: _fitlySubtleText,
                fontSize: 15,
                height: 1.38,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            _premiumDivider(),
            const SizedBox(height: 16),
            _sectionTitle('About'),
            const SizedBox(height: 8),
            Text(
              (_trainerProfile['description'] ?? 'No description available.')
                  .toString(),
              style: const TextStyle(
                color: _fitlySubtleText,
                fontSize: 15,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioSection() {
    final rawImages = _trainerProfile['workImageUrls'];

    if (rawImages is! List || rawImages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _premiumCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PremiumLabel(text: 'PORTFOLIO'),
              SizedBox(height: 10),
              _EmptyInlineText(text: 'No work images available yet.'),
            ],
          ),
        ),
      );
    }

    final images = rawImages.map((e) => e.toString()).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _premiumCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PremiumLabel(text: 'PORTFOLIO'),
            const SizedBox(height: 8),
            const Text(
              'Training results, sessions, and proof of work.',
              style: TextStyle(
                color: _fitlyMuted,
                fontSize: 13.5,
                height: 1.32,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: images.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
              ),
              itemBuilder: (_, i) {
                final url = images[i];

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
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: _fitlySurfaceRaised,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Image.asset(
                          'assets/default_profile.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageButton(String trainerUid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _fitlyGold.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.message_rounded, size: 20),
          label: const Text('Message trainer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _fitlyGold,
            foregroundColor: _fitlyInk,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () {
            final me = FirebaseAuth.instance.currentUser;

            if (me == null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SignupPage(preselectedRole: 'customer'),
                ),
              );
              return;
            }

            _messageTrainer(trainerUid);
          },
        ),
      ),
    );
  }

  Widget _buildReviewsSection(String trainerUid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _premiumCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PremiumLabel(text: 'REVIEWS'),
            const SizedBox(height: 10),
            TrainerReviewsSection(
              trainerUid: trainerUid,
              allowReview:
                  FirebaseAuth.instance.currentUser?.emailVerified ?? false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewFormSection() {
    final emailVerified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!emailVerified) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _premiumCard(
          borderColor: _fitlyDanger.withValues(alpha: 0.30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PremiumLabel(
                text: 'LEAVE A REVIEW',
                color: _fitlyDanger,
              ),
              const SizedBox(height: 10),
              const Text(
                'Sign up or log in to leave a review.',
                style: TextStyle(
                  color: _fitlySubtleText,
                  fontSize: 14.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _fitlyGold,
                    foregroundColor: _fitlyInk,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    final me = FirebaseAuth.instance.currentUser;

                    if (me == null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      await me.sendEmailVerification();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Verification e-mail sent. Check your inbox.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content:
                              Text('Could not send verification email: $e'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Sign up / Log in',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _premiumCard(
        child: ReviewForm(
          onSubmit: (int rating, String comment) async {
            if (rating <= 0 || comment.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Please provide a rating and a review comment.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            final messenger = ScaffoldMessenger.of(context);

            await _submitReview(rating: rating, comment: comment);

            if (!mounted) return;

            messenger.showSnackBar(
              const SnackBar(
                content: Text('Review submitted!'),
                behavior: SnackBarBehavior.floating,
              ),
            );

            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _premiumCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(18, 18, 18, 18),
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _fitlySurfaceAlt,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor ?? _fitlyLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _iconBox({
    required IconData icon,
    required Color color,
    double size = 48,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }

  Widget _premiumDivider() {
    return Container(
      height: 1,
      color: _fitlyLine.withValues(alpha: 0.82),
    );
  }

  Widget _detailLine({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconBox(icon: icon, color: _fitlyGold, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _fitlyMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: _fitlyText,
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _fitlyText,
        fontSize: 17,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _premiumChipWrap({
    required List<String> items,
    required bool useCategoryColors,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final color = useCategoryColors
            ? (categoryColors[item] ?? _fitlyGold)
            : _fitlyGold;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.36)),
          ),
          child: Text(
            item,
            style: const TextStyle(
              color: _fitlyText,
              fontSize: 12.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MatchScoreRing extends StatelessWidget {
  final int score;
  final Color color;

  const _MatchScoreRing({
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (score.clamp(0, 100)) / 100.0;

    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 7,
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score%',
                style: const TextStyle(
                  color: _fitlyText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const Text(
                'match',
                style: TextStyle(
                  color: _fitlyMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoachingIdentityBadge extends StatelessWidget {
  final _TrainerIdentityView identity;

  const _CoachingIdentityBadge({required this.identity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 188,
      height: 188,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            identity.accent.withValues(alpha: 0.23),
            Colors.black.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: identity.accent.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: identity.accent.withValues(alpha: 0.17),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Image.asset(
        identity.assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Center(
            child: Icon(
              identity.fallbackIcon,
              color: identity.accent,
              size: 78,
            ),
          );
        },
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String text;
  final Color accent;

  const _InfoBox({
    required this.title,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE7E9EE),
              fontSize: 13.8,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _PremiumLabel({
    required this.text,
    this.color = _fitlyGold,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color.withValues(alpha: 0.94),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.15,
      ),
    );
  }
}

class _EmptyInlineText extends StatelessWidget {
  final String text;

  const _EmptyInlineText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _fitlyMuted,
        fontSize: 13.5,
        height: 1.35,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REVIEW FORM
// -----------------------------------------------------------------------------
class ReviewForm extends StatefulWidget {
  final Future<void> Function(int rating, String comment) onSubmit;

  const ReviewForm({
    super.key,
    required this.onSubmit,
  });

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
        const _PremiumLabel(text: 'LEAVE A REVIEW'),
        const SizedBox(height: 12),
        const Text(
          'Rate your experience with this trainer.',
          style: TextStyle(
            color: _fitlyMuted,
            fontSize: 13.5,
            height: 1.32,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (i) {
            final idx = i + 1;

            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              icon: Icon(
                Icons.star_rounded,
                size: 31,
                color: _selectedRating >= idx ? _fitlyGold : _fitlyLineAlt,
              ),
              onPressed: () => setState(() => _selectedRating = idx),
            );
          }),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          style: const TextStyle(color: _fitlyText),
          cursorColor: _fitlyGold,
          decoration: InputDecoration(
            hintText: 'Write your review',
            hintStyle: const TextStyle(color: _fitlyMuted),
            filled: true,
            fillColor: _fitlySurfaceRaised,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _fitlyLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _fitlyGold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (_selectedRating <= 0 ||
                        _commentCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please provide a rating and a review comment.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    setState(() => _isSubmitting = true);

                    await widget.onSubmit(
                      _selectedRating,
                      _commentCtrl.text.trim(),
                    );

                    if (!mounted) return;

                    setState(() {
                      _selectedRating = 5;
                      _commentCtrl.clear();
                      _isSubmitting = false;
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _fitlyGold,
              foregroundColor: _fitlyInk,
              disabledBackgroundColor: _fitlySurfaceRaised,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _fitlyInk,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Text(
                    'Submit Review',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
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

  const FullScreenImage({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fitlyInk,
      appBar: AppBar(
        title: const Text(
          'Trainer portfolio',
          style: TextStyle(color: _fitlyText),
        ),
        backgroundColor: _fitlyInk,
        foregroundColor: _fitlyText,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => Image.asset(
              'assets/default_profile.png',
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      ),
    );
  }
}
