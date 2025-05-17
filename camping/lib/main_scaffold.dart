// lib/main_scaffold.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'campground_data.dart';
import 'screens/camping_home_screen.dart';
import 'screens/bookmark_screen.dart';
import 'screens/my_info_screen.dart';
import 'screens/nearby_map_page.dart';  // ← 지도 페이지 위젯을 import

import 'package:camping/tools/save_fcm_token.dart'; // ✅ 추가


class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));  // ← 추가
  Map<String, bool> bookmarked = {};

  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    saveFcmToken(); // FCM 토큰 추가
  }

  Future<void> _loadBookmarks() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snap = await _fire
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .get();

    setState(() {
      bookmarked = {
        for (var doc in snap.docs) doc.id: true,
      };
    });
  }

  Future<void> toggleBookmark(String campName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final isBookmarked = bookmarked[campName] == true;

    setState(() {
      if (isBookmarked) {
        bookmarked.remove(campName);
      } else {
        bookmarked[campName] = true;
      }
    });

    final docRef = _fire
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .doc(campName);

    if (isBookmarked) {
      await docRef.delete();
    } else {
      await docRef.set({
        'campName': campName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4개의 스크린 리스트: 홈, 지도, 북마크, 내 정보
    final screens = [
    CampingHomeScreen(
                bookmarked: bookmarked,
                onToggleBookmark: toggleBookmark,
                // 홈에서 선택한 날짜를 내려줍니다.
                selectedDate: _selectedDate,
                onDateChanged: (newDate) {
                setState(() => _selectedDate = newDate);
            },
          ),
    NearbyMapPage(
        key: ValueKey(_selectedDate),
        bookmarked: bookmarked,            // ← 추가
        onToggleBookmark: toggleBookmark,  // ← 추가
        selectedDate: _selectedDate,
      ),
      BookmarkScreen(
        key: ValueKey(bookmarked.length),
        bookmarked: bookmarked,
        onToggleBookmark: toggleBookmark,
        selectedDate: _selectedDate,
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
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            label: '북마크',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}
