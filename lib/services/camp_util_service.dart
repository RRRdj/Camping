import 'package:intl/intl.dart';

class CampUtilService {
  /* ── 예약 페이지 URL ── */

  String formatDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String reservationUrl(String type, String? resveUrl) {
    if (type == '국립') {
      return 'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do';
    }
    return resveUrl ?? '';
  }

  /* ── Kakao 지도 HTML (InAppWebView) ── */
  String kakaoMapHtml(double lat, double lng) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
  <style>
    html,body,#map{margin:0;padding:0;width:100%;height:100%;}
  </style>
  <script>
    (function(){
      const o=document.write.bind(document);
      document.write=s=>o(s.replace(/http:\/\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'));
    })();
  </script>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    const coord=new kakao.maps.LatLng($lat,$lng);
    const map=new kakao.maps.Map(document.getElementById('map'),{center:coord,level:3});
    const marker=new kakao.maps.Marker({position:coord});
    marker.setMap(map);
    kakao.maps.event.addListener(map,'idle',()=>map.setCenter(coord));
  </script>
</body>
</html>
''';
}
