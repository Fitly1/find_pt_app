import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/* ───────────────── Fitly premium colours ───────────────── */

const Color _ink = Color(0xFF07080A);
const Color _surfaceRaised = Color(0xFF20242C);
const Color _line = Color(0xFF303540);
const Color _gold = Color(0xFFE7B95C);
const Color _text = Color(0xFFF5F6F8);
const Color _muted = Color(0xFFA6ADB8);

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

  static const double _imageHeight = 160;

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

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  String _clean(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  Future<_Rating> _resolveRating(Map<String, dynamic> trainer) async {
    final embeddedAvg = _toDouble(
      trainer['avgRating'] ??
          trainer['averageRating'] ??
          trainer['rating'] ??
          trainer['reviewAverage'],
    );

    final embeddedCount = _toInt(
      trainer['ratingCount'] ??
          trainer['reviewsCount'] ??
          trainer['reviewCount'] ??
          trainer['numReviews'],
    );

    if (embeddedAvg != null && embeddedCount > 0) {
      return _Rating(embeddedAvg, embeddedCount);
    }

    final uid = trainer['uid']?.toString();

    if (uid == null || uid.isEmpty) {
      return const _Rating(null, 0);
    }

    return _fetchRatingFromReviews(uid);
  }

  Future<_Rating> _fetchRatingFromReviews(String trainerUid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .collection('reviews')
          .get();

      final count = snap.docs.length;

      if (count == 0) {
        return const _Rating(null, 0);
      }

      double total = 0;

      for (final doc in snap.docs) {
        total += _toDouble(doc.data()['rating']) ?? 0;
      }

      return _Rating(total / count, count);
    } catch (e, st) {
      debugPrint('Error fetching average rating: $e');

      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Fetch reviews for rating failed',
      );

      return const _Rating(null, 0);
    }
  }

  String _displayName() {
    final first = _clean(widget.trainerData['firstName']);
    final last = _clean(widget.trainerData['lastName']);

    final fullName = [first, last].where((v) => v.isNotEmpty).join(' ').trim();

    if (fullName.isNotEmpty) return fullName;

    final fallback = widget.name.trim();

    return fallback.isNotEmpty ? fallback : 'Trainer';
  }

  String _displayLocation() {
    final location = widget.location.trim();

    if (location.isNotEmpty) return location;

    final suburb = _clean(widget.trainerData['suburb']);
    final city = _clean(widget.trainerData['city']);
    final state = _clean(widget.trainerData['state']);

    final parts = [suburb, city, state].where((v) => v.isNotEmpty).toList();

    if (parts.isNotEmpty) {
      return parts.take(2).join(', ');
    }

    return 'Location not listed';
  }

  String? _displayRate() {
    final rawRate = widget.trainerData['rate'] ??
        widget.trainerData['hourlyRate'] ??
        widget.trainerData['pricePerHour'] ??
        widget.trainerData['sessionRate'] ??
        widget.trainerData['price'];

    final rate = _toDouble(rawRate);

    if (rate == null || rate <= 0) {
      return null;
    }

    final rounded =
        rate % 1 == 0 ? rate.toInt().toString() : rate.toStringAsFixed(0);

    return '\$$rounded/hr';
  }

  String? _coachingIdentityLabel() {
    final completed = widget.trainerData['trainerQuizCompleted'] == true ||
        widget.trainerData['coachingQuizCompleted'] == true ||
        widget.trainerData['coachingIdentityCompleted'] == true ||
        widget.trainerData['identityQuizCompleted'] == true ||
        widget.trainerData['hasCoachingIdentity'] == true;

    if (!completed) return null;

    final raw = widget.trainerData['coachingIdentity'] ??
        widget.trainerData['coachingIdentityLabel'] ??
        widget.trainerData['trainerIdentity'] ??
        widget.trainerData['trainerIdentityLabel'] ??
        widget.trainerData['identityLabel'] ??
        widget.trainerData['identityType'] ??
        widget.trainerData['archetype'];

    String label = '';

    if (raw is Map) {
      label = _clean(
        raw['title'] ??
            raw['name'] ??
            raw['label'] ??
            raw['type'] ??
            raw['identity'],
      );
    } else {
      label = _clean(raw);
    }

    if (label.isEmpty) return null;

    final lower = label.toLowerCase();

    final invalid = lower.contains('not completed') ||
        lower.contains('unknown') ||
        lower.contains('none') ||
        lower == 'null';

    if (invalid) return null;

    return label;
  }

  List<String> _cleanSpecialties() {
    return widget.specialties
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final location = _displayLocation();
    final rate = _displayRate();
    final identity = _coachingIdentityLabel();
    final specialties = _cleanSpecialties();

    final profileImageUrl = widget.profileImageUrl?.trim() ?? '';

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _line,
          width: 1,
        ),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF171B22),
            Color(0xFF111318),
            Color(0xFF0B0D10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _imageHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _TrainerImage(profileImageUrl: profileImageUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x9907080A),
                      ],
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                if (identity != null)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: _IdentityPill(label: identity),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 15.8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.15,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        color: _muted,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12.2,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<_Rating>(
                          future: _ratingFuture ??=
                              _resolveRating(widget.trainerData),
                          builder: (context, snapshot) {
                            final rating =
                                snapshot.data ?? const _Rating(null, 0);

                            final hasRating =
                                rating.avg != null && rating.count > 0;

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const _RatingPill(
                                label: 'Loading',
                                loading: true,
                              );
                            }

                            return _RatingPill(
                              label: hasRating
                                  ? '${rating.avg!.toStringAsFixed(1)} (${rating.count})'
                                  : 'New',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 7),
                      _RatePill(label: rate ?? 'Rate n/a'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SpecialtyRow(
                    specialties: specialties,
                    categoryColors: widget.categoryColors,
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // MarketplacePage already wraps this widget in an InkWell.
    // Returning the plain card here prevents the child from blocking parent taps.
    if (widget.onTap == null) {
      return card;
    }

    // Still supports standalone usage elsewhere if onTap is passed directly.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        child: card,
      ),
    );
  }
}

