// lib/repositories/camp_repository.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import '../models/camp_with_availability.dart';

class CampRepository {
  CampRepository({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final http.Client _client;

  /* ───────── 기본 캠핑장/예약 데이터 ───────── */

  Stream<List<Map<String, dynamic>>> campgroundsStream() => _firestore
      .collection('campgrounds')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => d.data() as Map<String, dynamic>).toList(),
      );

  Stream<Map<String, Map<String, dynamic>>> availabilityStream() =>
      _firestore.collection('realtime_availability').snapshots().map((snap) {
        final map = <String, Map<String, dynamic>>{};
        for (var d in snap.docs) {
          map[d.id] = d.data() as Map<String, dynamic>;
        }
        return map;
      });

  Future<DocumentSnapshot<Map<String, dynamic>>> campgroundDoc(
    String campName,
  ) => _firestore.collection('campgrounds').doc(campName).get();

  /* ───────── 캠핑장 이미지 (공공 API) ───────── */

  static const _serviceKey =
      'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';

  Future<List<String>> campImages(String contentId, String? firstUrl) async {
    if (contentId.isEmpty) return [];
    final uri = Uri.parse(
      'https://apis.data.go.kr/B551011/GoCamping/imageList',
    ).replace(
      queryParameters: {
        'serviceKey': _serviceKey,
        'contentId': contentId,
        'MobileOS': 'AND',
        'MobileApp': 'camping',
        'numOfRows': '20',
        'pageNo': '1',
        '_type': 'XML',
      },
    );

    final resp = await _client.get(uri);
    if (resp.statusCode != 200) return [];

    final doc = XmlDocument.parse(utf8.decode(resp.bodyBytes));
    final urls =
        doc
            .findAllElements('imageUrl')
            .map((e) => e.text.trim())
            .where((u) => u.isNotEmpty)
            .toList();

    if (firstUrl != null && firstUrl.isNotEmpty && !urls.contains(firstUrl)) {
      urls.insert(0, firstUrl);
    }
    return urls;
  }

  /* ───────── 유저 관련 ───────── */

  Future<String?> userNickname(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['nickname'] as String?;
  }

  /* ───────── 알림(빈자리 감시) ───────── */

  Future<int> userAlarmCount(String uid) async {
    final snap =
        await _firestore
            .collection('user_alarm_settings')
            .doc(uid)
            .collection('alarms')
            .get();
    return snap.docs.length;
  }

  Future<void> addAlarm({
    required String uid,
    required String campName,
    required String contentId,
    required DateTime date,
  }) async {
    await _firestore
        .collection('user_alarm_settings')
        .doc(uid)
        .collection('alarms')
        .add({
          'campName': campName,
          'contentId': contentId,
          'date': DateFormat('yyyy-MM-dd').format(date),
          'isNotified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /* ───────── 리뷰 ───────── */

  Stream<QuerySnapshot> reviewsStream(String contentId) =>
      _firestore
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .snapshots();

  Future<void> addReview({
    required String contentId,
    required Map<String, dynamic> campgroundReview,
    required Map<String, dynamic> userReview,
    required String userUid,
  }) async {
    final batch = _firestore.batch();
    final campRef =
        _firestore
            .collection('campground_reviews')
            .doc(contentId)
            .collection('reviews')
            .doc();
    final userRef =
        _firestore
            .collection('user_reviews')
            .doc(userUid)
            .collection('reviews')
            .doc();

    batch.set(campRef, campgroundReview);
    batch.set(userRef, userReview);
    await batch.commit();
  }

  Future<void> updateReview({
    required String contentId,
    required String reviewId,
    required int rating,
    required String content,
  }) => _firestore
      .collection('campground_reviews')
      .doc(contentId)
      .collection('reviews')
      .doc(reviewId)
      .update({
        'rating': rating,
        'content': content,
        'date': FieldValue.serverTimestamp(),
      });

  Future<void> deleteReview({
    required String contentId,
    required String reviewId,
  }) =>
      _firestore
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .doc(reviewId)
          .delete();

  Future<void> reportReview({
    required String contentId,
    required String reviewId,
    required String reportedUserId,
    required Map<String, dynamic> reportData,
  }) async {
    final batch = _firestore.batch();
    final reportRef = _firestore.collection('review_reports').doc();
    batch.set(reportRef, reportData);

    final reviewRef = _firestore
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .doc(reviewId);
    batch.update(reviewRef, {'reportCount': FieldValue.increment(1)});
    await batch.commit();
  }

  /* ───────── 캠핑장 + 예약현황 합친 단일 스트림 ───────── */

  Stream<List<CampWithAvailability>> campWithAvailStream(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return campgroundsStream().combineLatest(availabilityStream(), (
      List<Map<String, dynamic>> camps,
      Map<String, Map<String, dynamic>> availMap,
    ) {
      return camps.map((c) {
        final a = availMap[c['name']]?[key] as Map<String, dynamic>? ?? {};
        return CampWithAvailability(
          camp: c,
          available: a['available'] as int? ?? (c['available'] as int? ?? 0),
          total: a['total'] as int? ?? (c['total'] as int? ?? 0),
        );
      }).toList();
    });
  }
}

/// RxDart 없이 간단히 두 스트림을 합치는 combineLatest 확장
extension _CombineLatestExt<T> on Stream<T> {
  Stream<R> combineLatest<S, R>(
    Stream<S> other,
    R Function(T a, S b) combiner,
  ) {
    late T lastA;
    late S lastB;
    bool hasA = false, hasB = false;
    final controller = StreamController<R>();

    final subA = listen((a) {
      lastA = a;
      hasA = true;
      if (hasB) controller.add(combiner(lastA, lastB));
    });
    final subB = other.listen((b) {
      lastB = b;
      hasB = true;
      if (hasA) controller.add(combiner(lastA, lastB));
    });

    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
    };
    return controller.stream;
  }
}
