import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

const _greenMarker =
    'https://img.icons8.com/?size=50&id=L7DH4c3i9coo&format=png&color=228BE6';
const _redMarker =
    'https://img.icons8.com/?size=50&id=kqCJWucG32lh&format=png&color=FA5252';

final Map<String, Map<String, dynamic>?> _weatherCache = {};

class Camp {
  final String contentId;
  final String name;
  final String region;
  final String type;
  final double lat;
  final double lng;
  final int available;
  final int total;
  final double? avgTemp;
  final int? chanceOfRain;
  final int? wmoCode;

  Camp({
    required this.contentId,
    required this.name,
    required this.region,
    required this.type,
    required this.lat,
    required this.lng,
    required this.available,
    required this.total,
    this.avgTemp,
    this.chanceOfRain,
    this.wmoCode,
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

  Camp copyWith({
    int? available,
    int? total,
    double? avgTemp,
    int? chanceOfRain,
    int? wmoCode,
  }) {
    return Camp(
      contentId: contentId,
      name: name,
      region: region,
      type: type,
      lat: lat,
      lng: lng,
      available: available ?? this.available,
      total: total ?? this.total,
      avgTemp: avgTemp ?? this.avgTemp,
      chanceOfRain: chanceOfRain ?? this.chanceOfRain,
      wmoCode: wmoCode ?? this.wmoCode,
    );
  }

  String toMarkerJs(DateTime selectedDate) {
    final m = selectedDate.month;
    final d = selectedDate.day;
    final ok = available > 0;
    final markerImg = ok ? _greenMarker : _redMarker;
    final col = ok ? '#2ecc71' : '#e74c3c';
    final tag = ok ? '예약가능' : '마감';

    String weatherLine = '';
    if (avgTemp != null || chanceOfRain != null || wmoCode != null) {
      final wt = _wmoKoText(wmoCode);
      final emoji = _wmoEmoji(wmoCode);
      final t = avgTemp != null ? '${avgTemp!.toStringAsFixed(1)}℃' : '-℃';
      final pop = (chanceOfRain != null) ? ' · 강수확률 ${chanceOfRain!}%' : '';
      weatherLine =
          '<div style="font-size:11px; color:#333; margin-bottom:6px;">'
          ' $emoji $wt · $t$pop'
          '</div>';
    }

    final html = '''
<div style="
  transform:scale(1.6);
  transform-origin:bottom center;
  padding:6px;
  max-width:180px;
  font-family:sans-serif;
  background:#fff;
  box-shadow:0 1px 4px rgba(0,0,0,.25);
  border-radius:6px;">
  <strong style="font-size:13px; display:block; margin-bottom:4px;">$name</strong>
  <span style="font-size:11px; color:#555; display:block; margin-bottom:4px;">$region</span>
  $weatherLine
  <span style="font-size:11px; color:$col; font-weight:bold; display:block; margin-bottom:6px;">
    ${m}월 ${d}일 $tag ($available/$total)
  </span>

  <div style="display:flex; gap:4px;">
    <button style="flex:1; padding:6px; border:none; background:#007aff; color:#fff;
                   border-radius:4px; font-size:11px; cursor:pointer;"
            onclick="window.flutter_inappwebview.callHandler('detail','$contentId')">
      상세정보
    </button>
    <button style="flex:1; padding:6px; border:none; background:#555; color:#fff;
                   border-radius:4px; font-size:11px; cursor:pointer;"
            onclick="openRoadviewAt($lat,$lng)">
      로드뷰
    </button>
  </div>
</div>
''';

    final encoded = jsonEncode(html);

    return """
(function(){
  var pos = new kakao.maps.LatLng($lat, $lng);
  var marker = new kakao.maps.Marker({
    position: pos,
    image: new kakao.maps.MarkerImage(
      '$markerImg',
      new kakao.maps.Size(36,52),
      { offset: new kakao.maps.Point(18,52) }
    )
  });
  clusterer.addMarker(marker);

  var info = new kakao.maps.InfoWindow({ content: $encoded });

  kakao.maps.event.addListener(marker, 'click', function() {
    openSingleInfo(info, marker);
  });
})();
""";
  }

  static String _wmoKoText(int? code) {
    switch (code) {
      case 0:
        return '맑음';
      case 1:
      case 2:
        return '부분적 흐림';
      case 3:
        return '흐림';
      case 45:
      case 48:
        return '안개';
      case 51:
      case 53:
      case 55:
        return '이슬비';
      case 61:
      case 63:
      case 65:
        return '비';
      case 71:
      case 73:
      case 75:
        return '눈';
      case 80:
      case 81:
      case 82:
        return '소나기';
      case 95:
        return '천둥번개';
      default:
        return '날씨';
    }
  }

  static String _wmoEmoji(int? code) {
    if (code == null) return '☁️';
    if (code == 0) return '☀️';
    if ([1, 2].contains(code)) return '⛅️';
    if (code == 3) return '☁️';
    if ([61, 63, 65, 80, 81, 82].contains(code)) return '🌧️';
    if ([71, 73, 75].contains(code)) return '❄️';
    if (code == 45 || code == 48) return '🌫️';
    if (code == 95) return '⛈️';
    return '☁️';
  }
}

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

    final merged =
        camps.map((c) {
          final day = rtMap[c.name]?[key] as Map<String, dynamic>?;
          return day == null
              ? c
              : c.copyWith(
                available: (day['available'] as int?) ?? c.available,
                total: (day['total'] as int?) ?? c.total,
              );
        }).toList();

    final enriched = await Future.wait(
      merged.map((c) async {
        final w = await _fetchWeatherForDate(c.lat, c.lng, selectedDate);
        if (w == null) return c;
        return c.copyWith(
          wmoCode: w['wmo'] as int?,
          avgTemp: (w['temp'] as num?)?.toDouble(),
          chanceOfRain: w['chanceOfRain'] as int?,
        );
      }),
    );

    return enriched;
  }

