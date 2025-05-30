import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReservationInfoScreen extends StatefulWidget {
  const ReservationInfoScreen({Key? key}) : super(key: key);

  @override
  State<ReservationInfoScreen> createState() => _ReservationInfoScreenState();
}

class _ReservationInfoScreenState extends State<ReservationInfoScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();

  String _campName = '캠핑장';
  String _contentId = '없음';
  String _reservationWarning = '로딩 중...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _campName = args['campName'] ?? _campName;
          _contentId = args['contentId'] ?? _contentId;
          if (args.containsKey('reservationWarning')) {
            _reservationWarning = args['reservationWarning'] as String;
          }
        });
        _loadSavedReservationInfo();
        // Firestore에서 campName 기준으로 불러오도록 수정
        if (!args.containsKey('reservationWarning')) {
          _loadReservationWarning();
        }
      }
    });
  }

  Future<void> _loadSavedReservationInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docSnap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reservation_info')
            .doc(_contentId)
            .get();

    if (docSnap.exists) {
      final data = docSnap.data()!;
      setState(() {
        _idController.text = data['reservationUserId'] ?? '';
        _pwController.text = data['reservationPassword'] ?? '';
      });
    }
  }

  Future<void> _loadReservationWarning() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('campgrounds')
              .doc(_campName)
              .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _reservationWarning =
              data['reservation_warning'] as String? ??
              data['reservationWarning'] as String? ??
              '주의사항이 없습니다.';
        });
      } else {
        setState(() {
          _reservationWarning = '주의사항을 불러올 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _reservationWarning = '주의사항을 불러오는 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_campName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              '📌 캠핑장 ID: $_contentId',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            const Text(
              '🔐 로그인 정보',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
                  if (reservationUserId.isEmpty ||
                      reservationPassword.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('아이디와 비밀번호를 모두 입력하세요.')),
                    );
                    return;
                  }

                  final now = DateTime.now();
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('reservation_info')
                      .doc(_contentId)
                      .set({
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

            const Text(
              '⚠️ 예약 시 주의사항',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_reservationWarning),
            // '메모 저장' 버튼이 제거되었습니다.
          ],
        ),
      ),
    );
  }
}
