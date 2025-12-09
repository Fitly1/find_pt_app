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
  final Map<String, dynamic> trainerData;
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
  bool _isPressed = false;

  // Slightly shorter image to help fit more cards on screen
  static const double _imageHeight = 150;
  static const double _titleFont = 18;
  static const double _locationFont = 13;

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
      borderRadius: BorderRadius.circular(14),
      onHighlightChanged: (pressed) {
        setState(() => _isPressed = pressed);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(
          vertical: 4,
          horizontal: 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.18),
              blurRadius: _isPressed ? 14 : 10,
              offset: Offset(0, _isPressed ? 6 : 3),
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(
              color: Color(0xFFFFA726), // orange border line
              width: 1.3,
            ),
          ),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _imageHeight,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: _titleFont,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.location,
                      style: const TextStyle(
                        fontSize: _locationFont,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // 🔥 Single-row specialty chips: at most 2 chips
                    _SpecialtyRow(
                      specialties: widget.specialties,
                      categoryColors: widget.categoryColors,
                    ),

                    const SizedBox(height: 8),

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
                          return const Text(
                            "New",
                            style: TextStyle(fontSize: 13),
                          );
                        }
                        final rating = snapshot.data ?? const _Rating(null, 0);
                        final has = rating.avg != null && rating.count > 0;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              has
                                  ? '${rating.avg!.toStringAsFixed(1)} (${rating.count})'
                                  : 'New',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecialtyRow extends StatelessWidget {
  final List<String> specialties;
  final Map<String, Color> categoryColors;

  const _SpecialtyRow({
    required this.specialties,
    required this.categoryColors,
  });

  @override
  Widget build(BuildContext context) {
    if (specialties.isEmpty) return const SizedBox.shrink();

    final primary = specialties.first;
    String? secondaryLabel;

    if (specialties.length == 2) {
      secondaryLabel = specialties[1];
    } else if (specialties.length > 2) {
      final remaining = specialties.length - 1;
      secondaryLabel = '+$remaining more';
    }

    return Row(
      children: [
        Flexible(
          child: _SpecialtyChip(
            label: primary,
            color: categoryColors[primary] ?? Colors.blue,
          ),
        ),
        if (secondaryLabel != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: _SpecialtyChip(
              label: secondaryLabel,
              color: specialties.length == 2
                  ? (categoryColors[secondaryLabel] ?? Colors.grey)
                  : Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SpecialtyChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }
}
