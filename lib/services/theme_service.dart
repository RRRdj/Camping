// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeService {
  ThemeService._();
  static final ThemeService _instance = ThemeService._();
  factory ThemeService() => _instance;

  /// 앱 전역에서 구독할 현재 테마 모드
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  /// Firestore 문서 경로(기존 알림 설정 문서 재사용)
  DocumentReference<Map<String, dynamic>>? _prefDoc(User user) =>
      FirebaseFirestore.instance
          .collection('user_alarm_settings')
          .doc(user.uid)
          .collection('settings')
          .doc('preferences');

  /// 시작 시/로그인 변경 시 호출: 원격 설정을 로드하여 themeMode에 반영
  Future<void> init() async {
    // 로그인 변화에 반응
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        themeMode.value = ThemeMode.system;
        return;
      }
      try {
        final snap = await _prefDoc(user)!.get();
        final data = snap.data() ?? const {};
        // 저장 방식: 'dark_enabled' == true/false, 없으면 system
        final bool? dark = data['dark_enabled'] as bool?;
        themeMode.value =
            (dark == null)
                ? ThemeMode.system
                : (dark ? ThemeMode.dark : ThemeMode.light);
      } catch (_) {
        themeMode.value = ThemeMode.system;
      }
    });
  }

  /// 스위치로 다크 켜기/끄기 (system 모드는 별도 제공)
  Future<void> setDarkEnabled(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    themeMode.value = value ? ThemeMode.dark : ThemeMode.light;
    if (user == null) return;
    await _prefDoc(user)!.set({'dark_enabled': value}, SetOptions(merge: true));
  }

  /// 시스템 따라가기로 전환
  Future<void> setSystem() async {
    final user = FirebaseAuth.instance.currentUser;
    themeMode.value = ThemeMode.system;
    if (user == null) return;
    // system 의미: 필드를 제거(또는 null 저장)
    await _prefDoc(
      user,
    )!.set({'dark_enabled': FieldValue.delete()}, SetOptions(merge: true));
  }
}
