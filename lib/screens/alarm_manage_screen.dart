import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlarmManageScreen extends StatelessWidget {
  const AlarmManageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('알림 관리'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('user_alarm_settings')
                .doc(user.uid)
                .collection('alarms')
                .orderBy('date')
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final alarms = snapshot.data!.docs;
          if (alarms.isEmpty) {
            return const Center(child: Text('설정된 알림이 없습니다.'));
          }

          return ListView.separated(
            itemCount: alarms.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final data = alarms[index].data() as Map<String, dynamic>;
              final docId = alarms[index].id;
              final campName = data['campName'] ?? '이름 없음';
              final dateStr = data['date'] as String;
              final date = DateTime.parse(dateStr);
              final formatted = DateFormat('yyyy년 M월 d일').format(date);

              return ListTile(
                title: Text('$campName'),
                subtitle: Text('알림 날짜: $formatted'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.teal),
                      onPressed:
                          () => _editAlarm(context, user.uid, docId, date),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('user_alarm_settings')
                            .doc(user.uid)
                            .collection('alarms')
                            .doc(docId)
                            .delete();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('알림이 삭제되었습니다.')),
                        );
                      },
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

  Future<void> _editAlarm(
    BuildContext context,
    String uid,
    String docId,
    DateTime oldDate,
  ) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: oldDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (newDate == null) return;

    await FirebaseFirestore.instance
        .collection('user_alarm_settings')
        .doc(uid)
        .collection('alarms')
        .doc(docId)
        .update({
          'date': DateFormat('yyyy-MM-dd').format(newDate),
          'isNotified': false,
        });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('알림 날짜가 수정되었습니다.')));
  }
}
