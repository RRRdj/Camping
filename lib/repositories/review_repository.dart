/// lib/repositories/review_repository.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// 사용자 리뷰 저장소: Firestore 및 Storage 동기화
class ReviewRepository {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = Uuid();

  String get _uid => _auth.currentUser!.uid;

  /// 내가 쓴 리뷰 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> userReviewsStream() {
    final uid = _uid;
    return _fire
        .collection('user_reviews')
        .doc(uid)
        .collection('reviews')
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// 리뷰 생성 (user_reviews + campground_reviews 동기화)
  Future<void> addReview({
    required String contentId,
    required String campName,
    required int rating,
    required String content,
    List<XFile>? imageFiles,
  }) async {
    final uid = _uid;
    final now = DateTime.now();
    final batch = _fire.batch();

    // 이미지 업로드
    List<String> imageUrls = [];
    if (imageFiles != null) {
      for (final file in imageFiles) {
        final ext = file.path.split('.').last;
        final ref = _storage
            .ref('review_images/$contentId/$uid')
            .child('${_uuid.v4()}.$ext');
        final task = await ref.putFile(File(file.path));
        imageUrls.add(await task.ref.getDownloadURL());
      }
    }

    // 새로운 문서 ID
    final docId = _fire
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .doc()
        .id;

    final data = {
      'userId': uid,
      'campName': campName,
      'rating': rating,
      'content': content,
      'date': now,
      'imageUrls': imageUrls,
    };

    // 배치로 두 컬렉션에 동기화
    batch.set(
      _fire
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .doc(docId),
      data,
    );
    batch.set(
      _fire
          .collection('user_reviews')
          .doc(uid)
          .collection('reviews')
          .doc(docId),
      data,
    );

    await batch.commit();
  }

  /// 리뷰 수정 (user_reviews + campground_reviews 동기화, 이미지 추가/삭제)
  Future<void> updateReview({
    required String contentId,
    required String reviewId,
    required int rating,
    required String content,
    List<XFile>? newImageFiles,
    List<String>? removeImageUrls,
  }) async {
    final uid = _uid;
    final batch = _fire.batch();

    // 문서 참조
    final campRef = _fire
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .doc(reviewId);
    final userRef = _fire
        .collection('user_reviews')
        .doc(uid)
        .collection('reviews')
        .doc(reviewId);

    // 기존 URL 로드
    final snap = await campRef.get();
    List<String> urls = List<String>.from(snap.data()?['imageUrls'] ?? []);

    // 이미지 삭제
    if (removeImageUrls != null) {
      for (final url in removeImageUrls) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (_) {}
        urls.remove(url);
      }
    }

    // 새로운 이미지 업로드
    if (newImageFiles != null) {
      for (final file in newImageFiles) {
        final ext = file.path.split('.').last;
        final ref = _storage
            .ref('review_images/$contentId/$uid')
            .child('${_uuid.v4()}.$ext');
        final task = await ref.putFile(File(file.path));
        urls.add(await task.ref.getDownloadURL());
      }
    }

    // 업데이트 데이터
    final updateData = {
      'rating': rating,
      'content': content,
      'imageUrls': urls,
      'date': FieldValue.serverTimestamp(),
    };

    // 배치로 동기화
    batch.update(campRef, updateData);
    batch.update(userRef, updateData);
    await batch.commit();
  }



/// 리뷰 삭제 (user_reviews + campground_reviews 동기화)
  Future<void> deleteReview({
    required String userReviewId,
    required String? contentId,
    required String? content,
    required Timestamp? date,
  }) async {
    final uid = _uid!;
    // Firestore 직접 ID 참조
    final docId = userReviewId;
    final batch = _fire.batch();
    if (contentId != null) {
      batch.delete(
        _fire
            .collection('campground_reviews')
            .doc(contentId)
            .collection('reviews')
            .doc(docId),
      );
    }
    batch.delete(
      _fire
          .collection('user_reviews')
          .doc(uid)
          .collection('reviews')
          .doc(docId),
    );
    await batch.commit();
  }
}


