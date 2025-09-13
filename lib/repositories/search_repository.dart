import 'package:cloud_firestore/cloud_firestore.dart';

class SearchRepository {
  final _col = FirebaseFirestore.instance.collection('campgrounds');

  Future<List<Map<String, dynamic>>> search({
    required String keyword,
    required Set<String> regions,
    required Set<String> facilities,
    required Set<String> campTypes,
  }) async {
    final snap = await _col.get();
    final docs =
        snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

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
