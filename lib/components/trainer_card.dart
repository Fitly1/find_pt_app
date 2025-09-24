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
  final double? avg;
  final int count;
  const _Rating(this.avg, this.count);
}

class _TrainerCardState extends State<TrainerCard> {
  Future<_Rating>? _ratingFuture;
  bool _isPressed = false; // for lift effect

  @override
  void initState() {
    super.initState();
    _primeRatingFuture();
  }

  @override
  void didUpdateWidget(covariant TrainerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUid = oldWidget.trainerData['uid']?.toString();
    final newUid = widget.trainerData['uid']?.toString();
    if (oldUid != newUid) {
      _primeRatingFuture();
    }
  }

  void _primeRatingFuture() {
    _ratingFuture = _resolveRating(widget.trainerData);
  }

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
    final embeddedAvg = _toDouble(t['avgRating'] ?? t['rating']);
    final embeddedCount =
        _toInt(t['ratingCount'] ?? t['reviewsCount'] ?? t['numReviews']);
    if (embeddedAvg != null && embeddedCount > 0) {
      return _Rating(embeddedAvg, embeddedCount);
    }

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

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      onHighlightChanged: (pressed) {
        setState(() => _isPressed = pressed);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isPressed)
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              )
            else
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0, // shadow handled above
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- IMAGE ---
              AspectRatio(
                aspectRatio: 1.2, // keeps all trainer cards same height
                child: (widget.profileImageUrl != null &&
                        widget.profileImageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: widget.profileImageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorWidget: (context, url, error) {
                          FirebaseCrashlytics.instance.recordError(
                            error,
                            StackTrace.current,
                            reason: 'Trainer profile image failed to load',
                          );
                          return Image.asset(
                            'assets/default_profile.png',
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : Image.asset(
                        'assets/default_profile.png',
                        fit: BoxFit.cover,
                      ),
              ),

              // --- INFO ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Specialties
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...widget.specialties.take(2).map(
                                (specialty) => Chip(
                                  label: Text(
                                    specialty,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                  backgroundColor:
                                      widget.categoryColors[specialty] ??
                                          Colors.grey,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          if (widget.specialties.length > 2)
                            const Chip(
                              label: Text(
                                '...',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                              backgroundColor: Colors.grey,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),

                      const Spacer(),

                      // Rating
                      FutureBuilder<_Rating>(
                        future: _ratingFuture ??=
                            _resolveRating(widget.trainerData),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          if (snapshot.hasError) {
                            return const Text("New",
                                style: TextStyle(fontSize: 13));
                          }

                          final rating =
                              snapshot.data ?? const _Rating(null, 0);
                          final hasRatings =
                              rating.avg != null && rating.count > 0;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                hasRatings
                                    ? '${rating.avg!.toStringAsFixed(1)} (${rating.count})'
                                    : 'New',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 4),

                      // Location
                      Text(
                        widget.location,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
