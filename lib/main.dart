// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ← 추가
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'main_scaffold.dart';
import 'screens/search_page.dart';
import 'screens/admin_main_screen.dart';
import 'screens/admin_camp_list_screen.dart';
import 'screens/admin_review_screen.dart';
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
  runApp(
    const ProviderScope(
      // ← 여기서 앱 전체를 감싸야 합니다
      child: MyApp(),
    ),
  );
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
        '/search': (ctx) => const SearchPage(),
        '/admin': (ctx) => const AdminDashboardScreen(),
        '/admin/camps': (ctx) => const AdminCampListScreen(),
        '/admin/reviews': (ctx) => const AdminReviewScreen(),
        '/alarm_manage': (ctx) => AlarmManageScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MainScaffold();
        }
        return const LoginScreen();
      },
    );
  }
}
