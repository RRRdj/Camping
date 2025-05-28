/// lib/repositories/camp_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// 데이터 영속 계층: Firestore 액세스 전담
class CampRepository {
  final _firestore = FirebaseFirestore.instance;

  // ─── 캠핑장 기본 정보 ───
  Future<DocumentSnapshot<Map<String, dynamic>>> getCamp(String campName) {
    return _firestore.collection('campgrounds').doc(campName).get();
  }

  // ─── 사용자 ───
  Future<String?> getUserNickname(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['nickname'] as String?;
  }

  // ─── 리뷰 ───
  Stream<QuerySnapshot<Map<String, dynamic>>> getReviews(String contentId) {
    return _firestore
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> addReview({
    required String contentId,
    required String campName,
    required int rating,
    required String content,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final nick = await getUserNickname(user.uid) ?? '';
    final now = DateTime.now();

    final reviewData = {
      'userId': user.uid,
      'nickname': nick,
      'email': user.email ?? '',
      'rating': rating,
      'content': content,
      'date': now,
    };

    final userReviewData = {
      'contentId': contentId,
      'campName': campName,
      'rating': rating,
      'content': content,
      'date': now,
    };

    final batch = _firestore.batch();
    batch.set(
      _firestore
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .doc(),
      reviewData,
    );
    batch.set(
      _firestore
          .collection('user_reviews')
          .doc(user.uid)
          .collection('reviews')
          .doc(),
      userReviewData,
    );
    await batch.commit();
  }

  Future<void> updateReview({
    required String contentId,
    required String reviewId,
    required int rating,
    required String content,
  }) {
    return _firestore
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .doc(reviewId)
        .update({
          'rating': rating,
          'content': content,
          'date': FieldValue.serverTimestamp(),
        });
  }

  Future<void> deleteReview(String contentId, String reviewId) {
    return _firestore
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .doc(reviewId)
        .delete();
  }

  Future<void> reportReview({
    required String contentId,
    required String reviewId,
    required String reportedUserId,
    required String reason,
  }) async {
    final reporter = FirebaseAuth.instance.currentUser!;
    final nick = await getUserNickname(reporter.uid) ?? '';

    final batch = _firestore.batch();
    batch.set(_firestore.collection('review_reports').doc(), {
      'contentId': contentId,
      'reviewId': reviewId,
      'reportedUserId': reportedUserId,
      'reporterUid': reporter.uid,
      'reporterEmail': reporter.email ?? '',
      'reporterNickname': nick,
      'reason': reason,
      'date': FieldValue.serverTimestamp(),
    });

    batch.update(
      _firestore
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .doc(reviewId),
      {'reportCount': FieldValue.increment(1)},
    );

    await batch.commit();
  }

  // ─── 알림 ───
  Future<int> alarmsCount(String uid) async {
    final snap =
        await _firestore
            .collection('user_alarm_settings')
            .doc(uid)
            .collection('alarms')
            .get();
    return snap.size;
  }

  Future<void> addAlarm({
    required String campName,
    required String? contentId,
    required DateTime date,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;

    await _firestore.collection('user_alarm_settings').doc(user.uid).set({
      'lastAlarmAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore
        .collection('user_alarm_settings')
        .doc(user.uid)
        .collection('alarms')
        .add({
          'campName': campName,
          'contentId': contentId,
          'date': DateFormat('yyyy-MM-dd').format(date),
          'isNotified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
