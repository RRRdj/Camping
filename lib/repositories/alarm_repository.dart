import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AlarmRepository {
  final _fire = FirebaseFirestore.instance;

  /// 사용자가 이미 보유한 알림 개수
  Future<int> countUserAlarms(String uid) async {
    final docs =
        await _fire
            .collection('user_alarm_settings')
            .doc(uid)
            .collection('alarms')
            .get();
    return docs.size;
  }

  /// 새 알림 등록
  Future<void> addAlarm({
    required String uid,
    required String campName,
    required String? contentId,
    required DateTime date,
  }) async {
    await _fire.collection('user_alarm_settings').doc(uid).set({
      'lastAlarmAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _fire
        .collection('user_alarm_settings')
        .doc(uid)
        .collection('alarms')
        .add({
          'campName': campName,
          'contentId': contentId,
          'date': DateFormat('yyyy-MM-dd').format(date),
          'isNotified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
