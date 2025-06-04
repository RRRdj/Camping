import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AlarmRepository {
  final _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> streamUserAlarms(String uid) {
    return _firestore
        .collection('user_alarm_settings')
        .doc(uid)
        .collection('alarms')
        .orderBy('date')
        .snapshots();
  }

  Future<void> deleteAlarm(String uid, String alarmId) {
    return _firestore
        .collection('user_alarm_settings')
        .doc(uid)
        .collection('alarms')
        .doc(alarmId)
        .delete();
  }

  Future<void> updateAlarmDate(String uid, String alarmId, DateTime newDate) {
    return _firestore
        .collection('user_alarm_settings')
        .doc(uid)
        .collection('alarms')
        .doc(alarmId)
        .update({
          'date': DateFormat('yyyy-MM-dd').format(newDate),
          'isNotified': false,
        });
  }
}
