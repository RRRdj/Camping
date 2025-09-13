import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserRepository {
  final _col = FirebaseFirestore.instance.collection('users');

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

  Future<void> deleteUserDoc(String uid) => _col.doc(uid).delete();

  Future<void> deleteUserImage(String uid) async {
    try {
      await FirebaseStorage.instance
          .ref()
          .child('userProfileImages/$uid.jpg')
          .delete();
    } catch (_) {}
  }
}
