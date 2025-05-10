import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({Key? key}) : super(key: key);

  Future<void> _deleteReview(
      BuildContext context,
      String userReviewId,
      String? contentId,
      String? content,
      Timestamp? date,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. 사용자별 내가 쓴 리뷰 삭제
    await FirebaseFirestore.instance
        .collection('user_reviews')
        .doc(user.uid)
        .collection('reviews')
        .doc(userReviewId)
        .delete();

    // 2. 캠핑장별 리뷰도 삭제 (userId, content, date 모두 일치하는 문서만)
    if (contentId != null &&
        contentId.isNotEmpty &&
        content != null &&
        date != null) {
      final reviewQuery = await FirebaseFirestore.instance
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .where('userId', isEqualTo: user.uid)
          .where('content', isEqualTo: content)
          .where('date', isEqualTo: date)
          .get();

      for (var doc in reviewQuery.docs) {
        await doc.reference.delete();
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('후기가 삭제되었습니다.')),
    );
  }

  Future<void> _editReview(
      BuildContext context, {
        required String userReviewId,
        required String? contentId,
        required String? oldContent,
        required Timestamp? date,
        required String? campName,
        required int? oldRating,
      }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || contentId == null || contentId.isEmpty || date == null) return;

    final txtController = TextEditingController(text: oldContent ?? '');
    int rating = oldRating ?? 5;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('후기 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('평점:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: rating,
                  items: [
                    for (var v in List.generate(5, (i) => i + 1))
                      DropdownMenuItem(value: v, child: Text('$v')),
                  ],
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      rating = newValue;
                      // Hack: 강제로 rebuild
                      (ctx as Element).markNeedsBuild();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: txtController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop({
                'content': txtController.text.trim(),
                'rating': rating,
              });
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == null) return; // 취소

    final newContent = result['content'] as String;
    final newRating = result['rating'] as int;

    if (newContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력하세요.')),
      );
      return;
    }

    // 1. user_reviews에서 업데이트
    await FirebaseFirestore.instance
        .collection('user_reviews')
        .doc(user.uid)
        .collection('reviews')
        .doc(userReviewId)
        .update({
      'content': newContent,
      'rating': newRating,
      // date는 수정하지 않음 (원본 유지)
    });

    // 2. campground_reviews에서 업데이트 (userId, oldContent, date로 찾음)
    final reviewQuery = await FirebaseFirestore.instance
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .where('userId', isEqualTo: user.uid)
        .where('content', isEqualTo: oldContent)
        .where('date', isEqualTo: date)
        .get();

    for (var doc in reviewQuery.docs) {
      await doc.reference.update({
        'content': newContent,
        'rating': newRating,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('후기가 수정되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('내가 쓴 후기'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_reviews')
            .doc(user.uid)
            .collection('reviews')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('작성한 후기가 없습니다.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, idx) {
              final data = docs[idx].data() as Map<String, dynamic>;
              final userReviewId = docs[idx].id;
              final contentId = data['contentId'] as String?;
              final content = data['content'] as String?;
              final date = data['date'] as Timestamp?;
              final campName = data['campName'] as String?;
              final rating = data['rating'] as int?;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('${campName ?? ''}  ★${rating ?? 5}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        date != null
                            ? date.toDate().toString().substring(0, 16)
                            : '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.teal),
                        tooltip: '수정',
                        onPressed: () async {
                          await _editReview(
                            context,
                            userReviewId: userReviewId,
                            contentId: contentId,
                            oldContent: content,
                            date: date,
                            campName: campName,
                            oldRating: rating,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: '삭제',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('후기 삭제'),
                              content: const Text('정말로 이 후기를 삭제하시겠습니까?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('삭제', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _deleteReview(
                              context,
                              userReviewId,
                              contentId,
                              content,
                              date,
                            );
                          }
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
