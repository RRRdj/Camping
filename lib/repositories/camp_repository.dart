/// lib/repositories/camp_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

/// 데이터 영속 계층: Firestore + Storage 액세스 전담
class CampRepository {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _uuid = Uuid();

  // ─── 캠핑장 기본 정보 ───
  Future<DocumentSnapshot<Map<String, dynamic>>> getCamp(String campName) {
    return _firestore.collection('campgrounds').doc(campName).get();
  }

  // ─── 사용자 닉네임 조회 ───
  Future<String?> getUserNickname(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['nickname'] as String?;
  }

  // ─── 리뷰 목록 구독 ───
  Stream<QuerySnapshot<Map<String, dynamic>>> getReviews(String contentId) {
    return _firestore
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .orderBy('date', descending: true)
        .snapshots();
  }


  /// 리뷰 생성 (campground_reviews & user_reviews 동기화)
  Future<void> addReview({
    required String contentId,
    required String campName,
    required int rating,
    required String content,
    List<XFile>? imageFiles,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final nick = await getUserNickname(user.uid) ?? '';
    final now  = DateTime.now();

    // 1) 이미지 업로드 및 URL 수집
    List<String> imageUrls = [];
    if (imageFiles != null) {
      for (final file in imageFiles) {
        final ext = file.path.split('.').last;
        final ref = _storage.ref('review_images/$contentId/${_uuid.v4()}.$ext');
        final task = await ref.putFile(File(file.path));
        imageUrls.add(await task.ref.getDownloadURL());
      }
    }

    // 2) Firestore 문서 참조 생성
    final reviewDoc = _firestore
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .doc();

    final reviewData = {
      'userId': user.uid,
      'nickname': nick,
      'email': user.email ?? '',
      'rating': rating,
      'content': content,
      'date': now,
      'imageUrls': imageUrls,
    };

    final userReviewData = {
      'contentId': contentId,
      'campName': campName,
      'rating': rating,
      'content': content,
      'date': now,
      'imageUrls': imageUrls,
    };

    // 3) 배치로 두 컬렉션에 동기화
    final batch = _firestore.batch();
    batch.set(reviewDoc, reviewData);
    batch.set(
      _firestore
          .collection('user_reviews')
          .doc(user.uid)
          .collection('reviews')
          .doc(reviewDoc.id),
      userReviewData,
    );
    await batch.commit();
  }

  /// 리뷰 수정 (campground_reviews & user_reviews 동기화)
  Future<void> updateReview({
    required String contentId,
    required String reviewId,
    required int rating,
    required String content,
    List<XFile>? newImageFiles,
    List<String>? removeImageUrls,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;

    // 1) 캠핑장 리뷰 문서 참조
    final campRef = _firestore
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .doc(reviewId);

    final snap = await campRef.get();
    final data = snap.data()!;
    List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);

    // 2) 삭제할 이미지 처리
    if (removeImageUrls != null) {
      for (final url in removeImageUrls) {
        try {
          await _storage.refFromURL(url).delete();
          imageUrls.remove(url);
        } catch (_) {}
      }
    }

    // 3) 새 이미지 업로드
    if (newImageFiles != null) {
      for (final file in newImageFiles) {
        final ext = file.path.split('.').last;
        final ref = _storage.ref('review_images/$contentId/${_uuid.v4()}.$ext');
        final task = await ref.putFile(File(file.path));
        imageUrls.add(await task.ref.getDownloadURL());
      }
    }

    final updateData = {
      'rating': rating,
      'content': content,
      'imageUrls': imageUrls,
      'date': FieldValue.serverTimestamp(),
    };

    // 4) 배치로 두 컬렉션에 업데이트
    final batch = _firestore.batch();
    batch.update(campRef, updateData);
    batch.update(
      _firestore
          .collection('user_reviews')
          .doc(user.uid)
          .collection('reviews')
          .doc(reviewId),
      updateData,
    );
    await batch.commit();
  }

  /// 리뷰 삭제 (campground_reviews & user_reviews 동기화)
  Future<void> deleteReview(String contentId, String reviewId) async {
    final user = FirebaseAuth.instance.currentUser!;
    final batch = _firestore.batch();
    batch.delete(
      _firestore
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .doc(reviewId),
    );
    batch.delete(
      _firestore
          .collection('user_reviews')
          .doc(user.uid)
          .collection('reviews')
          .doc(reviewId),
    );
    await batch.commit();
  }

  // ─── 리뷰 신고 ───
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

  // ─── 알림 개수 조회 ───
  Future<int> alarmsCount(String uid) async {
    final snap = await _firestore
        .collection('user_alarm_settings')
        .doc(uid)
        .collection('alarms')
        .get();
    return snap.size;
  }

  // ─── 알림 설정 ───
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
