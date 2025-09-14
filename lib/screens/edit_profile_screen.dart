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
  final _pwCtr = TextEditingController();
  final _pwConfirmCtr = TextEditingController();

  File? _pickedImage;
  bool _loading = false;
  String? _initialPhotoUrl;
  bool _isKakao = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    _nameCtr.text = data['name'] ?? '';
    _nickCtr.text = data['nickname'] ?? '';
    _phoneCtr.text = data['phone'] ?? '';
    _initialPhotoUrl = data['photoUrl'];
    _isKakao = (data['provider'] as String?) == 'kakao';

    setState(() {});
  }

  Future<void> _pickImage() async {
    if (_isKakao) return; // 방어: 카카오 사용자는 선택 불가

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  ImageProvider? _currentImageProvider() {
    if (_pickedImage != null) return FileImage(_pickedImage!);
    if (_initialPhotoUrl != null && _initialPhotoUrl!.isNotEmpty) {
      return NetworkImage(_initialPhotoUrl!);
    }
    return null;
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newPw = _pwCtr.text.trim();
    final confirmPw = _pwConfirmCtr.text.trim();
    if (!_isKakao && (newPw.isNotEmpty || confirmPw.isNotEmpty)) {
      if (newPw.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새 비밀번호는 최소 6자 이상이어야 합니다.')),
        );
        return;
      }
      if (newPw != confirmPw) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호 확인이 일치하지 않습니다.')),
        );
        return;
      }
    }

    setState(() => _loading = true);

    // 닉네임 중복 체크
    final newNick = _nickCtr.text.trim();
    final nickSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: newNick)
        .get();
    if (nickSnap.docs.any((d) => d.id != user.uid)) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이미 사용 중인 닉네임입니다.')));
      return;
    }

    try {
      if (!_isKakao && newPw.isNotEmpty) {
        await user.updatePassword(newPw);
      }

      String photoUrl = _initialPhotoUrl ?? '';
      // 카카오 사용자는 사진 변경 불가. 일반 사용자만 업로드 수행.
      if (!_isKakao && _pickedImage != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('userProfileImages')
            .child('${user.uid}.jpg');

        // 메타데이터를 붙여두면 규칙(contentType) 검증에 유리합니다.
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=3600',
        );

        await ref.putFile(_pickedImage!, metadata);
        photoUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': _nameCtr.text.trim(),
        'nickname': newNick,
        'phone': _phoneCtr.text.trim(),
        'photoUrl': photoUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('프로필이 업데이트되었습니다.')));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('보안을 위해 다시 로그인해주세요.')));
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: ${e.message}')),
      );
    } on FirebaseException catch (e) {
      // Storage 권한/용량 등 Firebase 에러 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스토리지 오류: ${e.code}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
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

  Widget _buildAvatar() {
    final avatar = CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey[300],
      backgroundImage: _currentImageProvider(),
      child: _currentImageProvider() == null
          ? const Icon(Icons.person, size: 50, color: Colors.white70)
          : null,
    );

    if (_isKakao) {
      // 카카오 사용자는 완전히 막고, 잠금 오버레이 표시
      return Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
          ),
          const Icon(Icons.lock, color: Colors.white, size: 36),
        ],
      );
    } else {
      // 일반 사용자: 탭으로 갤러리 열기
      return InkWell(
        borderRadius: BorderRadius.circular(60),
        onTap: _pickImage,
        child: avatar,
      );
    }
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
            _buildAvatar(),
            const SizedBox(height: 8),
            if (_isKakao)
              Text(
                '카카오 연동 계정은 프로필 이미지를 앱에서 변경할 수 없습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

            if (!_isKakao) ...[
              TextField(
                controller: _pwCtr,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '새 비밀번호',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwConfirmCtr,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호 확인',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
            ] else
              const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
