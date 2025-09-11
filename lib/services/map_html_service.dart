// lib/services/map_html_service.dart
import 'package:intl/intl.dart';
import '../repositories/camp_map_repository.dart'; // Camp.toMarkerJs(DateTime) 사용

/// 카카오 지도 HTML을 만들어 주는 유틸
class MapHtmlService {
  /* ===== 외부에서 같이 쓰기 좋은 유틸 ===== */

  /// 'yyyy-MM-dd' 포맷
  String formatDateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// (선택) 예약 URL 유틸
  String reservationUrl(String type, String? resveUrl) =>
      type == '국립'
          ? 'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do'
          : (resveUrl ?? '');

  /* ===== HTML 생성기 ===== */

  /// 단일 좌표 지도
  String singleMarkerMapHtml(double lat, double lng) =>
      _htmlShell(_singleMarkerScript(lat, lng));

  /// 현재 위치 + 캠핑장 마커(클러스터) + 로드뷰 토글
  String interactiveMapHtml({
    required double lat,
    required double lng,
    required List<Camp> camps,
    required DateTime date,
  }) {
    final markersJs = StringBuffer();

    // 현재 위치 마커
    markersJs.writeln(
      '(function(){new kakao.maps.Marker({position:new kakao.maps.LatLng($lat,$lng)}).setMap(map);}());',
    );

    // 캠핑장 마커 (Camp.toMarkerJs가 InfoWindow/JS 핸들(detail) 호출 포함)
    for (final camp in camps) {
      markersJs.writeln(camp.toMarkerJs(date));
    }

    return _htmlShell(_interactiveScript(lat, lng, markersJs.toString()));
  }

  /* ===== 내부 구현 ===== */

  String _htmlShell(String bodyScript) => '''
<!DOCTYPE html>
<html lang="ko"><head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <style>
    html,body{margin:0;padding:0;width:100%;height:100%;}
    #map,#roadview{width:100%;height:100%;}
    #container{display:flex;flex-direction:column;width:100%;height:100%;transition:.3s;}
    #mapWrapper{flex:1 1 100%;position:relative;transition:.3s;}
    #roadview{display:none;flex:0 0 0;height:0;overflow:hidden;transition:.3s;}
    #container.view_roadview #mapWrapper{flex:0 0 50%;}
    #container.view_roadview #roadview{display:block;flex:0 0 50%;height:50%;}

    /* ✅ 로드뷰 버튼: 작게 */
    #roadviewControl{
      position:absolute;top:10px;left:10px;z-index:7;
      background:#fff;border:1px solid #ccc;border-radius:4px;
      padding:6px 12px;           /* 12px 20px -> 6px 12px */
      font-size:14px;             /* 28px -> 14px */
      cursor:pointer;
      box-shadow:0 1px 3px rgba(0,0,0,.08);
    }
    #roadviewControl.active{background:#007aff;color:#fff;}

    #rvClose{
      display:none;position:absolute;top:10px;right:10px;z-index:7;
      width:28px;height:28px;border:1px solid #ccc;border-radius:50%;
      background:#fff;font-size:16px;line-height:26px;text-align:center;cursor:pointer;
    }
    #container.view_roadview #rvClose{display:block;}

    /* ✅ 인포윈도우에 쓸 수 있는 작고 단정한 스타일 (toMarkerJs에서 감싸서 사용) */
    .camp-iw{
      padding:6px 8px;            /* 10px -> 6~8px */
      font-size:12px;             /* 14px -> 12px */
      line-height:1.35;
      color:#111;
      max-width:220px;            /* 너무 넓지 않게 */
    }
    .camp-iw h4{
      margin:0 0 4px 0;font-size:13px;font-weight:700;
    }
    .camp-iw .sub{color:#666;font-size:11px;}
    .camp-iw .row{margin-top:6px;}
    .camp-iw .btn{
      display:inline-block;margin-top:8px;padding:6px 10px;border-radius:6px;
      background:#1976d2;color:#fff;text-decoration:none;font-size:12px;
    }
  </style>

  <script>
    // http -> https 강제 (카카오 CDN)
    (function(){
      const o=document.write.bind(document);
      document.write=s=>o(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'));
    })();
  </script>

  <!-- clusterer 포함 -->
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7&libraries=clusterer"></script>
</head>
<body>
  $bodyScript
</body>
</html>
''';

