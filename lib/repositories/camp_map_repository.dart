// lib/repositories/camp_map_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

/// 캠핑장 모델: Firestore 문서 + 가용성 동기화, 마커 JS 생성 지원
class Camp {
  final String contentId;
  final String name;
  final String region;
  final String type;
  final double lat;
  final double lng;
  final int available;
  final int total;

  Camp({
    required this.contentId,
    required this.name,
    required this.region,
    required this.type,
    required this.lat,
    required this.lng,
    required this.available,
    required this.total,
  });

  /// Firestore DocumentSnapshot → Camp 인스턴스
  factory Camp.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Camp(
      contentId: d.id,
      name: m['name'] as String? ?? '',
      region: m['addr1'] as String? ?? '',
      type: m['type'] as String? ?? '',
      lat: double.tryParse(m['mapY']?.toString() ?? '') ?? 0.0,
      lng: double.tryParse(m['mapX']?.toString() ?? '') ?? 0.0,
      available: (m['available'] ?? 0) as int,
      total: (m['total'] ?? 0) as int,
    );
  }

  /// 가용성만 교체하여 반환
  Camp copyWith({int? available, int? total}) {
    return Camp(
      contentId: contentId,
      name: name,
      region: region,
      type: type,
      lat: lat,
      lng: lng,
      available: available ?? this.available,
      total: total ?? this.total,
    );
  }

  /// 카카오맵에 마커와 InfoWindow를 띄우는 JS 코드 반환
  String toMarkerJs(DateTime selectedDate) {
    final month = selectedDate.month;
    final day = selectedDate.day;
    // 예약 가능 여부 텍스트 및 색상
    final status = available > 0 ? '예약가능' : '마감';
    final colorHex = available > 0 ? '#2ecc71' : '#e74c3c';

    return """
(function(){
  var coord = new kakao.maps.LatLng($lat, $lng);
  var markerImage = new kakao.maps.MarkerImage(
    'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/marker_red.png',
    new kakao.maps.Size(24,35),
    { offset: new kakao.maps.Point(12,35) }
  );
  var marker = new kakao.maps.Marker({ position: coord, image: markerImage });
  marker.setMap(map);

  var contentHtml = '
    <div style="padding:8px;max-width:200px;font-family:sans-serif;">
      <strong style="font-size:14px;display:block;margin-bottom:4px;">$name</strong>
      <span style="font-size:12px;color:#555;display:block;margin-bottom:4px;">$region</span>
      <span style="font-size:12px;color:$colorHex;font-weight:bold;display:block;margin-bottom:8px;">'
      + '$month월 $day일 $status ($available/$total)</span>'
      + '<button '
      + 'style="width:100%;padding:6px;border:none;background:#007aff;color:#fff;border-radius:4px;cursor:pointer;" '
      + "onclick=\"window.flutter_inappwebview.callHandler('detail','$contentId')\""
      + '>상세정보</button>
    </div>';

  var infoWindow = new kakao.maps.InfoWindow({ content: contentHtml });
  kakao.maps.event.addListener(marker, 'click', function() {
    infoWindow.getMap() ? infoWindow.close() : infoWindow.open(map, marker);
  });
})();
""";
  }
}

/// 위치 권한 및 Firestore 데이터 로딩을 담당하는 리포지토리
class CampMapRepository {
  final _fire = FirebaseFirestore.instance;

  /// 현재 위치 조회 (권한 체크 포함)
  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('위치 서비스가 꺼져 있습니다.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 필요합니다.');
      }
    }
    return await Geolocator.getCurrentPosition();
  }

  /// Firestore에서 캠핑장 목록 + 실시간 가용성 머지
  Future<List<Camp>> fetchCamps(DateTime selectedDate) async {
    final campSnap = await _fire.collection('campgrounds').get();
    var camps = campSnap.docs.map((d) => Camp.fromDoc(d)).toList();
    // 국립/지자체 필터
    camps =
        camps.where((c) {
          final t = c.type.toLowerCase();
          return t.contains('국립') || t.contains('지자체');
        }).toList();

    final rtSnap = await _fire.collection('realtime_availability').get();
    final rtMap = {for (var d in rtSnap.docs) d.id: d.data()};
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    return camps.map((c) {
      final dayData = rtMap[c.name]?[dateKey] as Map<String, dynamic>?;
      if (dayData != null) {
        return c.copyWith(
          available: dayData['available'] as int? ?? c.available,
          total: dayData['total'] as int? ?? c.total,
        );
      }
      return c;
    }).toList();
  }
}
