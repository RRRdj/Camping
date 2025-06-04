import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/user_repository.dart';

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

  /* ───────────── Auth 동작 ───────────── */

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
