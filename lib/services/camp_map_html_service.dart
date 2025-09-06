// lib/services/camp_map_html_service.dart

import 'package:intl/intl.dart';
import '../repositories/camp_map_repository.dart';

/// 캠핑장·지도 HTML 생성 & 각종 유틸리티 모음
class CampMapHtmlService {
  /* ─── 날짜·예약 유틸 ─── */

  String formatDateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  String reservationUrl(String type, String? resveUrl) =>
      type == '국립'
          ? 'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do'
          : (resveUrl ?? '');

  /* ─── 지도 HTML 생성 ─── */

  /// (1) 단일 좌표 지도
  String singleMarkerMapHtml(double lat, double lng) =>
      _htmlShell(_singleMarkerScript(lat, lng));

  /// (2) 현재 위치 + 캠핑장 마커 + 로드뷰
  String interactiveMapHtml({
    required double lat,
    required double lng,
    required List<Camp> camps,
    required DateTime date,
  }) {
    final buf = StringBuffer();

    // 현재 위치 마커 (지도에 직접 올림)
    buf.writeln(
      '(function(){new kakao.maps.Marker({position:new kakao.maps.LatLng($lat,$lng)}).setMap(map);}());',
    );
    // 캠핑장 마커들 (클러스터러에 등록)
    for (final camp in camps) {
      buf.writeln(camp.toMarkerJs(date));
    }

    return _htmlShell(_interactiveScript(lat, lng, buf.toString()));
  }

  /* ─── 내부 헬퍼 ─── */

  String _htmlShell(String bodyScript) => '''
<!DOCTYPE html>
<html lang="ko"><head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
  <style>
    html,body{margin:0;padding:0;width:100%;height:100%;}
    #map,#roadview{width:100%;height:100%;}
    #container{display:flex;flex-direction:column;width:100%;height:100%;transition:.3s;}
    #mapWrapper{flex:1 1 100%;position:relative;transition:.3s;}
    #roadview{display:none;flex:0 0 0;height:0;overflow:hidden;transition:.3s;}
    #container.view_roadview #mapWrapper{flex:0 0 50%;}
    #container.view_roadview #roadview{display:block;flex:0 0 50%;height:50%;}
    #roadviewControl{position:absolute;top:10px;left:10px;z-index:7;
      background:#fff;border:1px solid #ccc;border-radius:4px;
      padding:12px 20px;font-size:36px;cursor:pointer;}
    #roadviewControl.active{background:#007aff;color:#fff;}
    #rvClose{display:none;position:absolute;top:10px;right:10px;z-index:7;
      width:28px;height:28px;border:1px solid #ccc;border-radius:50%;
      background:#fff;font-size:16px;line-height:26px;text-align:center;cursor:pointer;}
    #container.view_roadview #rvClose{display:block;}
  </style>
  <script>
    (function(){
      const o=document.write.bind(document);
      document.write=s=>o(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'));
    })();
  </script>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7&libraries=clusterer"></script>
</head>
<body>
  $bodyScript
</body>
</html>
''';

  /// (a) 단일 좌표 스크립트
  String _singleMarkerScript(double lat, double lng) => '''
<div id="map"></div>
<script>
  const coord = new kakao.maps.LatLng($lat,$lng);
  const map   = new kakao.maps.Map(document.getElementById('map'),
                {center:coord,level:3});
  const clusterer = new kakao.maps.MarkerClusterer({
        map: map,
        averageCenter: true,
        minLevel: 10   
    });
  const marker = new kakao.maps.Marker({position:coord});
  clusterer.addMarker(marker);
  kakao.maps.event.addListener(map,'idle',()=>map.setCenter(coord));
</script>
''';

