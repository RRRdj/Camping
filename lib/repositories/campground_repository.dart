import 'package:cloud_firestore/cloud_firestore.dart';

class Campground {
  final String firstImageUrl;

  Campground({required this.firstImageUrl});
}

class CampgroundRepository {
  final _firestore = FirebaseFirestore.instance;

  /// campName 문서에서 firstImageUrl을 가져옴
  Future<Campground> fetchCampground(String campName) async {
    final doc = await _firestore.collection('campgrounds').doc(campName).get();

    final data = doc.data();
    final img = data?['firstImageUrl'] as String? ?? '';
    return Campground(firstImageUrl: img);
  }
}
