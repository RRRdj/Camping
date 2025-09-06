// lib/screens/my_info_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'setting_screen.dart';
import 'my_review_screen.dart';
import '../widgets/app_loading.dart';

class MyInfoScreen extends StatelessWidget {
  MyInfoScreen({Key? key}) : super(key: key);

  final _authSvc = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '내 정보',
          style: TextStyle(
            fontWeight: FontWeight.bold, // 볼드체 적용
            fontSize: 20, // 필요 시 크기 조정
          ),
        ),
        centerTitle: true,
      ),

      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future:
            FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading(); //
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류 발생: ${snapshot.error}'));
          }
          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
            return const Center(child: Text('프로필 데이터를 찾을 수 없습니다.'));
          }
          final data = doc.data()!;

          final provider = data['provider'] as String?;
          final emailFromFirestore = (data['email'] as String?) ?? '';
          final displayEmail =
              emailFromFirestore.isNotEmpty
                  ? emailFromFirestore
                  : (user.email ?? '');

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
                            (data['photoUrl'] ?? '').toString().isNotEmpty
                                ? NetworkImage(data['photoUrl'])
                                : null,
                        backgroundColor: Colors.grey[200],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "닉네임: ${data['nickname'] ?? ''}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        displayEmail.isNotEmpty ? displayEmail : '이메일 없음',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (provider != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '로그인 방식: ${provider == 'kakao' ? '카카오톡' : provider}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _item(
                  context,
                  icon: Icons.person,
                  title: '개인정보 수정',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                ),
                _item(
                  context,
                  icon: Icons.star,
                  title: '후기 관리',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyReviewsScreen(),
                        ),
                      ),
                ),
                _item(
                  context,
                  icon: Icons.notifications_active,
                  title: '알림 관리',
                  onTap: () => Navigator.pushNamed(context, '/alarm_manage'),
                ),
                _item(
                  context,
                  icon: Icons.settings,
                  title: '환경설정',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                ),
                const SizedBox(height: 16),
                /*──────── 회원 탈퇴 ─────────*/
                _item(
                  context,
                  icon: Icons.delete_forever,
                  title: '회원 탈퇴',
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text('회원 탈퇴'),
                            content: const Text(
                              '정말 탈퇴하시겠습니까? 탈퇴 시 복구할 수 없습니다.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  '탈퇴',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );
                    if (ok != true) return;

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder:
                          (_) =>
                              const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      await _authSvc.deleteAccount();
                      if (!context.mounted) return;
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (_) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
                      );
                    } on FirebaseAuthException catch (e) {
                      Navigator.pop(context); // 로딩 다이얼로그 닫기
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message ?? '탈퇴 실패')),
                      );
                    }
                  },
                  iconColor: Colors.red,
                ),
                const Divider(height: 32),
                /*──────── 로그아웃 ─────────*/
                _item(
                  context,
                  icon: Icons.logout,
                  title: '로그아웃',
                  onTap: () async {
                    await _authSvc.signOut();
                    if (!context.mounted) return;
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /* 공통 ListTile 위젯 */
  Widget _item(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.teal,
  }) => ListTile(
    leading: Icon(icon, color: iconColor),
    title: Text(title, style: const TextStyle(fontSize: 16)),
    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
    onTap: onTap,
  );
}
