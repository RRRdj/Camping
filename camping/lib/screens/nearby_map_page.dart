import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'camping_info_screen.dart'; // 상세 정보 페이지

class NearbyMapPage extends StatefulWidget {
  const NearbyMapPage({Key? key}) : super(key: key);

  @override
  State<NearbyMapPage> createState() => _NearbyMapPageState();
}

class _NearbyMapPageState extends State<NearbyMapPage> {
  double? _lat, _lng;
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>>? _campStream;
  late InAppWebViewController _webCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  List<Camp> _allCamps = [];
  List<Camp> _filteredCamps = [];

  @override
  void initState() {
    super.initState();
    _initLocationAndQuery();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text;
      setState(() {
        _filteredCamps = _allCamps
            .where((c) => c.name.contains(q) || c.region.contains(q))
            .toList();
      });
      _reloadMapMarkers();
    });
  }

  Future<void> _initLocationAndQuery() async {
    // 위치 서비스 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스가 꺼져 있습니다.')));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 필요합니다.')));
        return;
      }
    }

    // 현재 위치 가져오기
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 정보를 가져올 수 없습니다: \$e')));
      return;
    }

    // Firestore 지오쿼리 설정
    final ref = FirebaseFirestore.instance.collection('campgrounds');
    final centerPoint = GeoFirePoint(GeoPoint(_lat!, _lng!));
    _campStream = GeoCollectionReference<Map<String, dynamic>>(ref)
        .subscribeWithin(
      center: centerPoint,
      radiusInKm: 5,
      field: 'position',
      geopointFrom: (data) =>
      (data['position'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
    )
        .cast<List<DocumentSnapshot<Map<String, dynamic>>>>();

    _campStream!.listen((docs) {
      final camps = docs
          .map((d) => Camp.fromDoc(d))
          .where((c) => c.type.contains('국립') || c.type.contains('지자체'))
          .toList();
      setState(() {
        _allCamps = camps;
        _filteredCamps = camps;
      });
      _reloadMapMarkers();
    });
  }

  void _reloadMapMarkers() {
    if (_lat == null || _lng == null) return;
    final markersJs = _filteredCamps.map((c) => c.toMarkerJs()).join('\n');
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
  <style>html,body,#map{margin:0;padding:0;width:100%;height:100%;}</style>
  <script>
    (function(){
      const _old = document.write.bind(document);
      document.write = s => _old(s.replace(/http:\/\/t1\.daumcdn\.net/g,'https://t1.daumcdn.net'));
    })();
  </script>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    var center = new kakao.maps.LatLng(${_lat!}, ${_lng!});
    var map = new kakao.maps.Map(document.getElementById('map'), { center: center, level: 3 });
    new kakao.maps.Marker({
      position: center,
      image: new kakao.maps.MarkerImage(
        'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/marker_blue.png',
        new kakao.maps.Size(24,35),
        { offset: new kakao.maps.Point(12,35) }
      )
    }).setMap(map);
    $markersJs
  </script>
</body>
</html>
''';
    _webCtrl.loadData(data: html, mimeType: 'text/html', encoding: 'utf-8');
  }

  @override
  Widget build(BuildContext context) {
    // 위치 불러오기 전 로딩 표시
    if (_lat == null || _lng == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('내 주변 국립·지자체 캠핑장')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
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
              initialData: InAppWebViewInitialData(data: ''),
              initialOptions: InAppWebViewGroupOptions(
                android: AndroidInAppWebViewOptions(
                  mixedContentMode: AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                ),
                ios: IOSInAppWebViewOptions(),
              ),
              onWebViewCreated: (controller) {
                _webCtrl = controller;
                _reloadMapMarkers();
                controller.addJavaScriptHandler(
                  handlerName: 'detail',
                  callback: (args) {
                    final contentId = args.isNotEmpty ? args[0] as String : '';
                    if (contentId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CampingInfoScreen(
                            campName: contentId,
                            available: 0,
                            total: 0,
                            isBookmarked: false,
                            onToggleBookmark: (_) {},
                          ),
                        ),
                      );
                    }
                  },
                );
              },
              onConsoleMessage: (controller, msg) =>
                  debugPrint('JS> \${msg.message}'),
            ),
          ),
        ],
      ),
    );
  }
}

class Camp {
  final String contentId;
  final String name;
  final double lat, lng;
  final int available, total;
  final String region;
  final String type;

  Camp({
    required this.contentId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.available,
    required this.total,
    required this.region,
    required this.type,
  });

  factory Camp.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data()!;
    return Camp(
      contentId: d.id,
      name: data['name'] ?? '',
      lat: double.tryParse(data['mapY'] ?? '') ?? 0,
      lng: double.tryParse(data['mapX'] ?? '') ?? 0,
      available: (data['available'] ?? 0) as int,
      total: (data['total'] ?? 0) as int,
      region: data['addr1'] ?? '',
      type: data['inDuty'] ?? '',
    );
  }

  String toMarkerJs() {
    return """
(function(){
  var coord = new kakao.maps.LatLng(${lat}, ${lng});
  var marker = new kakao.maps.Marker({
    position: coord,
    image: new kakao.maps.MarkerImage(
      'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/marker_red.png',
      new kakao.maps.Size(24,35),
      { offset: new kakao.maps.Point(12,35) }
    )
  });
  marker.setMap(map);
  var info = new kakao.maps.InfoWindow({
    content:
      '<div style="padding:5px;font-size:12px;">'
      + '${name} (${region})<br>'
      + '${available > 0 ? '예약가능' : '마감'}'<br>'
      + '<button onclick="window.flutter_inappwebview.callHandler(\\'detail\\',\\"${contentId}\\")">상세정보</button>'
      + '</div>'
  });
  kakao.maps.event.addListener(marker,'click',function(){ info.open(map,marker); });
})();
""";
  }
}