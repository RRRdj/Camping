import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore 에서 캠핑장 검색을 수행하는 레포지토리
class SearchRepository {
  final _col = FirebaseFirestore.instance.collection('campgrounds');

  /// 키워드 + 필터 조건으로 캠핑장 검색
  Future<List<Map<String, dynamic>>> search({
    required String keyword,
    required Set<String> regions,
    required Set<String> facilities,
    required Set<String> campTypes,
  }) async {
    // 1단계: 전체 컬렉션 스냅샷
    final snap = await _col.get();
    final docs =
        snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    // 2단계: 클라이언트 측 필터링 (필요하면 Firestore where 절로 최적화 가능)
    return docs.where((c) {
      final nameMatch =
          keyword.isEmpty ||
          (c['name'] as String).toLowerCase().contains(keyword.toLowerCase());

      final regionMatch =
          regions.isEmpty ||
          regions.contains((c['location'] as String).split(' ').first);

      final facilityMatch =
          facilities.isEmpty ||
          ((c['amenities'] as List<dynamic>? ?? [])
              .cast<String>()
              .toSet()
              .intersection(facilities)
              .isNotEmpty);

      final typeMatch =
          campTypes.isEmpty || campTypes.contains(c['type'] as String);

      return nameMatch && regionMatch && facilityMatch && typeMatch;
    }).toList();
  }
}
