// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'main_scaffold.dart';

import 'screens/admin_main_screen.dart';
import 'screens/admin_camp_list_screen.dart';
import 'screens/admin_review_screen.dart';
import 'screens/admin_user_management_screen.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:camping/screens/alarm_manage_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

// 전역 테마 서비스
import 'services/theme_service.dart';

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kakao.KakaoSdk.init(nativeAppKey: 'd9d804fdec134c6b3df66f16b032ab4d');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ko');
  await requestNotificationPermission();

  // 사용자별 테마 모드 초기화
  await ThemeService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().themeMode,
      builder: (_, mode, __) {
        // 공통 컬러 스킴
        final lightScheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        );

        return MaterialApp(
          title: '금오캠핑',
          debugShowCheckedModeBanner: false,

          // -------- Light Theme --------
          theme: ThemeData(
            colorScheme: lightScheme,
            brightness: Brightness.light,
            useMaterial3: true,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: lightScheme.surfaceVariant,
              hintStyle: TextStyle(color: lightScheme.onSurfaceVariant),
              prefixIconColor: lightScheme.onSurfaceVariant,
              suffixIconColor: lightScheme.onSurfaceVariant,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: lightScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: lightScheme.primary, width: 1.5),
              ),
            ),
            cardTheme: CardTheme(
              color: lightScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              selectedItemColor: lightScheme.primary,
              unselectedItemColor: lightScheme.onSurfaceVariant,
              backgroundColor: lightScheme.surface,
              selectedIconTheme: const IconThemeData(size: 26),
            ),
          ),

          // -------- Dark Theme (검색창/칩/카드 대비 강화) --------
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            brightness: Brightness.dark,
            useMaterial3: true,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: darkScheme.surfaceContainerHighest,
              hintStyle: TextStyle(
                color: darkScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              prefixIconColor: darkScheme.onSurfaceVariant,
              suffixIconColor: darkScheme.onSurfaceVariant,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: darkScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: darkScheme.primary, width: 1.5),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: darkScheme.surfaceContainerHigh,
              selectedColor: darkScheme.primaryContainer,
              labelStyle: TextStyle(color: darkScheme.onSurface),
              secondaryLabelStyle: TextStyle(
                color: darkScheme.onPrimaryContainer,
              ),
              side: BorderSide(color: darkScheme.outlineVariant),
            ),

            cardTheme: CardTheme(
              color: darkScheme.surfaceContainerHigh,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              selectedItemColor: darkScheme.primary,
              unselectedItemColor: darkScheme.onSurfaceVariant,
              backgroundColor: darkScheme.surface,
              selectedIconTheme: const IconThemeData(size: 26),
            ),
          ),

          // 현재 모드
          themeMode: mode,

          // ----- 로컬라이제이션 -----
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // ----- 라우팅 -----
          home: const AuthGate(),
          routes: {
            '/login': (ctx) => const LoginScreen(),
            '/signup': (ctx) => const RegisterScreen(),
            '/main': (ctx) => const MainScaffold(),
            '/admin': (ctx) => const AdminDashboardScreen(),
            '/admin/camps': (ctx) => const AdminCampListScreen(),
            '/admin/reviews': (ctx) => const AdminReviewScreen(),
            '/admin/users': (ctx) => const AdminUserManagementScreen(),
            '/alarm_manage': (ctx) => const AlarmManageScreen(),
          },
        );
      },
    );
  }
}

/// 로그인 상태 + 차단 여부 체크
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _shownBlockDialog = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb.User?>(
      stream: fb.FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final fb.User? user = snap.data;
        if (user == null) {
          _shownBlockDialog = false;
          return const LoginScreen();
        }
        // 사용자 문서에서 blocked 확인
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
          builder: (ctx2, snap2) {
            if (snap2.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snap2.data?.data();
            final blocked = (data?['blocked'] as bool?) ?? false;
            if (blocked) {
              if (!_shownBlockDialog) {
                _shownBlockDialog = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (ctx3) => AlertDialog(
                          title: const Text('차단된 사용자'),
                          content: const Text('사용이 금지된 사용자입니다.'),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(ctx3);
                                await fb.FirebaseAuth.instance.signOut();
                              },
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                  );
                });
              }
              // 다이얼로그 띄우는 동안 빈 화면 유지
              return const Scaffold(body: SizedBox());
            }
            _shownBlockDialog = false;
            return const MainScaffold();
          },
        );
      },
    );
  }
}
