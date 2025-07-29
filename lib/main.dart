// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

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

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ko');
  await requestNotificationPermission();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '금오캠핑',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
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
                                await FirebaseAuth.instance.signOut();
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
