import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camping/services/theme_service.dart';

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
              setState(() => notificationEnabled = value);
              _updateNotificationSetting(value);
            },
          ),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService().themeMode,
            builder: (_, mode, __) {
              final isDark = mode == ThemeMode.dark;
              return SwitchListTile(
                title: const Text('다크 모드'),
                subtitle: Text(
                  mode == ThemeMode.system
                      ? '시스템 설정을 따름'
                      : (isDark ? '다크' : '라이트'),
                ),
                value: isDark,
                onChanged: (bool value) {
                  ThemeService().setDarkEnabled(value);
                },
                secondary: PopupMenuButton<String>(
                  tooltip: '모드 선택',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    if (v == 'system') ThemeService().setSystem();
                    if (v == 'light') ThemeService().setDarkEnabled(false);
                    if (v == 'dark') ThemeService().setDarkEnabled(true);
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(value: 'system', child: Text('시스템 기본')),
                        PopupMenuItem(value: 'light', child: Text('라이트')),
                        PopupMenuItem(value: 'dark', child: Text('다크')),
                      ],
                ),
              );
            },
          ),

          const Divider(),
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
