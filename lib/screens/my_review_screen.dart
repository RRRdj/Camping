import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/review_repository.dart';
import '../services/format_service.dart';

class MyReviewsScreen extends StatelessWidget {
  MyReviewsScreen({super.key});

  final _repo = ReviewRepository();
  final _fmt = FormatService();

  Future<void> _delete(
    BuildContext ctx,
    String id,
    String? cid,
    String? c,
    Timestamp? d,
  ) async {
    await _repo.deleteReview(
      userReviewId: id,
      contentId: cid,
      content: c,
      date: d,
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
  }) async {
    final ctrl = TextEditingController(text: oldContent ?? '');
    int rating = oldRating ?? 5;
    final res = await showDialog<Map<String, dynamic>?>(
      context: ctx,
      builder:
          (dctx) => AlertDialog(
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
                      items:
                          List.generate(5, (i) => i + 1)
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text('$v'),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          rating = v;
                          (dctx as Element).markNeedsBuild();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '내용',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(dctx, {
                      'c': ctrl.text.trim(),
                      'r': rating,
                    }),
                child: const Text('저장'),
              ),
            ],
          ),
    );
    if (res == null) return;
    if ((res['c'] as String).isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('내용을 입력하세요.')));
      return;
    }
    await _repo.updateReview(
      userReviewId: userReviewId,
      contentId: contentId,
      oldContent: oldContent,
      date: date,
      newContent: res['c'],
      newRating: res['r'],
    );
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(const SnackBar(content: Text('후기가 수정되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('내가 쓴 후기'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.userReviewsStream(),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('작성한 후기가 없습니다.'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final m = docs[i].data();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    '${m['campName'] ?? ''}  ${_fmt.ratingLabel(m['rating'] as int?)}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['content'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        _fmt.reviewDate(m['date'] as Timestamp?),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.teal),
                        onPressed:
                            () => _edit(
                              ctx,
                              userReviewId: docs[i].id,
                              contentId: m['contentId'] as String?,
                              oldContent: m['content'] as String?,
                              date: m['date'] as Timestamp?,
                              oldRating: m['rating'] as int?,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder:
                                (_) => AlertDialog(
                                  title: const Text('후기 삭제'),
                                  content: const Text('정말로 삭제하시겠습니까?'),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(ctx, false),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        '삭제',
                                        style: TextStyle(color: Colors.red),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
