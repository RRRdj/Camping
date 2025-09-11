import 'dart:convert';

/// 장소 정보 모델
class Place {
  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  // 직렬화
  String toJsonString() => jsonEncode({
    'n': name,
    'lat': latitude,
    'lng': longitude,
    'addr': address,
  });

  // 역직렬화
  static Place fromJsonString(String s) {
    final m = jsonDecode(s);
    return Place(
      name: m['n'],
      latitude: (m['lat'] as num).toDouble(),
      longitude: (m['lng'] as num).toDouble(),
      address: (m['addr'] ?? '') as String,
    );
  }
}
