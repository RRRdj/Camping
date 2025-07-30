import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

const _greenMarker =
    'https://img.icons8.com/?size=50&id=L7DH4c3i9coo&format=png&color=228BE6';
const _redMarker =
    'https://img.icons8.com/?size=50&id=kqCJWucG32lh&format=png&color=FA5252';

/// ──────────────────────────────────
/// Camp 모델
/// ──────────────────────────────────
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

  /// 카카오맵 마커 + 인포윈도우 JS
  String toMarkerJs(DateTime selectedDate) {
    final m = selectedDate.month;
    final d = selectedDate.day;
    final ok = available > 0;

    /* ① 마커 색상 결정 */
    final markerImg = ok ? _greenMarker : _redMarker;

    /* ② 인포윈도우 내부 색상·텍스트 */
    final col = ok ? '#2ecc71' : '#e74c3c';
    final tag = ok ? '예약가능' : '마감';

    /* ③ 인포윈도우 HTML */
    final html = '''
<div style="
  transform:scale(3);
  transform-origin:bottom center;
  padding:8px;
  max-width:220px;
  font-family:sans-serif;
  background:#fff;
  box-shadow:0 2px 6px rgba(0,0,0,.3);
  border-radius:4px;">
  <strong style="font-size:14px; display:block; margin-bottom:4px;">$name</strong>
  <span style="font-size:12px; color:#555; display:block; margin-bottom:4px;">$region</span>
  <span style="font-size:12px; color:$col; font-weight:bold; display:block; margin-bottom:8px;">
    ${m}월&nbsp;${d}일&nbsp;$tag&nbsp;($available/$total)
  </span>

  <div style="display:flex; gap:4px;">
    <button style="flex:1; padding:6px; border:none; background:#007aff; color:#fff;
                   border-radius:4px; cursor:pointer;"
            onclick="window.flutter_inappwebview.callHandler('detail','$contentId')">
      상세정보
    </button>

    <button style="flex:1; padding:6px; border:none; background:#555; color:#fff;
                   border-radius:4px; cursor:pointer;"
            onclick="openRoadviewAt($lat,$lng)">
      로드뷰
    </button>
  </div>
</div>
''';

    final encoded = jsonEncode(html);

    /* ④ 마커 + 인포윈도우 JS (클러스터러에 등록) */
    return """
(function(){
  var pos = new kakao.maps.LatLng($lat, $lng);
  var marker = new kakao.maps.Marker({
    position: pos,
    image: new kakao.maps.MarkerImage(
      '$markerImg',
      new kakao.maps.Size(72,105),
      { offset: new kakao.maps.Point(36,105) }
    )
  });
  clusterer.addMarker(marker);

  var info = new kakao.maps.InfoWindow({ content: $encoded });

  // 기존 info.getMap() 방식 삭제 → 전역 헬퍼 사용
  kakao.maps.event.addListener(marker, 'click', function() {
    openSingleInfo(info, marker);
  });
})();
""";
  }
}

/// ──────────────────────────────────
/// 위치 + Firestore 리포지토리
/// ──────────────────────────────────
class CampMapRepository {
  final _fire = FirebaseFirestore.instance;

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

  Future<List<Camp>> fetchCamps(DateTime selectedDate) async {
    final campSnap = await _fire.collection('campgrounds').get();
    var camps =
        campSnap.docs.map((d) => Camp.fromDoc(d)).toList()..retainWhere((c) {
          final t = c.type.toLowerCase();
          return t.contains('국립') || t.contains('지자체');
        });

    final rtSnap = await _fire.collection('realtime_availability').get();
    final rtMap = {for (var d in rtSnap.docs) d.id: d.data()};
    final key = DateFormat('yyyy-MM-dd').format(selectedDate);

    return camps.map((c) {
      final day = rtMap[c.name]?[key] as Map<String, dynamic>?;
      return day == null
          ? c
          : c.copyWith(
            available: day['available'] as int? ?? c.available,
            total: day['total'] as int? ?? c.total,
          );
    }).toList();
  }
}
