// lib/screens/nearby_map_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'camping_info_screen.dart';

class NearbyMapPage extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String campName) onToggleBookmark;

  const NearbyMapPage({
    Key? key,
    required this.bookmarked,
    required this.onToggleBookmark,
  }) : super(key: key);

  @override
  State<NearbyMapPage> createState() => _NearbyMapPageState();
}

class _NearbyMapPageState extends State<NearbyMapPage> {
  double? _lat, _lng;
  late InAppWebViewController _webCtrl;
  final _searchCtrl = TextEditingController();
  List<Camp> _allCamps = [];
  List<Camp> _filteredCamps = [];

  @override
  void initState() {
    super.initState();
    _initLocationAndQuery();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() async {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredCamps = List.from(_allCamps));
      _reloadMapMarkers();
      return;
    }

    // 1) 이름 검색
    Camp? matchCamp;
    final matches = _allCamps.where((c) => c.name.toLowerCase().contains(q));
    if (matches.isNotEmpty) matchCamp = matches.first;

    if (matchCamp != null) {
      await _webCtrl.evaluateJavascript(source: """
        map.panTo(new kakao.maps.LatLng(${matchCamp.lat}, ${matchCamp.lng}));
        map.setLevel(4);
      """);
    } else {
      // 2) 지역명 검색
      final safe = Uri.encodeComponent(_searchCtrl.text);
      await _webCtrl.evaluateJavascript(source: """
        var geocoder = new kakao.maps.services.Geocoder();
        geocoder.addressSearch('$safe', function(result, status) {
          if (status === kakao.maps.services.Status.OK) {
            var loc = new kakao.maps.LatLng(result[0].y, result[0].x);
            map.panTo(loc);
            map.setLevel(6);
          }
        });
      """);
    }

