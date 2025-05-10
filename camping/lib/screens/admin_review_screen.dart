// 후기 관리 화면
import 'package:flutter/material.dart';

class AdminReviewScreen extends StatelessWidget {
  const AdminReviewScreen({super.key});

  final List<Map<String, dynamic>> dummyReviews = const [
    {
      'nick': '김철수',
      'date': '2025-05-05',
      'rating': 4,
      'content': '조용하고 깨끗했어요.',
    },
    {
      'nick': '이영희',
      'date': '2025-04-30',
      'rating': 2,
      'content': '벌레가 많고 시끄러웠어요.',
    },
    {
      'nick': '익명',
      'date': '2025-04-28',
      'rating': 5,
      'content': '아이들과 오기 좋아요. 트램플린 최고!',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('후기 관리')),
      body: ListView.builder(
        itemCount: dummyReviews.length,
        itemBuilder: (context, index) {
          final review = dummyReviews[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Row(
                children: [
                  Text(review['nick'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Text(review['date'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < review['rating'] ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.green,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(review['content']),
                ],
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditReviewScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('삭제 기능은 아직 구현되지 않았습니다.')),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 후기 수정 화면
class EditReviewScreen extends StatelessWidget {
  const EditReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('후기 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '닉네임'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('평점: '),
                DropdownButton<int>(
                  value: 5,
                  items: List.generate(5, (i) => i + 1).map((v) {
                    return DropdownMenuItem<int>(
                      value: v,
                      child: Text('$v'),
                    );
                  }).toList(),
                  onChanged: (v) {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              maxLines: 4,
              decoration: const InputDecoration(labelText: '내용'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('저장 기능은 아직 구현되지 않았습니다.')),
                  );
                },
                child: const Text('수정 완료'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 캠핑장 수정/등록 화면
class EditCampScreen extends StatelessWidget {
  const EditCampScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캠핑장 정보 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(labelText: '캠핑장 이름'),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: '주소'),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: '유형 (국립, 지자체 등)'),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: '환경'),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: '예약 URL'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('저장 기능은 아직 구현되지 않았습니다.')),
                    );
                  },
                  child: const Text('저장'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
