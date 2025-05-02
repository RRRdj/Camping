import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────
/// 1. 내 정보(MyInfoScreen)
/// ──────────────────────────────────────────────
class MyInfoScreen extends StatelessWidget {
  const MyInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const _ProfileHeader(),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            _Option(
              icon: Icons.book,
              title: '예약 내역',
              onTap: () {
                /* 예약 내역 화면 */
              },
            ),
            _Option(
              icon: Icons.rate_review,
              title: '후기 내역',
              onTap: () {
                /* 후기 내역 화면 */
              },
            ),

            _Option(
              icon: Icons.person,
              title: '개인정보 수정',
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileEditScreen(),
                    ),
                  ),
            ),
            _Option(
              icon: Icons.settings,
              title: '환경설정',
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
            ),
            _Option(
              icon: Icons.logout,
              title: '로그아웃',
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundImage: AssetImage('assets/images/profile.jpg'),
        ),
        const SizedBox(height: 12),
        const Text(
          '홍길동',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'honggildong@example.com',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.onTap,
    Key? key,
  }) : super(key: key);
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}

/// ──────────────────────────────────────────────
/// 2. 환경설정(SettingsScreen)
///    • 관리자 모드, 알림 토글
///    • '회원정보 변경' 옵션 제거
/// ──────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAdmin = false;
  bool _pushNotify = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('환경설정'), centerTitle: true),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('관리자 모드'),
            value: _isAdmin,
            onChanged: (v) => setState(() => _isAdmin = v),
          ),
          SwitchListTile(
            title: const Text('알림 받기'),
            subtitle: const Text('푸시 · 예약 알림'),
            value: _pushNotify,
            onChanged: (v) => setState(() => _pushNotify = v),
          ),
          // 회원정보 변경 옵션 삭제됨
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────
/// 3. 회원정보 수정(ProfileEditScreen)
///    (MyInfoScreen의 개인정보 수정에서만 사용)
/// ──────────────────────────────────────────────
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({Key? key}) : super(key: key);
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickCtrl = TextEditingController(text: '홍길동');
  final _idCtrl = TextEditingController(text: 'honggildong@example.com');
  final _pwCtrl = TextEditingController();

  @override
  void dispose() {
    _nickCtrl.dispose();
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원정보가 수정되었습니다')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원정보 변경'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nickCtrl,
                decoration: const InputDecoration(labelText: '닉네임'),
                validator:
                    (v) => (v == null || v.isEmpty) ? '닉네임을 입력하세요' : null,
              ),
              TextFormField(
                controller: _idCtrl,
                decoration: const InputDecoration(labelText: 'ID(이메일)'),
                validator:
                    (v) =>
                        (v == null || !v.contains('@')) ? '이메일 형식이 아닙니다' : null,
              ),
              TextFormField(
                controller: _pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '새 비밀번호'),
                validator:
                    (v) =>
                        (v != null && v.isNotEmpty && v.length < 6)
                            ? '6자 이상 입력하세요'
                            : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _save, child: const Text('저장')),
            ],
          ),
        ),
      ),
    );
  }
}
