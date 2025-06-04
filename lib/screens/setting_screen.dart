import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance
            .collection('user_alarm_settings')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences')
            .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('push_enabled')) {
        setState(() {
          notificationEnabled = data['push_enabled'] ?? true;
        });
      }
    }
  }

  Future<void> _updateNotificationSetting(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('user_alarm_settings')
        .doc(user.uid)
        .collection('settings')
        .doc('preferences')
        .set({'push_enabled': value}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('환경설정')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('푸시 알림 수신'),
            value: notificationEnabled,
            onChanged: (bool value) {
              setState(() {
                notificationEnabled = value;
              });
              _updateNotificationSetting(value);
            },
          ),
          // 다크 모드, 앱 버전은 그대로 둡니다
          SwitchListTile(
            title: const Text('다크 모드'),
            value: false,
            onChanged: (bool value) {
              // 다크 모드는 추후 구현
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('앱 버전'),
            trailing: const Text('v1.0.0'),
          ),
        ],
      ),
    );
  }
}
