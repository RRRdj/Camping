import 'package:camping/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/region_selection_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/camping_info_screen.dart';
import 'screens/camping_reservation_screen.dart';
import 'screens/camping_sites_page.dart';
import 'screens/search_result_page.dart';
import 'screens/camping_home_screen.dart';
import 'screens/book_mark_screen.dart';
import 'screens/my_info_screen.dart';
import 'screens/memo_screen.dart';
import 'screens/review_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // ✅ 이 부분 중요
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '금오캠핑',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/': (context) => const BottomNavPage(),
        '/detail': (context) => DetailScreen(),
        '/camping_info': (context) => const CampingInfoScreen(),
        '/camping_reservation': (context) => CampingReservationScreen(),
        '/camping_sites_page': (context) => CampingSitesPage(),
        '/search_result': (context) => SearchResultPage(),
        '/signup': (context) => SignUpScreen(),
        '/review': (context) => ReviewScreen(),
        '/memo': (context) => MemoScreen(),
        '/bookmark': (context) => BookmarksScreen(),
        '/myinfo': (context) => MyInfoScreen(),
      },
    );
  }
}

class BottomNavPage extends StatefulWidget {
  const BottomNavPage({Key? key}) : super(key: key);

  @override
  _BottomNavPageState createState() => _BottomNavPageState();
}

class _BottomNavPageState extends State<BottomNavPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    CampingHomeScreen(),
    BookmarksScreen(),
    MyInfoScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), label: '북마크'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '내 정보'),
        ],
      ),
    );
  }
}