import 'package:flutter/material.dart';


class MemoScreen extends StatelessWidget {
  const MemoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('메모장'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 사이트 ID
            TextField(
              decoration: const InputDecoration(
                labelText: '사이트 ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 사이트 암호
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '사이트 암호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 메모 (여러 줄)
            TextField(
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '메모',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 저장 버튼 (기능 없음)
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
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}