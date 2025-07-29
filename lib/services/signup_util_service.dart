class SignUpUtilService {
  static const _avatarApi =
      'https://api.dicebear.com/6.x/adventurer/png?size=150';

  String defaultAvatar(String uid) =>
      'https://api.dicebear.com/6.x/adventurer/png?seed=$uid&size=150';

  bool isValidEmail(String email) => email.contains('@');

  String? validatePasswordMatch(String pw, String confirm) =>
      pw == confirm ? null : '비밀번호가 일치하지 않습니다.';
}
