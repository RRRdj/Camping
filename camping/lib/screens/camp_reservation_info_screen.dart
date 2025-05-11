import 'package:flutter/material.dart';

class CampReservationInfoScreen extends StatefulWidget {
  const CampReservationInfoScreen({super.key});

  @override
  State<CampReservationInfoScreen> createState() => _CampReservationInfoScreenState();
}

class _CampReservationInfoScreenState extends State<CampReservationInfoScreen> {
  final _idController = TextEditingController(text: 'testuser');
  final _pwController = TextEditingController(text: 'password123');

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final campName = args?['campName'] ?? '캠핑장';
    final contentId = args?['contentId'] ?? '없음';

    return Scaffold(
      appBar: AppBar(title: Text('$campName - 예약 정보')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('📌 캠핑장 ID: $contentId', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            const Text('🔐 로그인 정보 (필수 O)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: '아이디',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwController,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {}, // 기능 없음
                child: const Text('저장'),
              ),
            ),

            const Divider(height: 32),

            const Text('⚠️ 예약 시 주의사항', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '- 예약은 오전 9시부터 시작되며 선착순입니다.\n'
              '- 예약 후 반드시 결제를 완료해야 합니다.\n'
              '- 예약 취소는 3일 전까지 가능합니다.',
            ),

            const Divider(height: 32),

            const Text('💡 예약 팁', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '- 평일 예약은 비교적 여유가 있습니다.\n'
              '- 브라우저 자동 입력 기능을 활용하면 빠르게 로그인할 수 있습니다.\n'
              '- 미리 로그인 상태로 8시 59분에 대기하세요.',
            ),
          ],
        ),
      ),
    );
  }
}
