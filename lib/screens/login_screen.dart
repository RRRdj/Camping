import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtr = TextEditingController();
  final _pwCtr = TextEditingController();
  final _authSvc = AuthService();

  bool _loading = false;
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final saved = await _authSvc.loadSavedCredentials();
    if (saved.isEmpty) return;

    setState(() {
      _remember = true;
      _emailCtr.text = saved['email']!;
      _pwCtr.text = saved['password']!;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _login());
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await _authSvc.signIn(
        _emailCtr.text.trim(),
        _pwCtr.text.trim(),
        remember: _remember,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } on FirebaseAuthException catch (e) {
      final msg =
          (e.code == 'user-not-found' || e.code == 'wrong-password')
              ? '이메일 또는 비밀번호가 올바르지 않습니다.'
              : '로그인에 실패했습니다.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('금오캠핑'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      const Text(
                        '로그인',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _emailCtr,
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pwCtr,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '비밀번호',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: _remember,
                        onChanged:
                            (v) => setState(() => _remember = v ?? false),
                        title: const Text('자동 로그인'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('로그인'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed:
                            () => Navigator.pushNamed(context, '/signup'),
                        child: const Text('회원가입'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/admin'),
                        child: const Text(
                          '관리자 전용 화면',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
      ),
    );
  }
}
