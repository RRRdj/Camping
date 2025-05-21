import 'package:flutter/material.dart';


class ReviewScreen extends StatelessWidget {
  const ReviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 별점은 단순히 아이콘 5개를 나열한 예시입니다.
    // 실제로 별점 기능을 구현하려면 별점을 선택/저장하는 로직이 필요합니다.
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('후기 작성'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 후기 제목
            TextField(
              decoration: const InputDecoration(
                labelText: '후기 제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 후기 내용
            TextField(
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '후기 내용',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 별점 표시
            Row(
              children: List.generate(5, (index) {
                return const Icon(
                  Icons.star_border,
                  color: Colors.green,
                  size: 30,
                );
              }),
            ),
            const SizedBox(height: 16),

            // 후기 등록 버튼 (기능 없음)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // 버튼 기능은 구현하지 않아도 된다고 하셨습니다.
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('후기 등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}