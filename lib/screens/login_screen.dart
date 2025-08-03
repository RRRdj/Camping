// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/auth_service.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

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
      _emailCtr.text = saved['email'] ?? '';
      _pwCtr.text = saved['password'] ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loginWithEmail());
  }

  Future<void> _loginWithEmail() async {
    setState(() => _loading = true);
    try {
      await _authSvc.signIn(
        _emailCtr.text.trim(),
        _pwCtr.text.trim(),
        remember: _remember,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } on fb.FirebaseAuthException catch (e) {
      final msg = (e.code == 'user-not-found' || e.code == 'wrong-password')
          ? '이메일 또는 비밀번호가 올바르지 않습니다.'
          : '로그인에 실패했습니다.';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('로그인 중 오류가 발생했습니다. $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithKakao() async {
    setState(() => _loading = true);
    try {
      // 1. 카카오 로그인
      kakao.OAuthToken token;
      try {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 2. 사용자 정보 가져오기
      final kakao.User kakaoUser = await kakao.UserApi.instance.me();
      final nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? '사용자';
      final profileImageUrl =
          kakaoUser.kakaoAccount?.profile?.profileImageUrl;
      final email = kakaoUser.kakaoAccount?.email; // null 가능

      // 3. Firebase custom token 교환 및 로그인
      await _authSvc.signInWithKakaoToken(
        token.accessToken,
        remember: _remember,
      );
      final fb.User? user = fb.FirebaseAuth.instance.currentUser;

      // 4. Firestore에 정보 저장/병합
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': nickname,
          'nickname': nickname,
          if (profileImageUrl != null) 'photoUrl': profileImageUrl,
          if (email != null) 'email': email,
          'provider': 'kakao',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } catch (error) {
      if (mounted) {
        String message = '카카오 로그인 실패';
        if (error is kakao.KakaoException) {
          message += ': ${error.message}';
        } else if (error is fb.FirebaseAuthException) {
          message += ': ${error.message}';
        } else {
          message += ': $error';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildKakaoButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loginWithKakao,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('카카오톡으로 로그인'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          backgroundColor: const Color(0xFFFFE812),
          foregroundColor: Colors.black,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtr.dispose();
    _pwCtr.dispose();
    super.dispose();
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
                onChanged: (v) => setState(() => _remember = v ?? false),
                title: const Text('자동 로그인'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loginWithEmail,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('로그인'),
              ),
              const SizedBox(height: 8),
              _buildKakaoButton(),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
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