class _TrainerImage extends StatelessWidget {
  final String profileImageUrl;

  const _TrainerImage({
    required this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (profileImageUrl.isEmpty) {
      return Image.asset(
        'assets/default_profile.png',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      );
    }

    return CachedNetworkImage(
      imageUrl: profileImageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      placeholder: (context, url) {
        return Container(
          color: _surfaceRaised,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _gold,
              ),
            ),
          ),
        );
      },
      errorWidget: (context, url, error) {
        FirebaseCrashlytics.instance.recordError(
          error,
          StackTrace.current,
          reason: 'Trainer profile image failed to load',
        );

        return Image.asset(
          'assets/default_profile.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        );
      },
    );
  }
}

class _IdentityPill extends StatelessWidget {
  final String label;

  const _IdentityPill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _gold.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: _gold,
            size: 13,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontSize: 11.2,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final String label;
  final bool loading;

  const _RatingPill({
    required this.label,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _surfaceRaised.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: _gold,
              ),
            )
          else
            const Icon(
              Icons.star_rounded,
              size: 14,
              color: _gold,
            ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontSize: 11.4,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatePill extends StatelessWidget {
  final String label;

  const _RatePill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _gold.withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _gold,
          fontSize: 11.4,
          fontWeight: FontWeight.w900,
          height: 1.6,
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
    if (specialties.isEmpty) {
      return const SizedBox(
        height: 26,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Specialties not listed',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _muted,
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final visible = specialties.take(2).toList();
    final remaining = specialties.length - visible.length;

    return SizedBox(
      height: 26,
      child: Row(
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            Expanded(
              child: _SpecialtyChip(
                label: visible[i],
                color: categoryColors[visible[i]] ?? Colors.grey,
              ),
            ),
            if (i != visible.length - 1) const SizedBox(width: 6),
          ],
          if (remaining > 0) ...[
            const SizedBox(width: 6),
            _MoreSpecialtyChip(label: '+$remaining'),
          ],
        ],
      ),
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
      height: 26,
      constraints: const BoxConstraints(minWidth: 0),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.95),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                color: _text,
                fontSize: 10.8,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreSpecialtyChip extends StatelessWidget {
  final String label;

  const _MoreSpecialtyChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _surfaceRaised.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          style: const TextStyle(
            color: _muted,
            fontSize: 10.8,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
