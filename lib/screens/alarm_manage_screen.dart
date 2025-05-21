import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/alarm_repository.dart';
import '../services/format_service.dart';

class AlarmManageScreen extends StatelessWidget {
  AlarmManageScreen({super.key});

  final _repo = AlarmRepository();
  final _fmt = FormatService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));

    return Scaffold(
      appBar: AppBar(title: const Text('알림 관리'), centerTitle: true),
      body: StreamBuilder(
        stream: _repo.alarmsStream(user.uid),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = (snap.data! as dynamic).docs as List;
          if (docs.isEmpty) return const Center(child: Text('설정된 알림이 없습니다.'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final m = docs[i].data() as Map<String, dynamic>;
              final alarmId = docs[i].id;
              final campName = m['campName'] ?? '이름 없음';
              final date = (m['date'] as Timestamp).toDate();

              return ListTile(
                title: Text(campName),
                subtitle: Text('알림 날짜: ${_fmt.reviewDate(date)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.teal),
                      onPressed: () => _edit(ctx, user.uid, alarmId, date),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _delete(ctx, user.uid, alarmId),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, String uid, String id) async {
    await _repo.deleteAlarm(uid: uid, alarmId: id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('알림이 삭제되었습니다.')));
  }

  Future<void> _edit(
    BuildContext context,
    String uid,
    String id,
    DateTime old,
  ) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: old,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (newDate == null) return;
    await _repo.updateAlarmDate(uid: uid, alarmId: id, newDate: newDate);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('알림 날짜가 수정되었습니다.')));
  }
}
