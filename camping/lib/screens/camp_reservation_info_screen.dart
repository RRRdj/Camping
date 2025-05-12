import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CampReservationInfoScreen extends StatefulWidget {
  const CampReservationInfoScreen({super.key});

  @override
  State<CampReservationInfoScreen> createState() => _CampReservationInfoScreenState();
}

class _CampReservationInfoScreenState extends State<CampReservationInfoScreen> {
  final _idController = TextEditingController(text: '');
  final _pwController = TextEditingController(text: '');

  String _campName = '캠핑장';
  String _contentId = '없음';

  @override
  void initState() {
    super.initState();
    // context 사용을 위해 WidgetsBinding 추가
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _campName = args?['campName'] ?? '캠핑장';
      _contentId = args?['contentId'] ?? '없음';
      _loadSavedReservationInfo();
    });
  }

  Future<void> _loadSavedReservationInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reservation_info')
        .doc(_contentId);

    final docSnap = await docRef.get();
    if (docSnap.exists) {
      final data = docSnap.data()!;
      setState(() {
        _idController.text = data['reservationUserId'] ?? '';
        _pwController.text = data['reservationPassword'] ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$_campName - 예약 정보')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('📌 캠핑장 ID: $_contentId', style: const TextStyle(color: Colors.grey)),
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
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('로그인 후 이용해주세요.')),
                    );
                    return;
                  }

                  final reservationUserId = _idController.text.trim();
                  final reservationPassword = _pwController.text.trim();

                  if (reservationUserId.isEmpty || reservationPassword.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('아이디와 비밀번호를 모두 입력하세요.')),
                    );
                    return;
                  }

                  final now = DateTime.now();

                  final docRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('reservation_info')
                      .doc(_contentId);

                  await docRef.set({
                    'campName': _campName,
                    'contentId': _contentId,
                    'reservationUserId': reservationUserId,
                    'reservationPassword': reservationPassword,
                    'savedAt': now,
                    'email': user.email ?? '',
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('예약 정보가 저장되었습니다.')),
                  );
                },
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
