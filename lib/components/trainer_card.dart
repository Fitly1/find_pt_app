import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrainerCard extends StatefulWidget {
  final String name;
  final List<String> specialties;
  final String location;
  final Map<String, Color> categoryColors;
  final String? profileImageUrl;
  final Map<String, dynamic> trainerData; // Must include "uid"
  final VoidCallback? onTap; // Delegate tap handling

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

class _TrainerCardState extends State<TrainerCard> {
  late Future<double> _averageRatingFuture;

  @override
  void initState() {
    super.initState();
    _averageRatingFuture = _fetchAverageRating(widget.trainerData["uid"]);
  }

  /// Fetch the average rating from the trainer's "reviews" subcollection.
  Future<double> _fetchAverageRating(String trainerUid) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection("trainer_profiles")
          .doc(trainerUid)
          .collection("reviews")
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data["rating"] as num?)?.toDouble() ?? 0.0;
      }
      return total / snapshot.docs.length;
    } catch (e) {
      debugPrint("Error fetching average rating: $e");
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Combine firstName and lastName if available; otherwise use the provided name.
    String displayName = '';
    if (widget.trainerData["firstName"] != null) {
      displayName = widget.trainerData["firstName"];
      if (widget.trainerData["lastName"] != null &&
          widget.trainerData["lastName"].toString().trim().isNotEmpty) {
        displayName += " ${widget.trainerData["lastName"]}";
      }
    }
    if (displayName.isEmpty) {
      displayName = widget.name.isNotEmpty ? widget.name : "Trainer";
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section takes most of the card.
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: (widget.profileImageUrl != null &&
                        widget.profileImageUrl!.isNotEmpty)
                    ? Image.network(
                        widget.profileImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
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
            // Information section with minimal vertical spacing.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trainer Name
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
                  // Specialties using Wrap.
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
                            label: Text(
                              '...',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            backgroundColor: Colors.grey,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Average Rating using stored Future with larger star and text.
                  FutureBuilder<double>(
                    future: _averageRatingFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      } else if (snapshot.hasError) {
                        return const Text("Error",
                            style: TextStyle(fontSize: 14));
                      } else {
                        final avgRating = snapshot.data ?? 0.0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        );
                      }
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
