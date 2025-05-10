import 'package:camping/screens/admin_main_screen.dart';
import 'package:camping/screens/admin_review_screen.dart';
import 'package:camping/screens/camping_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:camping/screens/camping_info_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';     // SignUpScreen
import 'main_scaffold.dart';
import 'screens/search_page.dart';
import 'screens/admin_camp_list_screen.dart';
 import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);



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
        '/': (ctx) => const LoginScreen(),
        '/signup': (ctx) => const SignUpScreen(),   // ★회원가입 화면
        '/main': (ctx) => const MainScaffold(),
        '/search': (ctx) => const SearchPage(),
        '/admin': (ctx) => const AdminDashboardScreen(),
        '/admin/camps': (ctx) => const AdminCampListScreen(),
        '/admin/reviews': (ctx) => const AdminReviewScreen(),
        '/admin/camp_edit': (ctx) => const EditCampScreen(),

      },
    );
  }
}
