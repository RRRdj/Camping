import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;
  final _store = FirebaseStorage.instance;

  Future<bool> isNicknameTaken(String nick) async {
    final q =
        await _fire
            .collection('users')
            .where('nickname', isEqualTo: nick)
            .get();
    return q.docs.isNotEmpty;
  }

  Future<String> signUp({required String email, required String pw}) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: pw,
    );
    return cred.user!.uid;
  }

  Future<String> uploadProfileImage(String uid, File file) async {
    final ref = _store.ref().child('userProfileImages/$uid.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> saveUserData(String uid, Map<String, dynamic> data) async {
    await _fire.collection('users').doc(uid).set(data);
  }
}
