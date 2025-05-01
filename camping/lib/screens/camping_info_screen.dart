import 'package:flutter/material.dart';

class CampingInfoScreen extends StatelessWidget {
  final Map<String, dynamic> camp;

  const CampingInfoScreen({
    Key? key,
    required this.camp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = camp['name'] as String;
    final location = camp['location'] as String;
    final type = camp['type'] as String;
    final available = camp['available'] as int? ?? 0;
    final total = camp['total'] as int? ?? 0;
    final isAvailable = available > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('$name 야영장 정보'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name ,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$location  |  $type',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              isAvailable
                  ? '예약 가능 ($available / $total)'
                  : '예약 마감 ($available / $total)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isAvailable ? Colors.green : Colors.red,
              ),
            ),
            const Divider(height: 32),
            // 여기에 더 자세한 설명, 지도, 연락처 등 추가 가능
            const Text(
              '상세 정보',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // 예시 더미 텍스트
            const Text(
              '이곳에 해당 야영장의 시설 설명, 이용 요금, '
                  '부가 서비스 등을 표시할 수 있습니다.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
