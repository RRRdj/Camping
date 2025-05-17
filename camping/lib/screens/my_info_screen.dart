// lib/screens/my_info_screen.dart (수정된 부분 포함)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camping/screens/edit_profile_screen.dart';
import 'package:camping/screens/setting_screen.dart';
import 'package:camping/screens/my_review_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }
          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            return const Center(child: Text('프로필 데이터를 찾을 수 없습니다.'));
          }
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
                        backgroundImage: data['photoUrl'] != null && data['photoUrl'] != ''
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
                        "닉네임: ${data['nickname'] ?? ''}",
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
                // ✅ 알림 관리 항목 추가
                _buildOptionItem(
                  context,
                  icon: Icons.notifications_active,
                  title: '알림 관리',
                  onTap: () {
                    Navigator.pushNamed(context, '/alarm_manage');
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
                // 회원 탈퇴 옵션 추가
                _buildOptionItem(
                  context,
                  icon: Icons.delete_forever,
                  title: '회원 탈퇴',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('회원 탈퇴'),
                        content: const Text('정말 탈퇴하시겠습니까? 탈퇴 시 복구할 수 없습니다.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator()),
                              );
                              final uid = user.uid;
                              // Firestore 문서 삭제
                              await FirebaseFirestore.instance.collection('users').doc(uid).delete();
                              // Storage 이미지 삭제
                              try {
                                await FirebaseStorage.instance
                                    .ref()
                                    .child('userProfileImages/$uid.jpg')
                                    .delete();
                              } catch (_) {}
                              // Auth 사용자 삭제
                              try {
                                await user.delete();
                              } on FirebaseAuthException catch (e) {
                                if (e.code == 'requires-recent-login') {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('최근 로그인 인증이 필요합니다. 다시 로그인해주세요.')),
                                  );
                                  await FirebaseAuth.instance.signOut();
                                  Navigator.pushReplacementNamed(context, '/');
                                  return;
                                }
                              }
                              await FirebaseAuth.instance.signOut();
                              Navigator.pushReplacementNamed(context, '/');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
                              );
                            },
                            child: const Text('탈퇴', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 32),
                _buildOptionItem(
                  context,
                  icon: Icons.logout,
                  title: '로그아웃',
                  onTap: () async {
                    // 1) SharedPreferences에서 자동 로그인 정보 삭제
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('autoLogin');
                    await prefs.remove('savedEmail');
                    await prefs.remove('savedPw');

                    // 2) Firebase 로그아웃
                    await FirebaseAuth.instance.signOut();

                    // 3) 로그인 화면으로 이동
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
      leading: Icon(icon, color: icon == Icons.delete_forever ? Colors.red : Colors.teal),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
