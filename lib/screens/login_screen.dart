// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ 추가: 숫자 입력 필터용
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
      kakao.OAuthToken token;
      try {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      final kakao.User kakaoUser = await kakao.UserApi.instance.me();
      final nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? '사용자';
      final profileImageUrl =
          kakaoUser.kakaoAccount?.profile?.profileImageUrl;
      final email = kakaoUser.kakaoAccount?.email;

      await _authSvc.signInWithKakaoToken(
        token.accessToken,
        remember: _remember,
      );
      final fb.User? user = fb.FirebaseAuth.instance.currentUser;

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

  /// ✅ 관리자 진입 전 코드 입력 다이얼로그
  Future<void> _promptAdminCode() async {
    final codeCtr = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('관리자 코드 8자리를 입력하세요'),
        content: TextField(
          controller: codeCtr,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly], // 숫자만
          maxLength: 8, // 안내에 맞춰 표시(검증은 아래에서 수행)
          decoration: const InputDecoration(
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, codeCtr.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, codeCtr.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (!mounted || entered == null) return;

    // 허용 코드: '8888888' (요청값). 안내 문구는 8자리지만, 입력 길이는 엄격히 제한하지 않습니다.
    if (entered == '88888888' /* || entered == '88888888' */) {
      Navigator.pushNamed(context, '/admin');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 코드가 올바르지 않습니다.')),
      );
    }
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              // ✅ 관리자 전용 화면: 코드 입력 후 진입
              TextButton(
                onPressed: _promptAdminCode,
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
