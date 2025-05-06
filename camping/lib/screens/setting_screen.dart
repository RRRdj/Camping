import 'package:flutter/material.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool notificationEnabled = true;
    bool darkMode = false;

    return Scaffold(
      appBar: AppBar(title: const Text('환경설정')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('푸시 알림 수신'),
            value: notificationEnabled,
            onChanged: (bool value) {
              // 스위치 변경 처리 로직
            },
          ),
          SwitchListTile(
            title: const Text('다크 모드'),
            value: darkMode,
            onChanged: (bool value) {
              // 다크 모드 설정 로직
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