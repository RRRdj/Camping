// lib/screens/reservation_info_screen.dart

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
  String _campType = ''; // API에서 받은 campType
  late bool _isNational; // campType.contains('국립') 판별
  String _reservationWarning = '로딩 중...';

  static const _nationalDocId = 'national_login';
  // 국립 캠핑장 전용으로 고정된 문서 ID

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
          _campType = args['campType'] ?? '';
          _isNational = _campType.contains('국립');
          if (args.containsKey('reservationWarning')) {
            _reservationWarning = args['reservationWarning'] as String;
          }
        });
        _loadSavedReservationInfo();
        _loadSavedMemo();
        if (!args.containsKey('reservationWarning')) {
          _loadReservationWarning();
        }
      }
    });
  }

  /// 로그인 정보 불러오기 (국립은 고정 doc, 지자체는 contentId 기반)
  Future<void> _loadSavedReservationInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final base = FirebaseFirestore.instance.collection('users').doc(user.uid);

    if (_isNational) {
      final doc =
          await base
              .collection('reservation_national')
              .doc(_nationalDocId)
              .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _idController.text = data['loginId'] ?? '';
          _pwController.text = data['loginPassword'] ?? '';
        });
      }
    } else {
      final doc =
          await base.collection('reservation_info').doc(_contentId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _idController.text = data['reservationUserId'] ?? '';
          _pwController.text = data['reservationPassword'] ?? '';
        });
      }
    }
  }

  /// 추가 메모 불러오기 (변경 없음)
  Future<void> _loadSavedMemo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reservation_memos')
            .doc(_contentId)
            .get();

    if (doc.exists) {
      setState(() {
        _memoController.text = doc.data()?['memo'] ?? '';
      });
    }
  }

  /// 예약 시 주의사항 불러오기 (변경 없음)
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
    _memoController.dispose();
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

            // 🔐 로그인 정보
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
              obscureText: true,
              autofillHints: const [AutofillHints.password],
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

                  final id = _idController.text.trim();
                  final pw = _pwController.text.trim();
                  if (id.isEmpty || pw.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('아이디와 비밀번호를 모두 입력하세요.')),
                    );
                    return;
                  }

                  final now = DateTime.now();
                  final base = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid);

                  if (_isNational) {
                    // 국립 캠핑장: 항상 같은 문서에 저장
                    await base
                        .collection('reservation_national')
                        .doc(_nationalDocId)
                        .set({
                          'campName': _campName,
                          'loginId': id,
                          'loginPassword': pw,
                          'savedAt': now,
                        });
                  } else {
                    // 지자체 캠핑장: contentId로 구분
                    await base
                        .collection('reservation_info')
                        .doc(_contentId)
                        .set({
                          'campName': _campName,
                          'contentId': _contentId,
                          'reservationUserId': id,
                          'savedAt': now,
                          'email': user.email ?? '',
                        });
                  }

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
          ],
        ),
      ),
    );
  }
}
