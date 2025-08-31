/// lib/screens/admin_review_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  final _searchCtr = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtr.dispose();
    super.dispose();
  }

  // 항목별로 야영장명 + 원본 리뷰를 한 번에 로드
  Future<_ItemData> _fetchItemData(String contentId, String reviewId) async {
    // 캠핑장명
    String campName = '야영장 정보를 찾을 수 없습니다.';
    try {
      final campSnap = await FirebaseFirestore.instance
          .collection('campgrounds')
          .where('contentId', isEqualTo: contentId)
          .limit(1)
          .get();
      if (campSnap.docs.isNotEmpty) {
        campName = campSnap.docs.first.data()['name'] as String? ?? '이름없음';
      }
    } catch (_) {}

    // 원본 리뷰
    String origNick = '익명';
    String origContent = '';
    DateTime? origDate;
    String origUserId = '';
    List<String> imageUrls = [];

    try {
      final revDoc = await FirebaseFirestore.instance
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .doc(reviewId)
          .get();

      if (revDoc.exists) {
        final revData = revDoc.data()!;
        origNick = revData['nickname'] as String? ?? '익명';
        origContent = revData['content'] as String? ?? '';
        origDate = (revData['date'] as Timestamp?)?.toDate();
        origUserId = revData['userId'] as String? ?? '';
        imageUrls =
            (revData['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
      }
    } catch (_) {}

    return _ItemData(
      campName: campName,
      origNick: origNick,
      origContent: origContent,
      origDate: origDate,
      origUserId: origUserId,
      imageUrls: imageUrls,
    );
  }

  bool _stringContains(String haystack, String needle) {
    if (needle.isEmpty) return true;
    return haystack.toLowerCase().contains(needle.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('신고된 후기 관리')),
      body: Column(
        children: [
          // 검색창: 야영장명 / 작성자닉네임 / 신고자닉네임
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtr,
              decoration: InputDecoration(
                hintText: '야영장명 / 작성자닉네임 / 신고자닉네임 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtr.clear();
                    setState(() => _query = '');
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                    final reviewId = reportData['reviewId'] as String? ?? '';
                    final timestamp =
                    (reportData['date'] as Timestamp?)?.toDate();

                    // 먼저 신고자 닉네임으로 1차 필터
                    final reporterMatch =
                    _stringContains(reporterNick, _query);

                    // 캠핑장명/작성자닉네임은 비동기로 가져온 후 최종 필터 판단
                    return FutureBuilder<_ItemData>(
                      future: _fetchItemData(contentId, reviewId),
                      builder: (ctx, itemSnap) {
                        if (itemSnap.connectionState != ConnectionState.done) {
                          // 검색어가 있고, 신고자도 불일치라면 로딩 위젯 대신 숨김
                          if (_query.isNotEmpty && !reporterMatch) {
                            return const SizedBox.shrink();
                          }
                          // 로딩 표시
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (!itemSnap.hasData) {
                          // 데이터 없으면 필터와 관계없이 숨김
                          return const SizedBox.shrink();
                        }

                        final item = itemSnap.data!;
                        final campMatch =
                        _stringContains(item.campName, _query);
                        final origMatch =
                        _stringContains(item.origNick, _query);

                        // 최종: (신고자 OR 야영장 OR 작성자) 중 하나라도 매칭되면 표시
                        if (_query.isNotEmpty &&
                            !(reporterMatch || campMatch || origMatch)) {
                          return const SizedBox.shrink();
                        }

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
                                const SizedBox(height: 8),

                                // 2) 야영장 정보
                                Text(
                                  '야영장: ${item.campName}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                                const SizedBox(height: 12),

                                // 3) 원본 리뷰 + 신고자/사유/처리완료
                                Text('작성자: ${item.origNick}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('내용: ${item.origContent}'),
                                const SizedBox(height: 8),

                                if (item.imageUrls.isNotEmpty) ...[
                                  const Text('사진:'),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 80,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: item.imageUrls.length,
                                      itemBuilder: (_, i) => Padding(
                                        padding:
                                        const EdgeInsets.only(right: 8),
                                        child: GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => Dialog(
                                                insetPadding:
                                                const EdgeInsets.all(0),
                                                child: InteractiveViewer(
                                                  child: Image.network(
                                                      item.imageUrls[i]),
                                                ),
                                              ),
                                            );
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                            BorderRadius.circular(8),
                                            child: Image.network(
                                              item.imageUrls[i],
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                Text('신고자: $reporterNick ($reporterEmail)'),
                                const SizedBox(height: 4),
                                Text('사유: $reason'),
                                const SizedBox(height: 12),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent),
                                    child: const Text('처리 완료'),
                                    onPressed: () async {
                                      final batch = FirebaseFirestore.instance.batch();
                                      // 1) 신고 문서 삭제
                                      batch.delete(FirebaseFirestore.instance
                                          .collection('review_reports')
                                          .doc(reportDoc.id));
                                      // 2) campground_reviews 리뷰 삭제
                                      batch.delete(FirebaseFirestore.instance
                                          .collection('campground_reviews')
                                          .doc(contentId)
                                          .collection('reviews')
                                          .doc(reviewId));
                                      // 3) user_reviews 리뷰 삭제
                                      if (item.origUserId.isNotEmpty &&
                                          item.origDate != null) {
                                        final userReviewQuery =
                                        await FirebaseFirestore.instance
                                            .collection('user_reviews')
                                            .doc(item.origUserId)
                                            .collection('reviews')
                                            .where('contentId',
                                            isEqualTo: contentId)
                                            .where('content',
                                            isEqualTo:
                                            item.origContent)
                                            .where(
                                            'date',
                                            isEqualTo:
                                            Timestamp.fromDate(
                                                item.origDate!))
                                            .get();
                                        for (var ur in userReviewQuery.docs) {
                                          batch.delete(ur.reference);
                                        }
                                      }
                                      await batch.commit();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('신고 및 리뷰가 삭제되었습니다.')),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 항목 렌더링에 필요한 최소 데이터 묶음
class _ItemData {
  final String campName;
  final String origNick;
  final String origContent;
  final DateTime? origDate;
  final String origUserId;
  final List<String> imageUrls;

  _ItemData({
    required this.campName,
    required this.origNick,
    required this.origContent,
    required this.origDate,
    required this.origUserId,
    required this.imageUrls,
  });
}
