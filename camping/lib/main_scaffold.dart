import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
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

    // 🔹 1. UI를 즉시 반영
    setState(() {
      if (isBookmarked) {
        bookmarked.remove(campName);
      } else {
        bookmarked[campName] = true;
      }
    });

    // 🔸 2. Firestore는 비동기로 처리
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
    final screens = [
      CampingHomeScreen(
        bookmarked: bookmarked,
        onToggleBookmark: toggleBookmark,
      ),
      BookmarkScreen(
        key: ValueKey(bookmarked.length),
        bookmarked: bookmarked,
        onToggleBookmark: toggleBookmark,
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: '북마크'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
        ],
      ),
    );
  }
}