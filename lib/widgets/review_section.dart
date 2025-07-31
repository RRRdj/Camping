/// lib/widgets/review_section.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../repositories/camp_repository.dart';

/// 리뷰 목록 + 수정/삭제/신고 + 이미지 수정·확대 보기 기능 포함 섹션
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
        if (snapshot.connectionState != ConnectionState.active) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Text('아직 등록된 리뷰가 없습니다.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((doc) {
            final data = doc.data();
            final reviewerId = data['userId'] as String? ?? '';
            final reviewId = doc.id;
            final nick = data['nickname'] as String? ?? '익명';
            final date = data['date'] != null
                ? (data['date'] as Timestamp).toDate().toString().substring(0, 10)
                : '';
            final rating = data['rating'] as int? ?? 5;
            final content = data['content'] as String? ?? '';
            final imageUrls = (data['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];

            // 수정/삭제/신고 버튼
            List<Widget> actions = [];
            if (currentUser != null && reviewerId == currentUser.uid) {
              actions.addAll([
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.teal),
                  tooltip: '수정',
                  onPressed: () => _showEditDialog(
                    context,
                    reviewId,
                    rating,
                    content,
                    imageUrls,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  tooltip: '삭제',
                  onPressed: () => _showDeleteDialog(context, reviewId),
                ),
              ]);
            } else if (currentUser != null) {
              actions.add(
                IconButton(
                  icon: const Icon(Icons.flag, size: 18, color: Colors.redAccent),
                  tooltip: '신고',
                  onPressed: () => _showReportDialog(
                    context,
                    reviewId,
                    reviewerId,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작성자, 날짜, 버튼
                Row(
                  children: [
                    Text(nick, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const Spacer(),
                    ...actions,
                  ],
                ),
                const SizedBox(height: 4),
                // 평점
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
                // 내용
                Text(content),
                // 이미지 썸네일 및 클릭 확대
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: imageUrls.map((url) {
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              insetPadding: EdgeInsets.all(0),
                              child: InteractiveViewer(
                                child: Image.network(url),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const Divider(),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  /// 리뷰 수정 다이얼로그 (이미지 추가/삭제 지원)
  Future<void> _showEditDialog(
      BuildContext context,
      String reviewId,
      int oldRating,
      String oldContent,
      List<String> oldImageUrls,
      ) async {
    // 로컬 복사본
    final originalUrls = List<String>.from(oldImageUrls);
    final currentUrls = List<String>.from(oldImageUrls);
    final newImages = <XFile>[];
    int newRating = oldRating;
    final contentCtrl = TextEditingController(text: oldContent);
    final picker = ImagePicker();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('리뷰 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 평점
                Row(
                  children: [
                    const Text('평점:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: newRating,
                      items: List.generate(5, (i) => i + 1)
                          .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => newRating = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 기존 이미지
                if (currentUrls.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentUrls.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final url = entry.value;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => currentUrls.removeAt(idx)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                // 새로운 이미지 선택
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 추가 버튼
                    GestureDetector(
                      onTap: () async {
                        final picked = await picker.pickMultiImage();
                        if (picked != null && picked.isNotEmpty) {
                          setState(() => newImages.addAll(picked));
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.add_a_photo, color: Colors.grey),
                      ),
                    ),
                    // 새로 추가된 썸네일
                    ...newImages.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final file = entry.value;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(File(file.path), width: 80, height: 80, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => newImages.removeAt(idx)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
                const SizedBox(height: 8),
                // 내용
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '내용'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인')),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      // 삭제된 URL 목록
      final removeUrls = originalUrls.where((u) => !currentUrls.contains(u)).toList();
      await repository.updateReview(
        contentId: contentId,
        reviewId: reviewId,
        rating: newRating,
        content: contentCtrl.text.trim(),
        newImageFiles: newImages.isNotEmpty ? newImages : null,
        removeImageUrls: removeUrls.isNotEmpty ? removeUrls : null,
      );
    }
  }

  /// 리뷰 삭제 다이얼로그
  Future<void> _showDeleteDialog(BuildContext context, String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: const Text('이 리뷰를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );

    if (confirmed == true) {
      await repository.deleteReview(contentId, reviewId);
    }
  }

  /// 리뷰 신고 다이얼로그
  Future<void> _showReportDialog(
      BuildContext context,
      String reviewId,
      String reportedUserId,
      ) async {
    final reporter = FirebaseAuth.instance.currentUser;
    if (reporter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용해주세요.')),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신고 사유 입력'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '신고 사유를 입력하세요'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()), child: const Text('확인')),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신고 확인'),
        content: const Text('이 리뷰를 신고하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('신고')),
        ],
      ),
    );

    if (confirm == true) {
      await repository.reportReview(
        contentId: contentId,
        reviewId: reviewId,
        reportedUserId: reportedUserId,
        reason: reason,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고가 접수되었습니다.')),
      );
    }
  }
}