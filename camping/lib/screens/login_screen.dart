import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtr = TextEditingController();
  final _pwCtr    = TextEditingController();
  bool _loading   = false;
  bool _autoLogin = false;

  @override
  void initState() {
    super.initState();
    _loadAutoLogin();
  }

  Future<void> _loadAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final auto   = prefs.getBool('autoLogin') ?? false;
    if (auto) {
      final savedEmail = prefs.getString('savedEmail') ?? '';
      final savedPw    = prefs.getString('savedPw')    ?? '';
      if (savedEmail.isNotEmpty && savedPw.isNotEmpty) {
        setState(() {
          _autoLogin = true;
          _emailCtr.text = savedEmail;
          _pwCtr.text    = savedPw;
        });
        // 프레임 완료 후 자동 로그인 시도
        WidgetsBinding.instance.addPostFrameCallback((_) => _login());
      }
    }
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final email = _emailCtr.text.trim();
      final pw    = _pwCtr.text.trim();

      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pw);
      final uid = cred.user!.uid;

      // Firestore 유저 문서가 없으면 생성
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc    = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'email':     cred.user!.email ?? '',
          'name':      '',
          'nickname':  '',
          'phone':     '',
          'gender':    '',
          'photoUrl':
          'https://api.dicebear.com/6.x/adventurer/png?seed=$uid&size=150',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // SharedPreferences에 저장/삭제
      final prefs = await SharedPreferences.getInstance();
      if (_autoLogin) {
        await prefs.setBool('autoLogin', true);
        await prefs.setString('savedEmail', email);
        await prefs.setString('savedPw', pw);
      } else {
        await prefs.remove('autoLogin');
        await prefs.remove('savedEmail');
        await prefs.remove('savedPw');
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } on FirebaseAuthException catch (e) {
      String msg = '로그인에 실패했습니다.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        msg = '이메일 또는 비밀번호가 올바르지 않습니다.';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('금오캠핑'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              const Text('로그인',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),

              // 이메일 입력
              TextField(
                controller: _emailCtr,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // 비밀번호 입력
              TextField(
                controller: _pwCtr,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 자동 로그인 체크박스
              CheckboxListTile(
                value: _autoLogin,
                onChanged: (v) => setState(() {
                  _autoLogin = v ?? false;
                }),
                title: const Text('자동 로그인'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),

              // 로그인 버튼
              ElevatedButton(
                onPressed: _login,
                child: const Text('로그인'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 16),

              // 회원가입 / 관리자 화면
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text('회원가입'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/admin'),
                child: const Text('관리자 전용 화면',
                    style: TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
