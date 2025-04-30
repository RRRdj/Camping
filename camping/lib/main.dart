import 'package:camping/screens/camping_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'main_scaffold.dart';
import 'screens/search_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),           // ✅ 시작화면
        '/main': (context) => const MainScaffold(),      // ✅ 로그인 성공 후 메인
        '/search': (context) => const SearchPage(),      // 검색
        '/camping_info_screen': (context) => const CampingInfoScreen(),
        '/signup': (context) => const SignUpScreen(), // ✅ 회원가입 경로 등록
        // '/signup': ... 추후 회원가입 추가 가능
      },
    );
  }
}
