import 'package:url_launcher/url_launcher.dart';

/// CampingInfoScreen 에서 공통적으로 쓰이는 유틸리티 모음
class CampUtilService {
  /* ── 예약 페이지 URL ── */
  String reservationUrl(String type, String? resveUrl) {
    if (type == '국립') {
      return 'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do';
    }
    return resveUrl ?? '';
  }

  /* ── Kakao 지도 HTML (InAppWebView) ── */
  String kakaoMapHtml(double lat, double lng) => '''
<!DOCTYPE html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
<style>html,body,#map{margin:0;padding:0;width:100%;height:100%}</style>
<script>(function(){const _old=document.write.bind(document);
document.write=function(s){_old(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'))}})();</script>
<script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script></head>
<body><div id="map"></div><script>
const coord=new kakao.maps.LatLng($lat,$lng);
const map=new kakao.maps.Map(document.getElementById('map'),{center:coord,level:3});
new kakao.maps.Marker({position:coord}).setMap(map);
kakao.maps.event.addListener(map,'idle',()=>map.setCenter(coord));
</script></body></html>
''';

  /* ── 외부 URL 열기 ── */
  Future<bool> openExternalUrl(String url) async {
    if (url.isEmpty) return false;
    final uri = Uri.parse(url);
    return await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /* ── 전화 다이얼러 호출 ── */
  Future<bool> dial(String number) async {
    if (number.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: number);
    return await canLaunchUrl(uri) && await launchUrl(uri);
  }
}
