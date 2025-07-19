// lib/services/block_service.dart
// Simple helper for user-blocking using Firebase Auth + Cloud Firestore.
// Works on both iOS & Android without any extra plugins.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class BlockService {
  /* ---------------  Singleton pattern --------------- */
  BlockService._();                     // private constructor
  static final BlockService instance = BlockService._();

  /* ---------------  Firebase handles --------------- */
  final FirebaseFirestore _db  = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  /* ---------------  Convenience getter --------------- */
  String get _myUid {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'NO_USER',
        message: 'User must be signed in to use blocking functions',
      );
    }
    return user.uid;
  }

  /* ---------------  Public API --------------- */

  /// Block [otherUid].  Creates /users/{me}/blocked/{otherUid}
  Future<void> block(String otherUid) async {
    if (otherUid.isEmpty) return;
    await _db
        .collection('users')
        .doc(_myUid)
        .collection('blocked')
        .doc(otherUid)
        .set({'blockedAt': FieldValue.serverTimestamp()});
  }

  /// Remove block entry (unblock)
  Future<void> unblock(String otherUid) async {
    if (otherUid.isEmpty) return;
    await _db
        .collection('users')
        .doc(_myUid)
        .collection('blocked')
        .doc(otherUid)
        .delete();
  }

  /// Return *my* blocked UID list
  Future<List<String>> blockedIds() async {
    final snap = await _db
        .collection('users')
        .doc(_myUid)
        .collection('blocked')
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Did *I* block [otherUid]?
  Future<bool> iBlocked(String otherUid) async {
    final doc = await _db
        .collection('users')
        .doc(_myUid)
        .collection('blocked')
        .doc(otherUid)
        .get();
    return doc.exists;
  }

  /// Did *they* block *me*?
  Future<bool> blockedMe(String otherUid) async {
    final doc = await _db
        .collection('users')
        .doc(otherUid)
        .collection('blocked')
        .doc(_myUid)
        .get();
    return doc.exists;
  }

  /// TRUE if either side has blocked the other.
  Future<bool> blockingEitherWay(String otherUid) async {
    final results = await Future.wait([
      iBlocked(otherUid),
      blockedMe(otherUid),
    ]);
    return results.any((e) => e);
  }
}