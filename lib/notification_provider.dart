import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationState {
  final int unreadMessages;
  final int newReviews;

  const NotificationState({
    this.unreadMessages = 0,
    this.newReviews = 0,
  });

  NotificationState copyWith({int? unreadMessages, int? newReviews}) {
    return NotificationState(
      unreadMessages: unreadMessages ?? this.unreadMessages,
      newReviews: newReviews ?? this.newReviews,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState()) {
    _listenForNotifications();
  }

  void updateUnreadMessages(int count) {
    state = state.copyWith(unreadMessages: count);
  }

  void updateNewReviews(int count) {
    state = state.copyWith(newReviews: count);
  }

  void _listenForNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic> unreadBy = data['unreadBy'] ?? [];
        debugPrint("Doc ${doc.id} unreadBy: $unreadBy");
        if (unreadBy.contains(user.uid)) {
          unreadCount++;
        }
      }
      debugPrint("Final unread count: $unreadCount");
      updateUnreadMessages(unreadCount);
    });
    // Optionally, add a similar listener for new reviews.
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(),
);
