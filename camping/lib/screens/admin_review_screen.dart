// lib/screens/admin_review_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminReviewScreen extends StatelessWidget {
  const AdminReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('신고된 후기 관리')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('review_reports')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('신고된 후기가 없습니다.'));
          }

          final reports = snap.data!.docs;
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, idx) {
              final reportDoc = reports[idx];
              final reportData =
              reportDoc.data()! as Map<String, dynamic>;

              final reporterNick =
                  reportData['reporterNickname'] as String? ?? '익명';
              final reporterEmail =
                  reportData['reporterEmail'] as String? ?? '';
              final reason = reportData['reason'] as String? ?? '';
              final contentId =
                  reportData['contentId'] as String? ?? '';
              final reviewId =
                  reportData['reviewId'] as String? ?? '';
              final timestamp =
              (reportData['date'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
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
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm')
                                  .format(timestamp),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2) 야영장 정보 (contentId 로 조회)
                      FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('campgrounds')
                            .where('contentId', isEqualTo: contentId)
                            .limit(1)
                            .get(),
                        builder: (ctxCamp, campSnap) {
                          if (campSnap.connectionState !=
                              ConnectionState.done) {
                            return const Text('야영장 정보를 불러오는 중...');
                          }
                          if (!campSnap.hasData ||
                              campSnap.data!.docs.isEmpty) {
                            return const Text('야영장 정보를 찾을 수 없습니다.');
                          }
                          final campDoc = campSnap.data!.docs.first;
                          final campName =
                              campDoc.data()['name'] as String? ??
                                  '이름없음';
                          final campDocId = campDoc.id;
                          return Text(
                            '야영장: $campName ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // 3) 원본 리뷰 정보 + 신고자/사유/처리완료 버튼
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('campground_reviews')
                            .doc(contentId)
                            .collection('reviews')
                            .doc(reviewId)
                            .get(),
                        builder: (ctxRev, revSnap) {
                          if (revSnap.connectionState !=
                              ConnectionState.done) {
                            return const Text('원본 리뷰를 불러오는 중...');
                          }
                          if (!revSnap.hasData ||
                              !revSnap.data!.exists) {
                            return const Text('원본 리뷰가 없습니다.');
                          }

                          final revData = revSnap.data!.data()!;
                          final origNick =
                              revData['nickname'] as String? ?? '익명';
                          final origContent =
                              revData['content'] as String? ?? '';
                          final origDate =
                          revData['date'] as Timestamp?;
                          final origUserId =
                              revData['userId'] as String? ?? '';

                          return Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text('작성자: $origNick',
                                  style: const TextStyle(
                                      fontWeight:
                                      FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('내용: $origContent'),
                              const Divider(height: 20),

                              // 신고자 & 사유
                              Text(
                                  '신고자: $reporterNick ($reporterEmail)'),
                              const SizedBox(height: 4),
                              Text('사유: $reason'),
                              const SizedBox(height: 12),

                              // 처리 완료 버튼
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  style:
                                  ElevatedButton.styleFrom(
                                      backgroundColor:
                                      Colors.redAccent),
                                  child:
                                  const Text('처리 완료'),
                                  onPressed: () async {
                                    final batch = FirebaseFirestore
                                        .instance
                                        .batch();

                                    // 1) 신고 문서 삭제
                                    batch.delete(FirebaseFirestore
                                        .instance
                                        .collection(
                                        'review_reports')
                                        .doc(reportDoc.id));

                                    // 2) campground_reviews 리뷰 삭제
                                    batch.delete(FirebaseFirestore
                                        .instance
                                        .collection(
                                        'campground_reviews')
                                        .doc(contentId)
                                        .collection('reviews')
                                        .doc(reviewId));

                                    // 3) user_reviews 리뷰 삭제
                                    if (origUserId.isNotEmpty &&
                                        origDate != null) {
                                      final userReviewQuery =
                                      await FirebaseFirestore
                                          .instance
                                          .collection(
                                          'user_reviews')
                                          .doc(origUserId)
                                          .collection('reviews')
                                          .where('contentId',
                                          isEqualTo:
                                          contentId)
                                          .where('content',
                                          isEqualTo:
                                          origContent)
                                          .where('date',
                                          isEqualTo:
                                          origDate)
                                          .get();

                                      for (var ur
                                      in userReviewQuery.docs) {
                                        batch.delete(ur.reference);
                                      }
                                    }

                                    await batch.commit();

                                    ScaffoldMessenger.of(
                                        context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            '신고 및 리뷰가 삭제되었습니다.'),
                                      ),
                                    );
                                  },
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
