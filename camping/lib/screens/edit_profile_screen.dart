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
  final _nameCtr = TextEditingController();
  final _nickCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  String? _selectedGender;
  File? _pickedImage;
  bool _loading = false;
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
    if (doc.exists) {
      final data = doc.data()!;
      _nameCtr.text = data['name'] ?? '';
      _nickCtr.text = data['nickname'] ?? '';
      _phoneCtr.text = data['phone'] ?? '';
      _selectedGender = data['gender'];
      _initialPhotoUrl = data['photoUrl'];
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);

    final newNick = _nickCtr.text.trim();
    // 닉네임 중복 확인 (자기 자신 제외)
    final nickSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: newNick)
        .get();
    if (nickSnap.docs.any((doc) => doc.id != user.uid)) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 사용 중인 닉네임입니다.')),
      );
      return;
    }

    String photoUrl = _initialPhotoUrl ?? '';
    // 이미지 업로드
    if (_pickedImage != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('userProfileImages')
          .child('${user.uid}.jpg');
      await ref.putFile(_pickedImage!);
      photoUrl = await ref.getDownloadURL();
    }
    // Firestore 업데이트
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'name': _nameCtr.text.trim(),
      'nickname': newNick,
      'phone': _phoneCtr.text.trim(),
      'gender': _selectedGender,
      'photoUrl': photoUrl,
    });
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('프로필이 업데이트되었습니다.')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _nickCtr.dispose();
    _phoneCtr.dispose();
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
        child: Column(
          children: [
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
            TextField(
              controller: _nameCtr,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nickCtr,
              decoration: const InputDecoration(
                labelText: '닉네임',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtr,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '전화번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: '성별',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '남성', child: Text('남성')),
                DropdownMenuItem(value: '여성', child: Text('여성')),
                DropdownMenuItem(value: '기타', child: Text('기타')),
              ],
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('저장'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


