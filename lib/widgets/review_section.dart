/// lib/widgets/review_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/camp_repository.dart';

/// 리뷰 목록 + 수정/삭제/신고 로직을 포함한 섹션
class ReviewSection extends StatelessWidget {
  final CampRepository repository;
  final String contentId;

  const ReviewSection({
    Key? key,
    required this.repository,
    required this.contentId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (contentId.isEmpty) {
      return const Text('리뷰를 불러올 수 없습니다.');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: repository.getReviews(contentId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text('아직 등록된 리뷰가 없습니다.');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              docs.map((doc) {
                final data = doc.data();
                final reviewerId = data['userId'] as String? ?? '';
                final reviewId = doc.id;
                final nick = data['nickname'] as String? ?? '익명';
                final date =
                    data['date'] != null
                        ? (data['date'] as Timestamp)
                            .toDate()
                            .toString()
                            .substring(0, 10)
                        : '';
                final rating = data['rating'] as int? ?? 5;
                final content = data['content'] as String? ?? '';

                List<Widget> actions = [];
                if (currentUser != null && reviewerId == currentUser.uid) {
                  actions.addAll([
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.teal,
                      ),
                      tooltip: '수정',
                      onPressed:
                          () => _showEditDialog(
                            context,
                            reviewId,
                            rating,
                            content,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      tooltip: '삭제',
                      onPressed: () => _showDeleteDialog(context, reviewId),
                    ),
                  ]);
                } else if (currentUser != null) {
                  actions.add(
                    IconButton(
                      icon: const Icon(
                        Icons.flag,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      tooltip: '신고',
                      onPressed:
                          () =>
                              _showReportDialog(context, reviewId, reviewerId),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          nick,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        ...actions,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating ? Icons.star : Icons.star_border,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(content),
                    const Divider(),
                  ],
                );
              }).toList(),
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    String reviewId,
    int oldRating,
    String oldContent,
  ) async {
    final contentCtrl = TextEditingController(text: oldContent);
    int newRating = oldRating;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('리뷰 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: newRating,
                  items:
                      List.generate(5, (i) => i + 1)
                          .map(
                            (v) =>
                                DropdownMenuItem(value: v, child: Text('$v')),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) newRating = v;
                  },
                ),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '내용'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('확인'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await repository.updateReview(
        contentId: contentId,
        reviewId: reviewId,
        rating: newRating,
        content: contentCtrl.text.trim(),
      );
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('리뷰 삭제'),
            content: const Text('이 리뷰를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await repository.deleteReview(contentId, reviewId);
    }
  }

  Future<void> _showReportDialog(
    BuildContext context,
    String reviewId,
    String reportedUserId,
  ) async {
    final reporter = FirebaseAuth.instance.currentUser;
    if (reporter == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 이용해주세요.')));
      return;
    }

    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('신고 사유 입력'),
            content: TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '신고 사유를 입력하세요'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
                child: const Text('확인'),
              ),
            ],
          ),
    );

    if (reason == null || reason.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('신고 확인'),
            content: const Text('이 리뷰를 신고하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('신고'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    await repository.reportReview(
      contentId: contentId,
      reviewId: reviewId,
      reportedUserId: reportedUserId,
      reason: reason,
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
  }
}
