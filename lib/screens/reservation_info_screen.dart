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
  final _memoController = TextEditingController();

  String _campName = '캠핑장';
  String _contentId = '없음';
  String _reservationWarning = '로딩 중...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _campName = args['campName'] ?? _campName;
          _contentId = args['contentId'] ?? _contentId;
          if (args.containsKey('reservationWarning')) {
            _reservationWarning = args['reservationWarning'] as String;
          }
        });
        _loadSavedReservationInfo();
        _loadSavedMemo();
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

    final docSnap = await FirebaseFirestore.instance
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

  Future<void> _loadSavedMemo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reservation_memos')
        .doc(_contentId)
        .get();

    if (docSnap.exists) {
      setState(() {
        _memoController.text = docSnap.data()?['memo'] ?? '';
      });
    }
  }

  Future<void> _loadReservationWarning() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('campgrounds')
          .doc(_campName) // campName으로 문서 조회
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          // firestore 필드명을 정확히 매칭
          _reservationWarning = data['reservation_warning'] as String? ??
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
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_campName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('📌 캠핑장 ID: $_contentId', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            const Text('🔐 로그인 정보', style: TextStyle(fontWeight: FontWeight.bold)),
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

            const Text('⚠️ 예약 시 주의사항', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_reservationWarning),

            const Divider(height: 32),

            const Text('📝 추가 메모', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '예: 예약 시간, 준비물, 유의사항 등 메모',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
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

                  final memoText = _memoController.text.trim();
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('reservation_memos')
                      .doc(_contentId)
                      .set({
                    'campName': _campName,
                    'contentId': _contentId,
                    'memo': memoText,
                    'savedAt': DateTime.now(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('메모가 저장되었습니다.')),
                  );
                },
                child: const Text('메모 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
