import 'package:camping/screens/admin_main_screen.dart';
import 'package:camping/screens/admin_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';    // ← 추가
import 'package:camping/screens/camping_info_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'main_scaffold.dart';
import 'screens/search_page.dart';
import 'screens/admin_camp_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화


  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Intl 로케일 데이터 초기화 (한국어)
  await initializeDateFormatting('ko');

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
        '/': (context) => const LoginScreen(),
        '/main': (context) => const MainScaffold(),
        '/search': (context) => const SearchPage(),
        // camp 파라미터를 동적으로 전달하도록 pushNamed 대신 MaterialPageRoute 사용 권장
        '/camping_info_screen': (context) => const CampingInfoScreen(camp: {}),
        '/signup': (context) => const SignUpScreen(),
        '/admin': (_) => const AdminDashboardScreen(),
        '/admin/camps': (_) => const AdminCampListScreen(),
        '/admin/reviews': (_) => const AdminReviewScreen(),
        '/admin/camp_edit': (_) => const EditCampScreen(),
      },
    );
  }
  
}
