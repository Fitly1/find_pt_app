// lib/trainer_reviews_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/* ───────────────── Fitly premium colours ───────────────── */
const Color _fitlyInk = Color(0xFF07080A);
const Color _fitlySurface = Color(0xFF111318);
const Color _fitlySurfaceRaised = Color(0xFF20242C);
const Color _fitlyLine = Color(0xFF303540);
const Color _fitlyGold = Color(0xFFE7B95C);
const Color _fitlyMuted = Color(0xFFA6ADB8);
const Color _fitlyText = Color(0xFFF5F6F8);

class TrainerReviewsSection extends StatelessWidget {
  final String trainerUid;
  final bool allowReview;

  const TrainerReviewsSection({
    super.key,
    required this.trainerUid,
    this.allowReview = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(trainerUid)
          .collection('reviews')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final isLoading = !snapshot.hasData;
        final reviews = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewsHeader(
              count: isLoading ? null : reviews.length,
            ),
            const SizedBox(height: 10),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: _fitlyGold,
                      strokeWidth: 2.2,
                    ),
                  ),
                ),
              )
            else if (reviews.isEmpty)
              const _EmptyReviewsState()
            else
              _ReviewsList(
                reviews: reviews,
                onReport: (reviewId) => _showReportDialog(context, reviewId),
              ),
          ],
        );
      },
    );
  }

  void _showReportDialog(BuildContext context, String reviewId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _fitlySurface,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: _fitlyLine),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Report review',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _fitlyText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tell us what looks wrong.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _fitlyMuted,
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _fitlyText,
                          side: const BorderSide(color: _fitlyLine),
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _fitlyGold,
                          foregroundColor: _fitlyInk,
                          elevation: 0,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) return;

                          final user = FirebaseAuth.instance.currentUser;
                          final messenger = ScaffoldMessenger.of(context);

                          Navigator.pop(dialogContext);

                          try {
                            await FirebaseFirestore.instance
                                .collection('reports')
                                .add({
                              'reportedBy': user?.uid ?? 'unknown',
                              'reportedItemId': reviewId,
                              'reportedType': 'review',
                              'reason': reason,
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Report submitted.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Could not submit report: $e'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Submit',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReviewsHeader extends StatelessWidget {
  final int? count;

  const _ReviewsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    final countText = count == null ? '' : ' ${count.toString()}';

    return Row(
      children: [
        const Text(
          'Reviews',
          style: TextStyle(
            color: _fitlyText,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            countText,
            style: const TextStyle(
              color: _fitlyMuted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyReviewsState extends StatelessWidget {
  const _EmptyReviewsState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 2, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No reviews yet.',
            style: TextStyle(
              color: _fitlyText,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Reviews will appear here.',
            style: TextStyle(
              color: _fitlyMuted,
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  final List<QueryDocumentSnapshot> reviews;
  final ValueChanged<String> onReport;

  const _ReviewsList({
    required this.reviews,
    required this.onReport,
  });

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is! Timestamp) return '';

    final time = timestamp.toDate();
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    final year = time.year.toString();

    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(reviews.length, (index) {
        final review = reviews[index];
        final data = review.data() as Map<String, dynamic>;

        return Column(
          children: [
            _ReviewRow(
              reviewId: review.id,
              reviewerName: (data['reviewerName'] ?? 'Anonymous').toString(),
              rating: _toDouble(data['rating']),
              comment: (data['comment'] ?? '').toString(),
              date: _formatDate(data['timestamp']),
              onReport: onReport,
            ),
            if (index != reviews.length - 1)
              Divider(
                height: 22,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
          ],
        );
      }),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String reviewId;
  final String reviewerName;
  final double rating;
  final String comment;
  final String date;
  final ValueChanged<String> onReport;

  const _ReviewRow({
    required this.reviewId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.date,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final ratingText = rating <= 0 ? '—' : rating.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _fitlyGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _fitlyGold.withValues(alpha: 0.22)),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: _fitlyGold,
                  size: 14,
                ),
                const SizedBox(width: 2),
                Text(
                  ratingText,
                  style: const TextStyle(
                    color: _fitlyText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _fitlyText,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: const TextStyle(
                      color: _fitlyMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    comment,
                    style: const TextStyle(
                      color: Color(0xFFE7E9EE),
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.flag_outlined,
              color: _fitlyMuted,
              size: 19,
            ),
            tooltip: 'Report review',
            onPressed: () => onReport(reviewId),
          ),
        ],
      ),
    );
  }
}
