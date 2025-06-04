// lib/widgets/reservation_action_buttons.dart
import 'package:flutter/material.dart';

class ReservationActionButtons extends StatelessWidget {
  final VoidCallback onSchedule;
  final VoidCallback onInfo;
  final VoidCallback onAlarm;

  const ReservationActionButtons({
    super.key,
    required this.onSchedule,
    required this.onInfo,
    required this.onAlarm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: const Text('예약 현황'),
          onPressed: onSchedule,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.info_outline),
          label: const Text('예약정보'),
          onPressed: onInfo,
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('알림'),
          onPressed: onAlarm,
        ),
      ],
    );
  }
}
