import 'package:cloud_firestore/cloud_firestore.dart';

/// 캠핑장·실시간 재고 데이터 전담 Repository
class CampgroundRepository {
  final _campCol = FirebaseFirestore.instance.collection('campgrounds');
  final _availCol = FirebaseFirestore.instance.collection(
    'realtime_availability',
  );

  /// 캠핑장 목록 스트림
  Stream<List<Map<String, dynamic>>> watchCamps() {
    return _campCol.snapshots().map(
      (snap) =>
          snap.docs.map((d) => d.data()! as Map<String, dynamic>).toList(),
    );
  }

  /// 실시간 재고 스트림
  Stream<Map<String, Map<String, dynamic>>> watchAvailability() {
    return _availCol.snapshots().map((snap) {
      final map = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        map[doc.id] = doc.data()! as Map<String, dynamic>;
      }
      return map;
    });
  }
}
