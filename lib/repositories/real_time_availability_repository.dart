import 'package:cloud_firestore/cloud_firestore.dart';

class Availability {
  final int available;
  final int total;

  Availability({required this.available, required this.total});
}

class RealTimeAvailabilityRepository {
  final _firestore = FirebaseFirestore.instance;

  /// campName 문서에서 dateKey(yyyy-MM-dd)에 해당하는 available/total을 가져옴
  Future<Availability> fetchAvailability({
    required String campName,
    required String dateKey,
  }) async {
    final doc =
        await _firestore
            .collection('realtime_availability')
            .doc(campName)
            .get();

    final data = doc.data();
    if (data != null && data[dateKey] != null) {
      final entry = data[dateKey] as Map<String, dynamic>;
      return Availability(
        available: entry['available'] ?? 0,
        total: entry['total'] ?? 0,
      );
    }

    return Availability(available: 0, total: 0);
  }
}
