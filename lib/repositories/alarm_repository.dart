import 'package:cloud_firestore/cloud_firestore.dart';

class AlarmRepository {
  final _fire = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> alarmsStream(String uid) =>
      _fire
          .collection('user_alarm_settings')
          .doc(uid)
          .collection('alarms')
          .orderBy('date')
          .snapshots();

  Future<void> deleteAlarm({
    required String uid,
    required String alarmId,
  }) async {
    await _fire
        .collection('user_alarm_settings')
        .doc(uid)
        .collection('alarms')
        .doc(alarmId)
        .delete();
  }

  Future<void> updateAlarmDate({
    required String uid,
    required String alarmId,
    required DateTime newDate,
  }) async {
    await _fire
        .collection('user_alarm_settings')
        .doc(uid)
        .collection('alarms')
        .doc(alarmId)
        .update({'date': newDate, 'isNotified': false});
  }
}
