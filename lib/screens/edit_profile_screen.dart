// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtr        = TextEditingController();
  final _nickCtr        = TextEditingController();
  final _phoneCtr       = TextEditingController();
  final _pwCtr          = TextEditingController(); // 새 비밀번호
  final _pwConfirmCtr   = TextEditingController(); // 비밀번호 확인
  File?   _pickedImage;
  bool    _loading       = false;
  String? _initialPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    _nameCtr.text        = data['name'] ?? '';
    _nickCtr.text        = data['nickname'] ?? '';
    _phoneCtr.text       = data['phone'] ?? '';
    _initialPhotoUrl     = data['photoUrl'];
    setState(() {});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600, imageQuality: 80);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 비밀번호 변경 처리
    final newPw = _pwCtr.text.trim();
    final confirmPw = _pwConfirmCtr.text.trim();
    if (newPw.isNotEmpty || confirmPw.isNotEmpty) {
      if (newPw.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('새 비밀번호는 최소 6자 이상이어야 합니다.')));
        return;
      }
      if (newPw != confirmPw) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('비밀번호 확인이 일치하지 않습니다.')));
        return;
      }
    }

    setState(() => _loading = true);

    // 닉네임 중복 검사
    final newNick = _nickCtr.text.trim();
    final nickSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: newNick)
        .get();
    if (nickSnap.docs.any((d) => d.id != user.uid)) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 사용 중인 닉네임입니다.')));
      return;
    }

    try {
      // 1) 비밀번호 업데이트
      if (newPw.isNotEmpty) {
        await user.updatePassword(newPw);
      }

      // 2) 프로필 사진 업로드
      String photoUrl = _initialPhotoUrl ?? '';
      if (_pickedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('userProfileImages')
            .child('${user.uid}.jpg');
        await ref.putFile(_pickedImage!);
        photoUrl = await ref.getDownloadURL();
      }

      // 3) Firestore 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name':     _nameCtr.text.trim(),
        'nickname': newNick,
        'phone':    _phoneCtr.text.trim(),
        'photoUrl': photoUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 업데이트되었습니다.')));
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      // 비밀번호 업데이트 시 재인증 필요 에러 처리
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('보안을 위해 다시 로그인해주세요.')));
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _nickCtr.dispose();
    _phoneCtr.dispose();
    _pwCtr.dispose();
    _pwConfirmCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 수정'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // 프로필 사진
          GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              backgroundImage: _pickedImage != null
                  ? FileImage(_pickedImage!)
                  : (_initialPhotoUrl != null && _initialPhotoUrl != ''
                  ? NetworkImage(_initialPhotoUrl!)
                  : null) as ImageProvider<Object>?,
            ),
          ),
          const SizedBox(height: 24),

          // 이름
          TextField(
            controller: _nameCtr,
            decoration: const InputDecoration(
                labelText: '이름', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          // 닉네임
          TextField(
            controller: _nickCtr,
            decoration: const InputDecoration(
                labelText: '닉네임', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          // 전화번호
          TextField(
            controller: _phoneCtr,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: '전화번호', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          // 새 비밀번호
          TextField(
            controller: _pwCtr,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: '새 비밀번호', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          // 비밀번호 확인
          TextField(
            controller: _pwConfirmCtr,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: '비밀번호 확인', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _saveProfile,
            child: const Text('저장'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
          ),
        ]),
      ),
    );
  }
}