    setState(() {
      _filteredCamps = _allCamps.where((c) {
        final n = c.name.toLowerCase();
        final r = c.region.toLowerCase();
        return n.contains(q) || r.contains(q);
      }).toList();
    });
    _reloadMapMarkers();
  }

  Future<void> _initLocationAndQuery() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showSnack('위치 서비스가 꺼져 있습니다.');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showSnack('위치 권한이 필요합니다.');
        return;
      }
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      _showSnack('위치 정보를 가져올 수 없습니다: $e');
      return;
    }

    // Firestore 에서 캠핑장 & 실시간 가용성 모두 불러와서 “내일”치로 덮어쓰기
    final campSnap = await FirebaseFirestore.instance.collection('campgrounds').get();
    var camps = campSnap.docs.map((d) => Camp.fromDoc(d)).toList();

    // 국립·지자체 필터
    camps = camps.where((c) {
      final t = c.type.toLowerCase();
      return t.contains('국립') || t.contains('지자체');
    }).toList();

    final rtSnap = await FirebaseFirestore.instance
        .collection('realtime_availability')
        .get();
    final rtMap = {
      for (var d in rtSnap.docs) d.id: d.data(),
    };

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateKey = DateFormat('yyyy-MM-dd').format(tomorrow);

    camps = camps.map((c) {
      final doc = rtMap[c.name];
      final dayData = doc?[dateKey] as Map<String, dynamic>?;
      if (dayData != null) {
        return c.copyWith(
          available: dayData['available'] as int? ?? c.available,
          total:     dayData['total']     as int? ?? c.total,
        );
      }
      return c;
    }).toList();

    setState(() {
      _allCamps = camps;
      _filteredCamps = List.from(camps);
    });

    _reloadMapMarkers();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _currentLocationJs => """
(function(){
  var pos = new kakao.maps.LatLng(${_lat}, ${_lng});
  new kakao.maps.Marker({ position: pos }).setMap(map);
})();
""";

  void _reloadMapMarkers() {
    if (_lat == null || _lng == null) return;
    final buf = StringBuffer()..write(_currentLocationJs)..writeln();
    for (var c in _filteredCamps) {
      buf.writeln(c.toMarkerJs());
    }
    final markersJs = buf.toString();

    final html = """
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <style>html,body,#map{margin:0;padding:0;width:100%;height:100%}body{overflow:hidden}</style>
  <script>
    (function(){
      const _old = document.write.bind(document);
      document.write = s => _old(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'));
    })();
  </script>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    var map = new kakao.maps.Map(
      document.getElementById('map'),
      { center:new kakao.maps.LatLng(${_lat},${_lng}), level:3 }
    );
    $markersJs
  </script>
</body>
</html>
""";

    _webCtrl.loadData(data: html, mimeType: 'text/html', encoding: 'utf-8');
  }

  @override
  Widget build(BuildContext context) {
    if (_lat == null || _lng == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('내 주변 캠핑장')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '캠핑장명 또는 지역 검색',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialData: InAppWebViewInitialData(data: '<html><body>Loading…</body></html>'),
              initialOptions: InAppWebViewGroupOptions(
                android: AndroidInAppWebViewOptions(
                  mixedContentMode: AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                ),
                ios: IOSInAppWebViewOptions(),
              ),
              onWebViewCreated: (ctrl) {
                _webCtrl = ctrl;
                _reloadMapMarkers();
                ctrl.addJavaScriptHandler(
                  handlerName: 'detail',
                  callback: (args) {
                    final cid = args.isNotEmpty ? args[0] as String : '';
                    if (cid.isNotEmpty) {
                      final camp = _allCamps.firstWhere((c) => c.contentId == cid);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CampingInfoScreen(
                            campName: cid,
                            available: camp.available,
                            total: camp.total,
                            isBookmarked: widget.bookmarked[cid] ?? false,
                            onToggleBookmark: widget.onToggleBookmark,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
              onConsoleMessage: (_, msg) => debugPrint('JS> ${msg.message}'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 캠핑장 모델
class Camp {
  final String contentId, name, region, type;
  final double lat, lng;
  final int available, total;

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
    final y = double.tryParse(m['mapY']?.toString() ?? '') ?? 0.0;
    final x = double.tryParse(m['mapX']?.toString() ?? '') ?? 0.0;
    return Camp(
      contentId: d.id,
      name: m['name']    ?? '',
      region: m['addr1'] ?? '',
      type:   m['type']  ?? '',
      lat:    y,
      lng:    x,
      available: (m['available'] ?? 0) as int,
      total:     (m['total']     ?? 0) as int,
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
      total:     total     ?? this.total,
    );
  }

  String toMarkerJs() => """
(function(){
  var coord = new kakao.maps.LatLng(${lat}, ${lng});
  var markerImage = new kakao.maps.MarkerImage(
    'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/marker_red.png',
    new kakao.maps.Size(24,35),
    { offset: new kakao.maps.Point(12,35) }
  );
  var marker = new kakao.maps.Marker({ position: coord, image: markerImage });
  marker.setMap(map);

  var d = new Date(); d.setDate(d.getDate()+1);
  var month = d.getMonth()+1, day = d.getDate();
  var avail = ${available}, tot = ${total};
  var statusText = avail>0?'예약가능':'마감';
  var infoHtml = '<div style="padding:8px;background:#fff;border-radius:8px;'
               + 'box-shadow:0 2px 6px rgba(0,0,0,0.15);font-family:sans-serif;'
               + 'font-size:13px;max-width:220px;">'
               + '<strong style="display:block;font-size:14px;margin-bottom:4px;">${name}</strong>'
               + '<span style="color:#555;display:block;margin-bottom:6px;">${region}</span>'
               + '<span style="color:'+ (avail>0?'#2ecc71':'#e74c3c')
               + ';display:block;font-weight:bold;margin-bottom:8px;">'
               + month+'월 '+day+'일 '+statusText+' ('+avail+'/'+tot+')</span>'
               + '<button style="width:100%;padding:6px 0;border:none;'
               + 'background:#007aff;color:#fff;border-radius:4px;cursor:pointer;"'
               + " onclick=\\"window.flutter_inappwebview.callHandler('detail','${contentId}')\\">"
               + '상세정보</button></div>';
  var infoWindow = new kakao.maps.InfoWindow({ content: infoHtml });
  kakao.maps.event.addListener(marker,'click', function(){
    infoWindow.getMap()
      ? infoWindow.close()
      : infoWindow.open(map,marker);
  });
})();
""";
}
