import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserRepository {
  final _col = FirebaseFirestore.instance.collection('users');

  /// 로그인 직후: 유저 문서가 없으면 기본 값으로 생성
  Future<void> ensureUserDoc(User user) async {
    final doc = await _col.doc(user.uid).get();
    if (doc.exists) return;

    await _col.doc(user.uid).set({
      'email': user.email ?? '',
      'name': '',
      'nickname': '',
      'phone': '',
      'gender': '',
      'photoUrl':
          'https://api.dicebear.com/6.x/adventurer/png?seed=${user.uid}&size=150',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 프로필 파이어스토어 문서 삭제
  Future<void> deleteUserDoc(String uid) => _col.doc(uid).delete();

  /// 프로필 이미지 삭제 (무시 가능 오류 처리)
  Future<void> deleteUserImage(String uid) async {
    try {
      await FirebaseStorage.instance
          .ref()
          .child('userProfileImages/$uid.jpg')
          .delete();
    } catch (_) {}
  }
}
