// lib/screens/signup_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailCtr        = TextEditingController();
  final _pwCtr           = TextEditingController();
  final _pwConfirmCtr    = TextEditingController();
  final _nameCtr         = TextEditingController();
  final _nickCtr         = TextEditingController();
  final _phoneCtr        = TextEditingController();
  File?   _pickedImage;
  bool    _loading       = false;

  static const _defaultAvatar =
      'https://api.dicebear.com/6.x/adventurer/png?size=150';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko');
  }

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
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _signUp() async {
    final email      = _emailCtr.text.trim();
    final pw         = _pwCtr.text.trim();
    final pwConfirm  = _pwConfirmCtr.text.trim();
    final nick       = _nickCtr.text.trim();

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 이메일을 입력해주세요.')),
      );
      return;
    }
    if (pw != pwConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // 닉네임 중복 확인
      final nickSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nick)
          .get();
      if (nickSnap.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 사용 중인 닉네임입니다.')),
        );
        return;
      }

      // Firebase Auth 가입
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pw);
      final uid = cred.user!.uid;

      // 프로필 사진 업로드 or 기본 URL
      String photoUrl;
      if (_pickedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('userProfileImages')
            .child('$uid.jpg');
        await ref.putFile(_pickedImage!);
        photoUrl = await ref.getDownloadURL();
      } else {
        photoUrl = 'https://api.dicebear.com/6.x/adventurer/png?seed=$uid&size=150';
      }

      // Firestore에 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'email':     email,
        'name':      _nameCtr.text.trim(),
        'nickname':  nick,
        'phone':     _phoneCtr.text.trim(),
        'photoUrl':  photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입되었습니다.')),
      );
      Navigator.pushReplacementNamed(context, '/');
    } on FirebaseAuthException catch (e) {
      String msg = '알 수 없는 오류가 발생했습니다.';
      if (e.code == 'email-already-in-use') {
        msg = '이미 사용 중인 이메일 주소입니다.';
      } else if (e.code == 'weak-password') {
        msg = '비밀번호가 너무 짧습니다. 최소 6자 이상 입력해주세요.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              backgroundImage: _pickedImage != null
                  ? FileImage(_pickedImage!)
                  : const NetworkImage(_defaultAvatar),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailCtr,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: '이메일', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwCtr,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: '비밀번호', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwConfirmCtr,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: '비밀번호 확인', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtr,
            decoration: const InputDecoration(
                labelText: '이름', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nickCtr,
            decoration: const InputDecoration(
                labelText: '닉네임', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtr,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: '전화번호', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _signUp,
            child: const Text('회원가입'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
          ),
        ]),
      ),
    );
  }
}
