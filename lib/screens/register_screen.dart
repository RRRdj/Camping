import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../repositories/auth_repository.dart';
import '../services/signup_util_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _repo = AuthRepository();
  final _util = SignUpUtilService();

  final _emailCtr = TextEditingController();
  final _pwCtr = TextEditingController();
  final _pwConfirmCtr = TextEditingController();
  final _nameCtr = TextEditingController();
  final _nickCtr = TextEditingController();
  final _phoneCtr = TextEditingController();

  File? _pickedImage;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtr.dispose();
    _pwCtr.dispose();
    _pwConfirmCtr.dispose();
    _nameCtr.dispose();
    _nickCtr.dispose();
    _phoneCtr.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _register() async {
    final email = _emailCtr.text.trim();
    final pw = _pwCtr.text.trim();
    final pw2 = _pwConfirmCtr.text.trim();
    final nick = _nickCtr.text.trim();

    if (!_util.isValidEmail(email)) {
      return _toast('올바른 이메일을 입력해주세요.');
    }
    final pwErr = _util.validatePasswordMatch(pw, pw2);
    if (pwErr != null) {
      return _toast(pwErr);
    }

    setState(() => _loading = true);
    try {
      if (await _repo.isNicknameTaken(nick)) {
        return _toast('이미 사용 중인 닉네임입니다.');
      }

      final uid = await _repo.signUp(email: email, pw: pw);

      final photoUrl =
          _pickedImage != null
              ? await _repo.uploadProfileImage(uid, _pickedImage!)
              : _util.defaultAvatar(uid);

      await _repo.saveUserData(uid, {
        'email': email,
        'name': _nameCtr.text.trim(),
        'nickname': nick,
        'phone': _phoneCtr.text.trim(),
        'photoUrl': photoUrl,
        'createdAt': DateTime.now(),
      });

      if (!mounted) return;
      _toast('회원가입이 완료되었습니다.');
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      _toast('오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            _pickedImage != null
                                ? FileImage(_pickedImage!) as ImageProvider
                                : NetworkImage(_util.defaultAvatar('preview')),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildInput(
                      _emailCtr,
                      '이메일',
                      type: TextInputType.emailAddress,
                    ),
                    _gap(),
                    _buildInput(_pwCtr, '비밀번호', obsc: true),
                    _gap(),
                    _buildInput(_pwConfirmCtr, '비밀번호 확인', obsc: true),
                    _gap(),
                    _buildInput(_nameCtr, '이름'),
                    _gap(),
                    _buildInput(_nickCtr, '닉네임'),
                    _gap(),
                    _buildInput(_phoneCtr, '전화번호', type: TextInputType.phone),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('회원가입'),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    bool obsc = false,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obsc,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  SizedBox _gap() => const SizedBox(height: 16);
}
