import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Reviews",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("trainer_profiles")
              .doc(trainerUid)
              .collection("reviews")
              .orderBy("timestamp", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final reviews = snapshot.data!.docs;
            if (reviews.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 10), // Adjusted padding
                child: Text("No reviews yet.", style: TextStyle(fontSize: 16)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                final reviewData = review.data() as Map<String, dynamic>;
                final reviewerName = reviewData["reviewerName"] ?? "Anonymous";
                final rating = reviewData["rating"] ?? 0;
                final comment = reviewData["comment"] ?? "";
                final Timestamp ts = reviewData["timestamp"] ?? Timestamp.now();
                final DateTime time = ts.toDate();

                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 6), // Adjusted margin
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0), // Increased padding
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50, // Increased width
                          height: 50, // Increased height
                          decoration: const BoxDecoration(
                            color: Colors.lightBlue,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14, // Adjusted font size
                            ),
                          ),
                        ),
                        const SizedBox(width: 12), // Ensure adequate spacing
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reviewerName,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold), // Increased font size
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment,
                                style: const TextStyle(
                                    fontSize: 16), // Increased font size
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${time.day}/${time.month}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors
                                      .grey), // Maintained smaller size for the date
                            ),
                            IconButton(
                              icon: const Icon(Icons.flag, color: Colors.red),
                              tooltip: "Report this review",
                              onPressed: () {
                                showReportDialog(context, review.id);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void showReportDialog(BuildContext context, String reviewId) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Report Review"),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Why are you reporting this review?",
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Submit"),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;

                final user = FirebaseAuth.instance.currentUser;

                // Safely capture context objects before async gap
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.of(context).pop(); // Close the dialog initially

                try {
                  await FirebaseFirestore.instance.collection('reports').add({
                    'reportedBy': user?.uid ?? 'unknown',
                    'reportedItemId': reviewId,
                    'reportedType': 'review',
                    'reason': reason,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text("Report submitted")),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text("Error submitting report: ${e.toString()}"),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
