// lib/screens/my_info_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camping/screens/edit_profile_screen.dart';
import 'package:camping/screens/setting_screen.dart';
import 'package:camping/screens/my_review_screen.dart';
class MyInfoScreen extends StatelessWidget {
  const MyInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보'), centerTitle: true),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, snapshot) {
          // 1) 로딩 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2) 쿼리 에러
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }
          final doc = snapshot.data;
          // 3) 문서 자체가 없을 때
          if (doc == null || !doc.exists) {
            return const Center(child: Text('프로필 데이터를 찾을 수 없습니다.'));
          }

          // 4) 정상적으로 데이터가 있을 때
          final data = doc.data()!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage:
                        data['photoUrl'] != null && data['photoUrl'] != ''
                            ? NetworkImage(data['photoUrl']!)
                            : null,
                        backgroundColor: Colors.grey[200],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "닉네임: "+data['nickname'] ?? '',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                const SizedBox(height: 24),
                _buildOptionItem(
                  context,
                  icon: Icons.person,
                  title: '개인정보 수정',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()),
                    );
                  },
                ),
                _buildOptionItem(
                  context,
                  icon: Icons.star,
                  title: '후기 관리',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyReviewsScreen()),
                    );
                  },
                ),
                _buildOptionItem(
                  context,
                  icon: Icons.settings,
                  title: '환경설정',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                _buildOptionItem(
                  context,
                  icon: Icons.logout,
                  title: '로그아웃',
                  onTap: () {
                    FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing:
      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