  String _singleMarkerScript(double lat, double lng) => '''
<div id="map"></div>
<script>
  const coord = new kakao.maps.LatLng($lat,$lng);
  const map   = new kakao.maps.Map(document.getElementById('map'),{center:coord,level:3});
  const clusterer = new kakao.maps.MarkerClusterer({ map: map, averageCenter: true, minLevel: 10 });
  const marker = new kakao.maps.Marker({position:coord});
  clusterer.addMarker(marker);
  kakao.maps.event.addListener(map,'idle',()=>map.setCenter(coord));
</script>
''';

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
  // InfoWindow 한 개만 열리도록 관리
  const infoWindows = [];
  function openSingleInfo(infoWindow, marker){
    infoWindows.forEach(iw => iw.close());
    infoWindows.length = 0;
    infoWindow.open(map, marker);
    infoWindows.push(infoWindow);
  }

  // ✅ 인포윈도우 내용 감싸기 헬퍼 (작은 스타일 적용)
  // Camp.toMarkerJs에서: const iw = new kakao.maps.InfoWindow({content: wrapIw(html)});
  // 처럼 사용하면 .camp-iw 스타일이 적용됩니다.
  window.wrapIw = function(innerHtml){
    return '<div class="camp-iw">'+ innerHtml +'</div>';
  }

  // ✅ 작아진 마커 이미지 헬퍼 (28px 권장)
  // Camp.toMarkerJs에서: image: smallMarkerImage('URL', 28, 28)
  window.smallMarkerImage = function(url, w, h){
    w = w || 28; h = h || 28;
    return new kakao.maps.MarkerImage(
      url,
      new kakao.maps.Size(w,h),
      { offset: new kakao.maps.Point(Math.round(w/2), h) }
    );
  }

  const container = document.getElementById('container'),
        map       = new kakao.maps.Map(document.getElementById('map'), {center:new kakao.maps.LatLng($lat,$lng), level:3}),
        clusterer = new kakao.maps.MarkerClusterer({ map: map, averageCenter: true, minLevel: 5, gridSize: 100 }),
        rv        = new kakao.maps.Roadview(document.getElementById('roadview')),
        rvClient  = new kakao.maps.RoadviewClient(),
        button    = document.getElementById('roadviewControl'),
        rvMarker  = new kakao.maps.Marker({
          image:new kakao.maps.MarkerImage(
            'https://t1.daumcdn.net/localimg/localimages/07/2018/pc/roadview_minimap_wk_2018.png',
            new kakao.maps.Size(10,20), /* 작게 */
            {spriteSize:new kakao.maps.Size(1666,168), spriteOrigin:new kakao.maps.Point(705,114), offset:new kakao.maps.Point(10,20)}
          ),
          position:map.getCenter(), draggable:true
        });
  let overlayOn=false;

  function toggleRoadviewUI(){
    if(button.classList.toggle('active')){
      overlayOn=true;
      map.addOverlayMapTypeId(kakao.maps.MapTypeId.ROADVIEW);
      rvMarker.setMap(map);
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
    rvClient.getNearestPanoId(pos,50,function(panoId){ if(panoId) rv.setPanoId(panoId,pos); });
  }
  kakao.maps.event.addListener(rv,'position_changed',function(){
    const pos=rv.getPosition(); map.setCenter(pos); if(overlayOn) rvMarker.setPosition(pos);
  });
  kakao.maps.event.addListener(rvMarker,'dragend',function(e){ moveTo(e.latLng); });
  kakao.maps.event.addListener(map,'click',function(e){
    if(overlayOn){ rvMarker.setPosition(e.latLng); moveTo(e.latLng); }
    // 빈 공간 클릭 시 열린 인포윈도우 닫기
    infoWindows.forEach(function(iw){ iw.close(); }); infoWindows.length=0;
  });

  // Dart에서 호출할 수 있게 노출
  window.openRoadviewAt = function(lat, lng){
    if(!button.classList.contains('active')) toggleRoadviewUI();
    const pos = new kakao.maps.LatLng(lat, lng);
    rvMarker.setPosition(pos);
    moveTo(pos);
  };

  // 캠핑장 마커들 추가
  $markersJs
</script>
''';
}
