// services/map_html_service.dart
import 'dart:convert';
import '../repositories/camp_map_repository.dart';

class MapHtmlService {
  String buildHtml({
    required double lat,
    required double lng,
    required List<Camp> camps,
    required DateTime date,
  }) {
    final buf = StringBuffer();

    // ── 현재 위치 + 캠핑장 마커 스크립트
    buf.writeln("""
(function(){new kakao.maps.Marker({position:new kakao.maps.LatLng($lat,$lng)}).setMap(map);}());
""");
    for (final c in camps) buf.writeln(c.toMarkerJs(date));

    /* ---------------- HTML ---------------- */
    return '''
<!DOCTYPE html>
<html lang="ko"><head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
  <style>
    html, body { margin:0; padding:0; width:100%; height:100%; }
    /* 1) 세로 배치 */
    #container {
      display: flex;
      flex-direction: column;
      width: 100%; height: 100%;
      transition: .3s;
    }
    /* 2) 지도 영역 */
    #mapWrapper {
      flex: 1 1 100%;
      position: relative;
      transition: .3s;
    }
    /* 3) 로드뷰 영역 (초기 숨김) */
    #roadview {
      display: none;
      flex: 0 0 0;
      width: 100%; height: 0;
      overflow: hidden;
      transition: .3s;
    }

    /* 4) 토글 시: 지도 50% / 로드뷰 50% */
    #container.view_roadview #mapWrapper {
      flex: 0 0 50%;
    }
    #container.view_roadview #roadview {
      display: block;
      flex: 0 0 50%;
      height: 50%;
    }

    #map, #roadview {
      width: 100%; height: 100%;
    }

    /* 5) 버튼 크기 2배 */
    #roadviewControl {
      position: absolute; top: 10px; left: 10px; z-index: 7;
      background: #fff; border: 1px solid #ccc; border-radius: 4px;
      padding: 12px 20px;       /* 기존 6px 10px → 12px 20px */
      font-size: 28px;          /* 기존 14px → 28px */
      cursor: pointer;
    }
    #roadviewControl.active {
      background: #007aff; color: #fff;
    }

    /* X 버튼 (초기 숨김) */
    #rvClose {
      display: none;
      position: absolute; top: 10px; right: 10px; z-index: 7;
      width: 28px; height: 28px;
      border: 1px solid #ccc; border-radius: 50%;
      background: #fff; font-size: 16px; line-height: 26px;
      text-align: center; cursor: pointer;
    }
    /* 로드뷰 오픈 시 X 버튼 보이기 */
    #container.view_roadview #rvClose {
      display: block;
    }
  </style>

  <script>
    (function(){
      const o = document.write.bind(document);
      document.write = s => o(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'));
    })();
  </script>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script>
</head>
<body>
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
    const container = document.getElementById('container'),
          map       = new kakao.maps.Map(
                        document.getElementById('map'),
                        { center: new kakao.maps.LatLng($lat, $lng), level: 3 }
                      ),
          rv        = new kakao.maps.Roadview(document.getElementById('roadview')),
          rvClient  = new kakao.maps.RoadviewClient(),
          button    = document.getElementById('roadviewControl'),
          rvMarker  = new kakao.maps.Marker({
                        image: new kakao.maps.MarkerImage(
                          'https://t1.daumcdn.net/localimg/localimages/07/2018/pc/roadview_minimap_wk_2018.png',
                          new kakao.maps.Size(26,46),
                          { spriteSize:new kakao.maps.Size(1666,168),
                            spriteOrigin:new kakao.maps.Point(705,114),
                            offset:new kakao.maps.Point(13,46) }
                          ),
                        position: map.getCenter(),
                        draggable: true
                      });
    let overlayOn = false;

    function toggleRoadviewUI(){
      if(button.classList.toggle('active')){
        overlayOn = true;
        map.addOverlayMapTypeId(kakao.maps.MapTypeId.ROADVIEW);
        rvMarker.setMap(map);
        container.classList.add('view_roadview');
        moveTo(map.getCenter());
      } else {
        closeRoadview();
      }
    }
    function closeRoadview(){
      overlayOn = false;
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
      rvMarker.setPosition(e.latLng); moveTo(e.latLng);
    });

    function openRoadviewAt(lat, lng){
  // 1) 로드뷰 UI가 꺼져 있으면 켜기
  if(!button.classList.contains('active')){
    overlayOn = true;
    button.classList.add('active');
    map.addOverlayMapTypeId(kakao.maps.MapTypeId.ROADVIEW);
    rvMarker.setMap(map);
    container.classList.add('view_roadview');
  }
  // 2) 해당 좌표로 이동
  const pos = new kakao.maps.LatLng(lat, lng);
  rvMarker.setPosition(pos);
  moveTo(pos);
}

    /* 캠핑장 마커들 */
    ${buf.toString()}
  </script>
</body>
</html>
''';
  }
}