  /// (b) 인터랙티브 지도 스크립트 (화사한 클러스터 스타일 + InfoWindow 관리)
  String _interactiveScript(double lat, double lng, String markersJs) => '''
<div id="container">
  <div id="mapWrapper">
    <div id="map"></div>
    <div id="roadviewControl" onclick="toggleRoadviewUI()">로드뷰</div>
  </div>
  <div id="roadview">
    <div id="rvClose" onclick="closeRoadview()">✕</div>
  </div>
</div>

<script>
  // ─── InfoWindow 전역 관리 ───────────────────────────────
  const infoWindows = [];
  function openSingleInfo(infoWindow, marker) {
    infoWindows.forEach(iw => iw.close());
    infoWindows.length = 0;
    infoWindow.open(map, marker);
    infoWindows.push(infoWindow);
  }
  // ───────────────────────────────────────────────────────

  const container = document.getElementById('container'),
        map       = new kakao.maps.Map(
                      document.getElementById('map'),
                      {center:new kakao.maps.LatLng($lat,$lng),level:3}),
        clusterer = new kakao.maps.MarkerClusterer({
          map: map,
          averageCenter: true,
          minLevel: 5,
          gridSize: 100,
          styles: [
            { width:'70px', height:'70px', background:'rgba(102,204,255,0.7)',
              border:'3px solid #fff', borderRadius:'50%', color:'#004085',
              fontSize:'36px', fontWeight:'600', textAlign:'center',
              lineHeight:'50px', display:'flex', alignItems:'center',
              justifyContent:'center' },
            { width:'100px', height:'100px', background:'rgba(51,153,255,0.7)',
              border:'3px solid #fff', borderRadius:'50%', color:'#fff',
              fontSize:'42px', fontWeight:'600', textAlign:'center',
              lineHeight:'60px', display:'flex', alignItems:'center',
              justifyContent:'center' },
            { width:'130px', height:'130px', background:'rgba(0,123,255,0.7)',
              border:'3px solid #fff', borderRadius:'50%', color:'#fff',
              fontSize:'48px', fontWeight:'600', textAlign:'center',
              lineHeight:'70px', display:'flex', alignItems:'center',
              justifyContent:'center' }
          ]
        }),
        rv        = new kakao.maps.Roadview(document.getElementById('roadview')),
        rvClient  = new kakao.maps.RoadviewClient(),
        button    = document.getElementById('roadviewControl'),
        rvMarker  = new kakao.maps.Marker({
          image:new kakao.maps.MarkerImage(
            'https://t1.daumcdn.net/localimg/localimages/07/2018/pc/roadview_minimap_wk_2018.png',
            new kakao.maps.Size(10,20),
            {spriteSize:new kakao.maps.Size(1666,168),
             spriteOrigin:new kakao.maps.Point(705,114),
             offset:new kakao.maps.Point(10,40)}),
          position:map.getCenter(),draggable:true
        });
  let overlayOn=false;

  function toggleRoadviewUI(){
    if(button.classList.toggle('active')){
      overlayOn=true;
      map.addOverlayMapTypeId(kakao.maps.MapTypeId.ROADVIEW);
      container.classList.add('view_roadview');
      moveTo(map.getCenter());
    } else {
      closeRoadview();
    }
  }
  function closeRoadview(){
    overlayOn=false;
    button.classList.remove('active');
    map.removeOverlayMapTypeId(kakao.maps.MapTypeId.ROADVIEW);
    rvMarker.setMap(null);
    container.classList.remove('view_roadview');
  }
  function moveTo(pos){
    rvClient.getNearestPanoId(pos,50,panoId=>{
      if(panoId) rv.setPanoId(panoId,pos);
    });
  }

  kakao.maps.event.addListener(rv,'position_changed',()=>{
    const pos = rv.getPosition();
    map.setCenter(pos);
    if(overlayOn) rvMarker.setPosition(pos);
  });
  kakao.maps.event.addListener(rvMarker,'dragend',e=>moveTo(e.latLng));
  kakao.maps.event.addListener(map,'click',e=>{
    if(!overlayOn) return;
    rvMarker.setPosition(e.latLng);
    moveTo(e.latLng);
  });

  window.openRoadviewAt = (lat, lng) => {
    if(!button.classList.contains('active')) toggleRoadviewUI();
    const pos = new kakao.maps.LatLng(lat, lng);
    rvMarker.setPosition(pos);
    moveTo(pos);
  };

  /* 캠핑장 마커들 */
  $markersJs
</script>
''';
}
