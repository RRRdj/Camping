import 'package:flutter/material.dart';
import 'campground_data.dart';
import 'screens/camping_home_screen.dart';
import 'screens/bookmark_screen.dart';
import 'screens/my_info_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  Map<String, bool> bookmarked = {};

  void toggleBookmark(String name) {
    setState(() {
      bookmarked[name] = !(bookmarked[name] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CampingHomeScreen(
        bookmarked: bookmarked,
        onToggleBookmark: toggleBookmark,
      ),
      BookmarkScreen(
        bookmarked: bookmarked,
        onToggleBookmark: toggleBookmark, // ✅ 이거 추가!
      ),

      const MyInfoScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: '북마크'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
        ],
      ),


      
    );
  }
}