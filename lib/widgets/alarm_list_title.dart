import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alarm_model.dart';

class AlarmListTile extends StatelessWidget {
  final AlarmModel alarm;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AlarmListTile({
    super.key,
    required this.alarm,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('yyyy년 M월 d일').format(alarm.date);

    return ListTile(
      title: Text(alarm.campName),
      subtitle: Text('알림 날짜: $formatted'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.teal),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
