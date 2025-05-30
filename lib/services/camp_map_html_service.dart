// services/camp_map_html_service.dart
import 'package:intl/intl.dart';
import '../repositories/camp_map_repository.dart';

/// 캠핑장·지도 HTML 생성 & 각종 유틸리티 모음
class CampMapHtmlService {
  /* ─── 날짜·예약 유틸 ─── */

  /// 파이어스토어 key 용(yyyy-MM-dd)
  String formatDateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// 캠핑장 예약 페이지 URL
  String reservationUrl(String type, String? resveUrl) =>
      type == '국립'
          ? 'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do'
          : (resveUrl ?? '');

  /* ─── 지도 HTML 생성 ─── */

  /// (1) 단일 좌표만 표시하는 가벼운 지도
  String singleMarkerMapHtml(double lat, double lng) =>
      _htmlShell(_singleMarkerScript(lat, lng));

  /// (2) 현재 위치 + 캠핑장 마커 + 로드뷰 토글이 포함된 풀-버전 지도
  String interactiveMapHtml({
    required double lat,
    required double lng,
    required List<Camp> camps,
    required DateTime date,
  }) {
    final buf = StringBuffer();

    // 현재 위치 마커
    buf.writeln(
      '(function(){new kakao.maps.Marker({position:new kakao.maps.LatLng($lat,$lng)}).setMap(map);}());',
    );
    // 캠핑장 마커들
    for (final camp in camps) buf.writeln(camp.toMarkerJs(date));

    return _htmlShell(_interactiveScript(lat, lng, buf.toString()));
  }

  /* ─── 내부 헬퍼 ─── */

  /// Kakao Maps SDK & 공통 스타일까지 포함한 HTML 틀
  String _htmlShell(String bodyScript) => '''
<!DOCTYPE html>
<html lang="ko"><head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
  <style>
    html,body{margin:0;padding:0;width:100%;height:100%;}
    #map,#roadview{width:100%;height:100%;}
    /* 인터랙티브 모드 전용 추가 스타일 */
    #container{display:flex;flex-direction:column;width:100%;height:100%;transition:.3s;}
    #mapWrapper{flex:1 1 100%;position:relative;transition:.3s;}
    #roadview{display:none;flex:0 0 0;height:0;overflow:hidden;transition:.3s;}
    #container.view_roadview #mapWrapper{flex:0 0 50%;}
    #container.view_roadview #roadview{display:block;flex:0 0 50%;height:50%;}
    #roadviewControl{position:absolute;top:10px;left:10px;z-index:7;
      background:#fff;border:1px solid #ccc;border-radius:4px;
      padding:12px 20px;font-size:28px;cursor:pointer;}
    #roadviewControl.active{background:#007aff;color:#fff;}
    #rvClose{display:none;position:absolute;top:10px;right:10px;z-index:7;
      width:28px;height:28px;border:1px solid #ccc;border-radius:50%;
      background:#fff;font-size:16px;line-height:26px;text-align:center;cursor:pointer;}
    #container.view_roadview #rvClose{display:block;}
  </style>
  <script>
    // http→https 이미지 패치
    (function(){
      const o=document.write.bind(document);
      document.write=s=>o(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'));
    })();
  </script>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script>
</head>
<body>
  $bodyScript
</body>
</html>
''';

  /// (a) 단순 지도에 들어갈 스크립트
  String _singleMarkerScript(double lat, double lng) => '''
<div id="map"></div>
<script>
  const coord = new kakao.maps.LatLng($lat,$lng);
  const map   = new kakao.maps.Map(document.getElementById('map'),
                {center:coord,level:3});
  new kakao.maps.Marker({position:coord}).setMap(map);
  kakao.maps.event.addListener(map,'idle',()=>map.setCenter(coord));
</script>
''';

  /// (b) 로드뷰 토글이 있는 인터랙티브 지도 스크립트
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
  const container = document.getElementById('container'),
        map       = new kakao.maps.Map(
                      document.getElementById('map'),
                      {center:new kakao.maps.LatLng($lat,$lng),level:3}),
        rv        = new kakao.maps.Roadview(document.getElementById('roadview')),
        rvClient  = new kakao.maps.RoadviewClient(),
        button    = document.getElementById('roadviewControl'),
        rvMarker  = new kakao.maps.Marker({
                      image:new kakao.maps.MarkerImage(
                        'https://t1.daumcdn.net/localimg/localimages/07/2018/pc/roadview_minimap_wk_2018.png',
                        new kakao.maps.Size(26,46),
                        {spriteSize:new kakao.maps.Size(1666,168),
                         spriteOrigin:new kakao.maps.Point(705,114),
                         offset:new kakao.maps.Point(13,46)}),
                      position:map.getCenter(),draggable:true});
  let overlayOn=false;

  function toggleRoadviewUI(){
    if(button.classList.toggle('active')){
      overlayOn=true;
      map.addOverlayMapTypeId(kakao.maps.MapTypeId.ROADVIEW);
      rvMarker.setMap(map);
      container.classList.add('view_roadview');
      moveTo(map.getCenter());
    }else closeRoadview();
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
    const pos=rv.getPosition();
    map.setCenter(pos);
    if(overlayOn) rvMarker.setPosition(pos);
  });
  kakao.maps.event.addListener(rvMarker,'dragend',e=>moveTo(e.latLng));
  kakao.maps.event.addListener(map,'click',e=>{
    if(!overlayOn) return;
    rvMarker.setPosition(e.latLng); moveTo(e.latLng);
  });

  /// 외부에서 호출해 특정 좌표로 바로 로드뷰 열기
  window.openRoadviewAt=(lat,lng)=>{
    if(!button.classList.contains('active')) toggleRoadviewUI();
    const pos=new kakao.maps.LatLng(lat,lng);
    rvMarker.setPosition(pos); moveTo(pos);
  };

  /* 캠핑장 마커들 */
  $markersJs
</script>
''';
}
