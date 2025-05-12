// lib/screens/reservation_info_screen.dart
import 'package:flutter/material.dart';

class ReservationInfoScreen extends StatelessWidget {
  const ReservationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('예약정보')),
      body: const Center(
        child: Text(
          '여기에 예약 정보 내용을 표시하세요.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
