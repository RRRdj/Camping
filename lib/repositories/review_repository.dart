import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewRepository {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// 스트림: 내가 쓴 리뷰
  Stream<QuerySnapshot<Map<String, dynamic>>> userReviewsStream() {
    if (_uid == null) {
      return const Stream.empty();
    }
    return _fire
        .collection('user_reviews')
        .doc(_uid)
        .collection('reviews')
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// 리뷰 삭제: user_reviews + campground_reviews 동기화
  Future<void> deleteReview({
    required String userReviewId,
    required String? contentId,
    required String? content,
    required Timestamp? date,
  }) async {
    if (_uid == null) return;
    // 1) user_reviews 컬렉션
    await _fire
        .collection('user_reviews')
        .doc(_uid)
        .collection('reviews')
        .doc(userReviewId)
        .delete();

    // 2) campground_reviews 컬렉션
    if (contentId != null &&
        contentId.isNotEmpty &&
        content != null &&
        date != null) {
      final query =
          await _fire
              .collection('campground_reviews')
              .doc(contentId)
              .collection('reviews')
              .where('userId', isEqualTo: _uid)
              .where('content', isEqualTo: content)
              .where('date', isEqualTo: date)
              .get();
      for (final d in query.docs) {
        await d.reference.delete();
      }
    }
  }

  /// 리뷰 수정
  Future<void> updateReview({
    required String userReviewId,
    required String? contentId,
    required String? oldContent,
    required Timestamp? date,
    required String newContent,
    required int newRating,
  }) async {
    if (_uid == null || contentId == null || contentId.isEmpty || date == null)
      return;

    // 1) user_reviews 업데이트
    await _fire
        .collection('user_reviews')
        .doc(_uid)
        .collection('reviews')
        .doc(userReviewId)
        .update({'content': newContent, 'rating': newRating});

    // 2) campground_reviews 업데이트
    final query =
        await _fire
            .collection('campground_reviews')
            .doc(contentId)
            .collection('reviews')
            .where('userId', isEqualTo: _uid)
            .where('content', isEqualTo: oldContent)
            .where('date', isEqualTo: date)
            .get();
    for (final d in query.docs) {
      await d.reference.update({'content': newContent, 'rating': newRating});
    }
  }
}
