import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class TrainerCard extends StatefulWidget {
  final String name;
  final List<String> specialties;
  final String location;
  final Map<String, Color> categoryColors;
  final String? profileImageUrl;
  final Map<String, dynamic> trainerData; // must include "uid" ideally
  final VoidCallback? onTap;

  const TrainerCard({
    required this.name,
    required this.specialties,
    required this.location,
    required this.categoryColors,
    this.profileImageUrl,
    required this.trainerData,
    this.onTap,
    super.key,
  });

  @override
  State<TrainerCard> createState() => _TrainerCardState();
}

class _Rating {
  final double? avg; // null => no ratings yet
  final int count;
  const _Rating(this.avg, this.count);
}

class _TrainerCardState extends State<TrainerCard> {
  // Make it nullable and initialize lazily to avoid LateInitializationError.
  Future<_Rating>? _ratingFuture;

  @override
  void initState() {
    super.initState();
    _primeRatingFuture();
  }

  @override
  void didUpdateWidget(covariant TrainerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recompute when the trainer changes.
    final oldUid = oldWidget.trainerData['uid']?.toString();
    final newUid = widget.trainerData['uid']?.toString();
    if (oldUid != newUid) {
      _primeRatingFuture();
    }
  }

  void _primeRatingFuture() {
    _ratingFuture = _resolveRating(widget.trainerData);
  }

  // -------------------- Helpers --------------------
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

  Future<_Rating> _resolveRating(Map<String, dynamic> t) async {
    // Prefer embedded values (fast path).
    final embeddedAvg = _toDouble(t['avgRating'] ?? t['rating']);
    final embeddedCount =
        _toInt(t['ratingCount'] ?? t['reviewsCount'] ?? t['numReviews']);
    if (embeddedAvg != null && embeddedCount > 0) {
      return _Rating(embeddedAvg, embeddedCount);
    }

    // Fallback to subcollection only if we have a uid.
    final uid = t['uid']?.toString();
    if (uid == null || uid.isEmpty) {
      return const _Rating(null, 0);
    }
    return _fetchRatingFromReviews(uid);
  }

  Future<_Rating> _fetchRatingFromReviews(String trainerUid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("trainer_profiles")
          .doc(trainerUid)
          .collection("reviews")
          .get();

      final count = snap.docs.length;
      if (count == 0) return const _Rating(null, 0);

      double total = 0.0;
      for (final doc in snap.docs) {
        total += (_toDouble(doc.data()["rating"]) ?? 0.0);
      }
      return _Rating(total / count, count);
    } catch (e, st) {
      debugPrint("Error fetching average rating: $e");
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Fetch reviews for rating failed',
      );
      // Safe fallback to "New"
      return const _Rating(null, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefer first/last name if present
    String displayName = (widget.trainerData["firstName"] ?? '') +
        ((widget.trainerData["lastName"] != null &&
                widget.trainerData["lastName"].toString().trim().isNotEmpty)
            ? " ${widget.trainerData["lastName"]}"
            : "");
    if (displayName.trim().isEmpty) {
      displayName = widget.name.isNotEmpty ? widget.name : "Trainer";
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: (widget.profileImageUrl != null &&
                        widget.profileImageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: widget.profileImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (context, url, error) {
                          FirebaseCrashlytics.instance.recordError(
                            error,
                            StackTrace.current,
                            reason: 'Trainer profile image failed to load',
                          );
                          return Image.asset(
                            'assets/default_profile.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                          );
                        },
                      )
                    : Image.asset(
                        'assets/default_profile.png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
              ),
            ),

            // Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Text(
                    displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Specialties
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        ...widget.specialties.take(2).map(
                              (specialty) => Chip(
                                label: Text(
                                  specialty,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                backgroundColor:
                                    widget.categoryColors[specialty] ??
                                        Colors.grey,
                              ),
                            ),
                        if (widget.specialties.length > 2)
                          const Chip(
                            label: Text('...',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            backgroundColor: Colors.grey,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Rating
                  FutureBuilder<_Rating>(
                    // Lazily initialize if somehow not yet primed.
                    future: _ratingFuture ??=
                        _resolveRating(widget.trainerData),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Text("New",
                            style: TextStyle(fontSize: 14));
                      }

                      final rating = snapshot.data ?? const _Rating(null, 0);
                      final hasRatings = rating.avg != null && rating.count > 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              hasRatings
                                  ? '${rating.avg!.toStringAsFixed(1)} (${rating.count})'
                                  : 'New',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),

                  // Location
                  Text(
                    widget.location,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
