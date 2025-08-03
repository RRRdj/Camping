import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/user_repository.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _userRepo = UserRepository();

  /* ───────────── SharedPreferences ───────────── */

  Future<Map<String, String>> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('autoLogin') ?? false)) return {};
    return {
      'email': prefs.getString('savedEmail') ?? '',
      'password': prefs.getString('savedPw') ?? '',
    };
  }

  Future<void> saveCredentials(String email, String pw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs
      ..setBool('autoLogin', true)
      ..setString('savedEmail', email)
      ..setString('savedPw', pw);
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs
      ..remove('autoLogin')
      ..remove('savedEmail')
      ..remove('savedPw');
  }

  /* ───────────── Email/PW 로그인 ───────────── */

  Future<UserCredential> signIn(
      String email,
      String pw, {
        bool remember = false,
      }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: pw,
    );
    await _userRepo.ensureUserDoc(cred.user!);
    if (remember) {
      await saveCredentials(email, pw);
    } else {
      await clearCredentials();
    }
    return cred;
  }

  /* ───────────── Kakao 로그인 (Firebase 연동) ───────────── */

  /// 백엔드에 카카오 액세스 토큰을 보내면, 검증 후 Firebase Custom Token을 받아서 로그인
  Future<UserCredential> signInWithKakaoToken(String kakaoAccessToken, {bool remember = false}) async {
    // 1. 백엔드로 카카오 토큰 전송해서 Firebase custom token 받기
    final uri = Uri.parse('https://kakaoauth-xgyfbbhnvq-uc.a.run.app/kakaoAuth'); // 실제 엔드포인트로 교체
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'access_token': kakaoAccessToken}),
    );

    if (resp.statusCode != 200) {
      throw Exception('백엔드에서 커스텀 토큰을 가져오지 못했습니다: ${resp.body}');
    }

    final body = json.decode(resp.body);
    final String firebaseCustomToken = body['firebase_custom_token'];
    if (firebaseCustomToken.isEmpty) {
      throw Exception('커스텀 토큰이 비어있습니다.');
    }

    // 2. Firebase에 커스텀 토큰으로 로그인
    final cred = await _auth.signInWithCustomToken(firebaseCustomToken);

    // 3. 사용자 문서 보장
    await _userRepo.ensureUserDoc(cred.user!);

    // 자동 로그인 같은 로직 필요 시 (카카오 로그인은 이메일/비번 기반이 아니므로 저장 정책은 별도 결정)
    if (remember) {
      // 필요하면 kakao용 표시를 저장하거나, 자체 플래그로 처리
    } else {
      await clearCredentials();
    }

    return cred;
  }

  Future<void> signOut() async {
    await clearCredentials();
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    await _userRepo.deleteUserDoc(uid);
    await _userRepo.deleteUserImage(uid);

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw FirebaseAuthException(code: e.code, message: '최근 로그인 인증이 필요합니다.');
      }
      rethrow;
    }

    await clearCredentials();
    await _auth.signOut();
  }
}
