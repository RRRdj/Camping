/// lib/screens/my_reviews_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/review_repository.dart';
import '../services/format_service.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({Key? key}) : super(key: key);

  @override
  _MyReviewsScreenState createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _repo = ReviewRepository();
  final _fmt = FormatService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _delete(
    BuildContext ctx,
    String userReviewId,
    String? contentId,
    String? content,
    Timestamp? date,
  ) async {
    await _repo.deleteReview(
      userReviewId: userReviewId,
      contentId: contentId,
      content: content,
      date: date,
    );
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(const SnackBar(content: Text('후기가 삭제되었습니다.')));
  }

  Future<void> _edit(
    BuildContext ctx, {
    required String userReviewId,
    required String? contentId,
    required String? oldContent,
    required Timestamp? date,
    required int? oldRating,
    required List<String> oldImageUrls,
  }) async {
    final TextEditingController ctrl = TextEditingController(
      text: oldContent ?? '',
    );
    int newRating = oldRating ?? 5;
    List<String> currentUrls = List.from(oldImageUrls);
    List<XFile> newImages = [];

    final result = await showDialog<bool>(
      context: ctx,
      builder:
          (dctx) => StatefulBuilder(
            builder:
                (dctx, setState) => AlertDialog(
                  title: const Text('후기 수정'),
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
                              items:
                                  List.generate(5, (i) => i + 1)
                                      .map(
                                        (v) => DropdownMenuItem<int>(
                                          value: v,
                                          child: Text('$v'),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => newRating = v);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 내용
                        TextField(
                          controller: ctrl,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '내용',
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 기존 이미지 편집
                        if (currentUrls.isNotEmpty) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '기존 사진',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                currentUrls.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  String url = entry.value;
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap:
                                              () => setState(
                                                () => currentUrls.removeAt(idx),
                                              ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // 새로운 이미지 추가
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('사진 추가'),
                            onPressed: () async {
                              final picked = await _picker.pickMultiImage();
                              if (picked != null && picked.isNotEmpty) {
                                setState(() => newImages.addAll(picked));
                              }
                            },
                          ),
                        ),
                        if (newImages.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                newImages.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  XFile file = entry.value;
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(file.path),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap:
                                              () => setState(
                                                () => newImages.removeAt(idx),
                                              ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dctx),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dctx, true),
                      child: const Text('저장'),
                    ),
                  ],
                ),
          ),
    );

    // 교체: _edit 내 result 처리 시작부에 널 가드 추가
    if (result == true) {
      if (contentId == null || contentId.isEmpty) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('캠핑장 정보가 없습니다.')));
        return;
      }

      final removedUrls =
          oldImageUrls.where((url) => !currentUrls.contains(url)).toList();

      await _repo.updateReview(
        contentId: contentId,
        reviewId: userReviewId,
        rating: newRating,
        content: ctrl.text.trim(),
        newImageFiles: newImages.isNotEmpty ? newImages : null,
        removeImageUrls: removedUrls.isNotEmpty ? removedUrls : null,
      );
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('후기가 수정되었습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('내가 쓴 후기'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.userReviewsStream(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('작성한 후기가 없습니다.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final m = docs[i].data();
              final imageUrls =
                  (m['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 및 별점
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${m['campName'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _fmt.ratingLabel(m['rating'] as int?),
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 내용
                      Text(m['content'] ?? ''),
                      const SizedBox(height: 8),
                      // 이미지 썸네일 (Wrap으로 정렬)
                      if (imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              imageUrls
                                  .map(
                                    (url) => GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder:
                                              (_) => Dialog(
                                                insetPadding: EdgeInsets.all(0),
                                                child: InteractiveViewer(
                                                  child: Image.network(url),
                                                ),
                                              ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // 날짜 및 액션 버튼
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt.reviewDate(m['date'] as Timestamp?),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.teal,
                                ),
                                onPressed:
                                    () => _edit(
                                      ctx,
                                      userReviewId: docs[i].id,
                                      contentId: m['contentId'] as String?,
                                      oldContent: m['content'] as String?,
                                      date: m['date'] as Timestamp?,
                                      oldRating: m['rating'] as int?,
                                      oldImageUrls: imageUrls,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  // 교체: 삭제 확인 다이얼로그 빌더와 pop 컨텍스트
                                  final ok = await showDialog<bool>(
                                    context: ctx,
                                    builder:
                                        (dctx) => AlertDialog(
                                          title: const Text('후기 삭제'),
                                          content: const Text('정말로 삭제하시겠습니까?'),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    dctx,
                                                    false,
                                                  ),
                                              child: const Text('취소'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(dctx, true),
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

                                  if (ok == true) {
                                    await _delete(
                                      ctx,
                                      docs[i].id,
                                      m['contentId'] as String?,
                                      m['content'] as String?,
                                      m['date'] as Timestamp?,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
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