  Future<Map<String, dynamic>?> _fetchWeatherForDate(
    double lat,
    double lng,
    DateTime date,
  ) async {
    DateTime just(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
    final d = just(date);
    final today = just(DateTime.now());
    final diffDays = d.difference(today).inDays;

    if (diffDays < 0 || diffDays > 13) return null;

    final dateStr = DateFormat('yyyy-MM-dd').format(d);
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}|$dateStr';
    if (_weatherCache.containsKey(key)) return _weatherCache[key];

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${lat.toStringAsFixed(4)}'
      '&longitude=${lng.toStringAsFixed(4)}'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_mean'
      '&forecast_days=14'
      '&timezone=auto',
    );

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;

      final decoded = utf8.decode(resp.bodyBytes);
      final data = json.decode(decoded) as Map<String, dynamic>;
      final List times = (data['daily']?['time'] as List?) ?? [];
      final List codes = (data['daily']?['weathercode'] as List?) ?? [];
      final List tmax = (data['daily']?['temperature_2m_max'] as List?) ?? [];
      final List tmin = (data['daily']?['temperature_2m_min'] as List?) ?? [];
      final List prcpProb =
          (data['daily']?['precipitation_probability_mean'] as List?) ?? [];

      final idx = times.indexOf(dateStr);
      if (idx < 0) return null;

      final code = (codes[idx] as num?)?.toInt();
      final tempAvg = _avgNum(tmax[idx], tmin[idx]);
      final pop =
          (prcpProb.isNotEmpty && prcpProb[idx] != null)
              ? (prcpProb[idx] as num).round()
              : null;

      final result = {'wmo': code, 'temp': tempAvg, 'chanceOfRain': pop};
      _weatherCache[key] = result;
      return result;
    } catch (_) {
      return null;
    }
  }
}

double? _avgNum(dynamic a, dynamic b) {
  if (a == null || b == null) return null;
  return ((a as num).toDouble() + (b as num).toDouble()) / 2.0;
}
