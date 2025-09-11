import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminReviewScreen extends StatelessWidget {
  const AdminReviewScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _reportColl =>
      FirebaseFirestore.instance.collection('review_reports');

  CollectionReference<Map<String, dynamic>> get _campColl =>
      FirebaseFirestore.instance.collection('campgrounds');

  CollectionReference<Map<String, dynamic>> _campReviewColl(String contentId) =>
      FirebaseFirestore.instance
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews');

  CollectionReference<Map<String, dynamic>> _userReviewColl(String userId) =>
      FirebaseFirestore.instance
          .collection('user_reviews')
          .doc(userId)
          .collection('reviews');

  // 간단 메모이즈: 동일 contentId/camp, review를 반복 조회할 때 낭비 방지
  static final Map<String, Future<QuerySnapshot<Map<String, dynamic>>>>
  _campByContentIdFuture = {};
  static final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
  _reviewDocFuture = {};

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchCampByContentId(
    String contentId,
  ) {
    return _campByContentIdFuture.putIfAbsent(
      contentId,
      () => _campColl.where('contentId', isEqualTo: contentId).limit(1).get(),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchReviewDoc(
    String contentId,
    String reviewId,
  ) {
    final key = '$contentId::$reviewId';
    return _reviewDocFuture.putIfAbsent(
      key,
      () => _campReviewColl(contentId).doc(reviewId).get(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('신고된 후기 관리')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _reportColl.orderBy('date', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('불러오기 실패: ${snap.error}'));
          }
          final reports = snap.data?.docs ?? [];
          if (reports.isEmpty) {
            return const Center(child: Text('신고된 후기가 없습니다.'));
          }

          return ListView.separated(
            itemCount: reports.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, idx) {
              final reportDoc = reports[idx];
              final report = reportDoc.data();

              final reporterNick =
                  (report['reporterNickname'] as String?) ?? '익명';
              final reporterEmail = (report['reporterEmail'] as String?) ?? '';
              final reason = (report['reason'] as String?) ?? '';
              final contentId = (report['contentId'] as String?) ?? '';
              final reviewId = (report['reviewId'] as String?) ?? '';
              final timestamp = (report['date'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1) 신고 기본 정보
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '리뷰 ID: $reviewId',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(timestamp),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2) 야영장 정보 (메모이즈된 Future)
                      FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        future:
                            contentId.isEmpty
                                ? Future.value(null)
                                : _fetchCampByContentId(contentId),
                        builder: (ctxCamp, campSnap) {
                          if (campSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('야영장 정보를 불러오는 중...');
                          }
                          final campDocs = campSnap.data?.docs ?? [];
                          if (campDocs.isEmpty) {
                            return const Text('야영장 정보를 찾을 수 없습니다.');
                          }
                          final campName =
                              (campDocs.first.data()['name'] as String?) ??
                              '이름없음';
                          return Text(
                            '야영장: $campName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // 3) 원본 리뷰 + 신고자/사유/처리완료 (메모이즈된 Future)
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future:
                            (contentId.isEmpty || reviewId.isEmpty)
                                ? Future.value(null)
                                : _fetchReviewDoc(contentId, reviewId),
                        builder: (ctxRev, revSnap) {
                          if (revSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('원본 리뷰를 불러오는 중...');
                          }
                          final revData = revSnap.data?.data();
                          if (revData == null) {
                            return const Text('원본 리뷰가 없습니다.');
                          }

                          final origNick =
                              (revData['nickname'] as String?) ?? '익명';
                          final origContent =
                              (revData['content'] as String?) ?? '';
                          final origDate =
                              (revData['date'] as Timestamp?)?.toDate();
                          final origUserId =
                              (revData['userId'] as String?) ?? '';
                          final imageUrls =
                              (revData['imageUrls'] as List<dynamic>?)
                                  ?.cast<String>() ??
                              const <String>[];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '작성자: $origNick',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(origContent),
                              const SizedBox(height: 8),

                              if (imageUrls.isNotEmpty) ...[
                                const Text('사진:'),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: imageUrls.length,
                                    itemBuilder:
                                        (_, i) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (_) => Dialog(
                                                      insetPadding:
                                                          EdgeInsets.zero,
                                                      child: InteractiveViewer(
                                                        child: Image.network(
                                                          imageUrls[i],
                                                          errorBuilder:
                                                              (
                                                                _,
                                                                __,
                                                                ___,
                                                              ) => const SizedBox(
                                                                width: 200,
                                                                height: 200,
                                                                child: Center(
                                                                  child: Text(
                                                                    '이미지 로드 실패',
                                                                  ),
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                              );
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                imageUrls[i],
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, __, ___) => Container(
                                                      width: 80,
                                                      height: 80,
                                                      color:
                                                          Colors.grey.shade200,
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              Text(
                                '신고자: $reporterNick (${reporterEmail.isEmpty ? '이메일 미제공' : reporterEmail})',
                              ),
                              const SizedBox(height: 4),
                              Text('사유: $reason'),
                              const SizedBox(height: 12),

                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: const Text('삭제 확인'),
                                            content: const Text(
                                              '신고와 연결된 리뷰를 모두 삭제하시겠습니까?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      false,
                                                    ),
                                                child: const Text('취소'),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      true,
                                                    ),
                                                child: const Text(
                                                  '삭제',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    );
                                    if (ok != true) return;

                                    try {
                                      final batch =
                                          FirebaseFirestore.instance.batch();
                                      // 1) 신고 문서 삭제
                                      batch.delete(
                                        _reportColl.doc(reportDoc.id),
                                      );
                                      // 2) campground_reviews 리뷰 삭제
                                      if (contentId.isNotEmpty &&
                                          reviewId.isNotEmpty) {
                                        batch.delete(
                                          _campReviewColl(
                                            contentId,
                                          ).doc(reviewId),
                                        );
                                      }
                                      // 3) user_reviews 리뷰 삭제 (가능하면 매칭)
                                      if (origUserId.isNotEmpty &&
                                          origDate != null &&
                                          contentId.isNotEmpty) {
                                        final userReviewQuery =
                                            await _userReviewColl(origUserId)
                                                .where(
                                                  'contentId',
                                                  isEqualTo: contentId,
                                                )
                                                .where(
                                                  'content',
                                                  isEqualTo: origContent,
                                                )
                                                .where(
                                                  'date',
                                                  isEqualTo: Timestamp.fromDate(
                                                    origDate,
                                                  ),
                                                )
                                                .get();
                                        for (final ur in userReviewQuery.docs) {
                                          batch.delete(ur.reference);
                                        }
                                      }
                                      await batch.commit();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('신고 및 리뷰가 삭제되었습니다.'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('삭제 실패: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('처리 완료'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
